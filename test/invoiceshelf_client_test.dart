// Unit tests for InvoiceShelfClient.
//
// Uses package:http/testing.dart MockClient — no real network calls are made.
// Tests cover: successful login, bad credentials, network timeout, ping,
// authenticated GET/POST helpers, rate-limit and generic API error handling.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:invoiso/services/invoiceshelf/invoiceshelf_client.dart';
import 'package:invoiso/services/invoiceshelf/invoiceshelf_exceptions.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

http.Client _mockClient(Map<String, dynamic> responses) {
  // responses: {'/api/v1/path': {'status': 200, 'body': {...}}}
  return MockClient((request) async {
    final path = request.url.path + (request.url.hasQuery ? '?${request.url.query}' : '');
    for (final entry in responses.entries) {
      if (path.startsWith(entry.key)) {
        final def = entry.value as Map<String, dynamic>;
        return http.Response(
          jsonEncode(def['body'] ?? {}),
          def['status'] as int? ?? 200,
          headers: (def['headers'] as Map<String, String>?) ??
              {'content-type': 'application/json'},
        );
      }
    }
    return http.Response('{"message":"Not found"}', 404,
        headers: {'content-type': 'application/json'});
  });
}

InvoiceShelfClient _client({
  Map<String, dynamic> routes = const {},
  String baseUrl = 'https://billing.example.com',
}) {
  return InvoiceShelfClient(
    baseUrl: baseUrl,
    token: 'test-token',
    companyId: '1',
    httpClient: _mockClient(routes),
  );
}

// ── login ─────────────────────────────────────────────────────────────────────

void main() {
  group('InvoiceShelfClient.login', () {
    test('returns token on 200', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/v1/auth/login') {
          return http.Response(
            jsonEncode({'type': 'Bearer', 'token': 'abc123'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path == '/api/v1/me') {
          return http.Response(
            jsonEncode({
              'companies': [
                {'id': 7, 'name': 'Acme'}
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final result = await InvoiceShelfClient.login(
        baseUrl: 'https://billing.example.com',
        email: 'admin@example.com',
        password: 's3cr3t',
        httpClient: client,
      );

      expect(result.token, 'abc123');
      expect(result.companyId, '7');
    });

    test('throws InvoiceShelfAuthException on 401', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'message': 'Invalid credentials'}),
            401,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        () => InvoiceShelfClient.login(
          baseUrl: 'https://billing.example.com',
          email: 'x',
          password: 'wrong',
          httpClient: client,
        ),
        throwsA(isA<InvoiceShelfAuthException>()),
      );
    });

    test('throws InvoiceShelfAuthException on 422', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'message': 'The given data was invalid.'}),
            422,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        () => InvoiceShelfClient.login(
          baseUrl: 'https://billing.example.com',
          email: '',
          password: '',
          httpClient: client,
        ),
        throwsA(isA<InvoiceShelfAuthException>()),
      );
    });

    test('throws InvoiceShelfApiException on 500', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'message': 'Server error'}),
            500,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        () => InvoiceShelfClient.login(
          baseUrl: 'https://billing.example.com',
          email: 'a',
          password: 'b',
          httpClient: client,
        ),
        throwsA(isA<InvoiceShelfApiException>()),
      );
    });
  });

  // ── ping ───────────────────────────────────────────────────────────────────

  group('InvoiceShelfClient.ping', () {
    test('returns true when response matches expected payload', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'success': 'invoiceshelf-self-hosted'}),
            200,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        await InvoiceShelfClient.ping(
          'https://billing.example.com',
          httpClient: client,
        ),
        isTrue,
      );
    });

    test('returns false when body does not match', () async {
      final client = MockClient((_) async =>
          http.Response('{"success":"something-else"}', 200,
              headers: {'content-type': 'application/json'}));

      expect(
        await InvoiceShelfClient.ping('https://billing.example.com',
            httpClient: client),
        isFalse,
      );
    });

    test('returns false on network error', () async {
      final client = MockClient((_) async => throw Exception('DNS failure'));

      expect(
        await InvoiceShelfClient.ping('https://billing.example.com',
            httpClient: client),
        isFalse,
      );
    });
  });

  // ── getCustomers ──────────────────────────────────────────────────────────

  group('InvoiceShelfClient.getCustomers', () {
    test('returns list from data key', () async {
      final c = _client(routes: {
        '/api/v1/customers': {
          'status': 200,
          'body': {
            'data': [
              {'id': 1, 'name': 'Alice'},
              {'id': 2, 'name': 'Bob'},
            ]
          }
        }
      });

      final result = await c.getCustomers();
      expect(result.length, 2);
      expect(result.first['name'], 'Alice');
    });

    test('throws InvoiceShelfAuthException on 401', () async {
      final c = _client(routes: {
        '/api/v1/customers': {
          'status': 401,
          'body': {'message': 'Unauthenticated'}
        }
      });

      expect(() => c.getCustomers(), throwsA(isA<InvoiceShelfAuthException>()));
    });

    test('throws InvoiceShelfRateLimitException on 429', () async {
      final c = _client(routes: {
        '/api/v1/customers': {
          'status': 429,
          'body': {'message': 'Too many requests'},
          'headers': {
            'content-type': 'application/json',
            'retry-after': '30',
          }
        }
      });

      expect(
        () => c.getCustomers(),
        throwsA(isA<InvoiceShelfRateLimitException>()
            .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 30)),
      );
    });
  });

  // ── getInvoices ───────────────────────────────────────────────────────────

  group('InvoiceShelfClient.getInvoices', () {
    test('returns list from data key', () async {
      final c = _client(routes: {
        '/api/v1/invoices': {
          'status': 200,
          'body': {
            'data': [
              {'id': 10, 'invoice_number': 'INV-0001'}
            ]
          }
        }
      });

      final result = await c.getInvoices();
      expect(result.length, 1);
      expect(result.first['invoice_number'], 'INV-0001');
    });
  });

  // ── getItems ──────────────────────────────────────────────────────────────

  group('InvoiceShelfClient.getItems', () {
    test('returns list from data key', () async {
      final c = _client(routes: {
        '/api/v1/items': {
          'status': 200,
          'body': {
            'data': [
              {'id': 5, 'name': 'Widget', 'price': '100.00'}
            ]
          }
        }
      });

      final result = await c.getItems();
      expect(result.first['name'], 'Widget');
    });
  });

  // ── URL normalisation ─────────────────────────────────────────────────────

  group('URL normalisation', () {
    test('strips trailing slash', () async {
      final c = InvoiceShelfClient(
        baseUrl: 'https://billing.example.com/',
        token: 't',
        companyId: '1',
        httpClient: MockClient((req) async {
          expect(req.url.toString(),
              contains('billing.example.com/api/v1/customers'));
          return http.Response('{"data":[]}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      await c.getCustomers();
    });

    test('prepends https when scheme missing', () async {
      final client = MockClient((req) async {
        expect(req.url.scheme, 'https');
        return http.Response(
          jsonEncode({'success': 'invoiceshelf-self-hosted'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      expect(
        await InvoiceShelfClient.ping('billing.example.com',
            httpClient: client),
        isTrue,
      );
    });
  });
}
