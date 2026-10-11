import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'invoiceshelf_exceptions.dart';

/// Low-level HTTP client for the InvoiceShelf REST API (v1).
///
/// All company-scoped requests require a valid [token] (Sanctum Bearer) and a
/// [companyId] (the tenant header `company: <id>`). Construct one of these via
/// [InvoiceShelfClient.login] or restore a previously saved token with the
/// regular constructor.
///
/// Authentication reference: POST /api/v1/auth/login → Bearer token.
/// API base:                  https://<host>/api/v1/
/// Required per-request headers:
///   Authorization: Bearer <token>
///   company: <company_id>
class InvoiceShelfClient {
  final String baseUrl;
  final String token;
  final String companyId;
  final http.Client _http;
  static const _timeout = Duration(seconds: 15);

  InvoiceShelfClient({
    required this.baseUrl,
    required this.token,
    required this.companyId,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  // ── factory: login ────────────────────────────────────────────────────────

  /// Authenticates against [baseUrl] and returns a configured client.
  ///
  /// Throws [InvoiceShelfAuthException] on bad credentials, or
  /// [InvoiceShelfNetworkException] on connectivity problems.
  static Future<({String token, String companyId})> login({
    required String baseUrl,
    required String email,
    required String password,
    String deviceName = 'invoiso',
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    final uri = Uri.parse('${_normalise(baseUrl)}/auth/login');
    final body = jsonEncode({
      'username': email,
      'password': password,
      'device_name': deviceName,
    });
    try {
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String? ?? '';
        if (token.isEmpty) {
          throw const InvoiceShelfAuthException('Server returned empty token');
        }
        // Fetch the first company the user belongs to.
        final companyId = await _fetchFirstCompanyId(
          baseUrl: baseUrl,
          token: token,
          client: client,
        );
        return (token: token, companyId: companyId);
      } else if (response.statusCode == 401 || response.statusCode == 422) {
        throw InvoiceShelfAuthException(
            _extractMessage(response.body) ?? 'Invalid credentials');
      } else {
        throw InvoiceShelfApiException(
            response.statusCode, _extractMessage(response.body) ?? response.reasonPhrase ?? '');
      }
    } on TimeoutException {
      throw const InvoiceShelfNetworkException('Connection timed out');
    } on SocketException catch (e) {
      throw InvoiceShelfNetworkException(e.message);
    } on InvoiceShelfAuthException {
      rethrow;
    } on InvoiceShelfApiException {
      rethrow;
    } catch (e) {
      throw InvoiceShelfNetworkException(e.toString());
    }
  }

  static Future<String> _fetchFirstCompanyId({
    required String baseUrl,
    required String token,
    required http.Client client,
  }) async {
    final uri = Uri.parse('${_normalise(baseUrl)}/me');
    final response = await client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final companies = data['companies'] as List<dynamic>? ?? [];
      if (companies.isNotEmpty) {
        final first = companies.first as Map<String, dynamic>;
        return (first['id'] ?? '').toString();
      }
    }
    return '';
  }

  // ── connectivity probe ────────────────────────────────────────────────────

  /// Returns true if the InvoiceShelf instance at [baseUrl] is reachable.
  /// Uses the unauthenticated GET /api/ping endpoint.
  static Future<bool> ping(String baseUrl, {http.Client? httpClient}) async {
    final client = httpClient ?? http.Client();
    final uri = Uri.parse('${_normaliseBase(baseUrl)}/api/ping');
    try {
      final response = await client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['success'] == 'invoiceshelf-self-hosted';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── auth ops ──────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _post('/auth/logout', null);
  }

  // ── customers ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCustomers({int page = 1, int perPage = 50}) async {
    final response = await _get('/customers?page=$page&per_page=$perPage');
    return _extractList(response, 'data');
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> payload) async {
    final response = await _post('/customers', payload);
    return (response['data'] as Map<String, dynamic>?) ?? response;
  }

  Future<Map<String, dynamic>> updateCustomer(String id, Map<String, dynamic> payload) async {
    final response = await _put('/customers/$id', payload);
    return (response['data'] as Map<String, dynamic>?) ?? response;
  }

  // ── invoices ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getInvoices({int page = 1, int perPage = 50}) async {
    final response = await _get('/invoices?page=$page&per_page=$perPage');
    return _extractList(response, 'data');
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> payload) async {
    final response = await _post('/invoices', payload);
    return (response['invoice'] as Map<String, dynamic>?) ??
        (response['data'] as Map<String, dynamic>?) ?? response;
  }

  // ── items / products ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getItems({int page = 1, int perPage = 50}) async {
    final response = await _get('/items?page=$page&per_page=$perPage');
    return _extractList(response, 'data');
  }

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> payload) async {
    final response = await _post('/items', payload);
    return (response['item'] as Map<String, dynamic>?) ??
        (response['data'] as Map<String, dynamic>?) ?? response;
  }

  // ── payments ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPayments({int page = 1, int perPage = 50}) async {
    final response = await _get('/payments?page=$page&per_page=$perPage');
    return _extractList(response, 'data');
  }

  // ── low-level HTTP helpers ────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'company': companyId,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('${_v1Base()}$path');
    try {
      final response =
          await _http.get(uri, headers: _headers).timeout(_timeout);
      return _handle(response);
    } on TimeoutException {
      throw const InvoiceShelfNetworkException('Request timed out');
    } on SocketException catch (e) {
      throw InvoiceShelfNetworkException(e.message);
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic>? body) async {
    final uri = Uri.parse('${_v1Base()}$path');
    try {
      final response = await _http
          .post(uri, headers: _headers, body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);
      return _handle(response);
    } on TimeoutException {
      throw const InvoiceShelfNetworkException('Request timed out');
    } on SocketException catch (e) {
      throw InvoiceShelfNetworkException(e.message);
    }
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${_v1Base()}$path');
    try {
      final response = await _http
          .put(uri, headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
      return _handle(response);
    } on TimeoutException {
      throw const InvoiceShelfNetworkException('Request timed out');
    } on SocketException catch (e) {
      throw InvoiceShelfNetworkException(e.message);
    }
  }

  Map<String, dynamic> _handle(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
      case 204:
        if (response.body.isEmpty) return {};
        return jsonDecode(response.body) as Map<String, dynamic>;
      case 401:
        throw InvoiceShelfAuthException(
            _extractMessage(response.body) ?? 'Unauthorized');
      case 429:
        final retryAfter =
            int.tryParse(response.headers['retry-after'] ?? '');
        throw InvoiceShelfRateLimitException(retryAfterSeconds: retryAfter);
      default:
        throw InvoiceShelfApiException(response.statusCode,
            _extractMessage(response.body) ?? response.reasonPhrase ?? '');
    }
  }

  String _v1Base() => '${_normalise(baseUrl)}';

  static String _normalise(String url) {
    final base = _normaliseBase(url);
    return '$base/api/v1';
  }

  static String _normaliseBase(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }

  static String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['message'] as String? ??
          decoded['error'] as String?;
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _extractList(
      Map<String, dynamic> response, String key) {
    final raw = response[key];
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
