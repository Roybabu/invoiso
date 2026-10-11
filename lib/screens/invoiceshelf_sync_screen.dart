import 'dart:async';
import 'package:flutter/material.dart';
import 'package:invoiso/services/invoiceshelf/invoiceshelf_client.dart';
import 'package:invoiso/services/invoiceshelf/invoiceshelf_credential_store.dart';
import 'package:invoiso/services/invoiceshelf/invoiceshelf_exceptions.dart';

/// Optional InvoiceShelf integration screen.
///
/// InvoiceShelf is an open-source, self-hosted invoicing server.
/// This screen lets the user point Invoiso at their own instance and
/// pull customers/invoices/items for read-only reference. All local data
/// remains in Invoiso's SQLite database; nothing is pushed automatically.
///
/// API reference: https://<your-instance>/openapi.json
/// Auth:          POST /api/v1/auth/login → Sanctum Bearer token
/// Multi-tenancy: company: <company_id> header on every request
class InvoiceShelfSyncScreen extends StatefulWidget {
  const InvoiceShelfSyncScreen({super.key});

  @override
  State<InvoiceShelfSyncScreen> createState() => _InvoiceShelfSyncScreenState();
}

class _InvoiceShelfSyncScreenState extends State<InvoiceShelfSyncScreen> {
  final _store = InvoiceShelfCredentialStore();
  final _formKey = GlobalKey<FormState>();

  final _urlCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _connected = false;
  bool _loading = true;
  bool _obscurePassword = true;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final enabled = await _store.isEnabled();
    final url = await _store.getBaseUrl();
    setState(() {
      _connected = enabled;
      if (url != null && url.isNotEmpty) _urlCtrl.text = url;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    try {
      final baseUrl = _urlCtrl.text.trim();
      final reachable = await InvoiceShelfClient.ping(baseUrl);
      if (!reachable) {
        _setStatus(
            'Cannot reach InvoiceShelf at $baseUrl. Check the URL and that the server is running.',
            error: true);
        return;
      }
      final result = await InvoiceShelfClient.login(
        baseUrl: baseUrl,
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await _store.save(
        baseUrl: baseUrl,
        token: result.token,
        companyId: result.companyId,
      );
      _passwordCtrl.clear();
      setState(() => _connected = true);
      _setStatus('Connected successfully.', error: false);
    } on InvoiceShelfAuthException catch (e) {
      _setStatus('Authentication failed: ${e.message}', error: true);
    } on InvoiceShelfNetworkException catch (e) {
      _setStatus('Network error: ${e.message}', error: true);
    } on InvoiceShelfApiException catch (e) {
      _setStatus('Server error (${e.statusCode}): ${e.message}', error: true);
    } catch (e) {
      _setStatus('Unexpected error: $e', error: true);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _loading = true);
    try {
      final token = await _store.getToken();
      final url = await _store.getBaseUrl();
      final companyId = await _store.getCompanyId();
      if (token != null && token.isNotEmpty && url != null && companyId != null) {
        final client = InvoiceShelfClient(
          baseUrl: url,
          token: token,
          companyId: companyId,
        );
        await client.logout().catchError((_) {});
      }
    } finally {
      await _store.clear();
      setState(() {
        _connected = false;
        _emailCtrl.clear();
        _passwordCtrl.clear();
      });
      _setStatus('Disconnected. Your local data is unchanged.', error: false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    try {
      final token = await _store.getToken();
      final url = await _store.getBaseUrl();
      final companyId = await _store.getCompanyId();
      if (token == null || url == null || companyId == null) {
        _setStatus('No saved credentials.', error: true);
        return;
      }
      final client = InvoiceShelfClient(baseUrl: url, token: token, companyId: companyId);
      await client.getCustomers(perPage: 1);
      _setStatus('Connection is healthy.', error: false);
    } on InvoiceShelfAuthException {
      _setStatus('Token expired — please reconnect.', error: true);
    } on InvoiceShelfNetworkException catch (e) {
      _setStatus('Network error: ${e.message}', error: true);
    } catch (e) {
      _setStatus('Test failed: $e', error: true);
    }
  }

  void _setStatus(String msg, {required bool error}) {
    setState(() {
      _statusMessage = msg;
      _statusIsError = error;
      _loading = false;
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('InvoiceShelf Sync')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 24),
                      if (_statusMessage != null) ...[
                        _buildStatus(theme),
                        const SizedBox(height: 16),
                      ],
                      if (!_connected) _buildConnectForm(theme),
                      if (_connected) _buildConnectedPanel(theme),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sync, color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 10),
            Text('InvoiceShelf Integration',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Connect to your self-hosted InvoiceShelf instance to browse its '
          'customers, invoices, and items. Your local Invoiso data is never '
          'modified automatically.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: [
            _pill(theme, 'Self-hosted only'),
            _pill(theme, 'API v1'),
            _pill(theme, 'Read reference data'),
          ],
        ),
      ],
    );
  }

  Widget _pill(ThemeData theme, String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
    );
  }

  Widget _buildStatus(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _statusIsError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _statusIsError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: _statusIsError
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _statusIsError
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Connect to InvoiceShelf',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://billing.example.com',
              prefixIcon: Icon(Icons.dns_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter the server URL';
              final trimmed = v.trim();
              if (!trimmed.contains('.') && !trimmed.contains('localhost')) {
                return 'Enter a valid URL (e.g. https://billing.example.com)';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email / Username',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter your email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              helperText: 'Used only to obtain a session token — never stored.',
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter your password' : null,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _connect,
            icon: const Icon(Icons.link),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withAlpha(60)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.check,
                    color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connected',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    FutureBuilder<String?>(
                      future: _store.getBaseUrl(),
                      builder: (_, snap) => Text(
                        snap.data ?? '…',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _KnownLimitations(theme: theme),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _testConnection,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Test Connection'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KnownLimitations extends StatelessWidget {
  const _KnownLimitations({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final items = [
      'InvoiceShelf must be self-hosted (no SaaS version exists).',
      'The InvoiceShelf REST API is still alpha (v3.0.0-alpha). Endpoints may change.',
      'Only a Bearer token is stored — your password is never saved.',
      'Sync is read-only: no Invoiso data is pushed to InvoiceShelf automatically.',
      'Rate-limited to 60 requests/minute by the InvoiceShelf server.',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Known Limitations',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...items.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 13)),
                  Expanded(
                      child: Text(s,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
