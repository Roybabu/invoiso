import 'package:invoiso/common/setting_key.dart';
import 'package:invoiso/database/settings_service.dart';

/// Persists InvoiceShelf connection credentials in the app's settings table.
///
/// No plaintext password is ever stored — only the Sanctum Bearer token
/// obtained after a successful login. The password is only held in memory
/// during the login call and discarded immediately after.
class InvoiceShelfCredentialStore {
  Future<bool> isEnabled() async {
    final v = await SettingsService.getSetting(SettingKey.invoiceShelfEnabled);
    return v == '1';
  }

  Future<String?> getBaseUrl() =>
      SettingsService.getSetting(SettingKey.invoiceShelfBaseUrl);

  Future<String?> getToken() =>
      SettingsService.getSetting(SettingKey.invoiceShelfToken);

  Future<String?> getCompanyId() =>
      SettingsService.getSetting(SettingKey.invoiceShelfCompanyId);

  Future<void> save({
    required String baseUrl,
    required String token,
    required String companyId,
  }) async {
    await Future.wait([
      SettingsService.setSetting(SettingKey.invoiceShelfEnabled, '1'),
      SettingsService.setSetting(SettingKey.invoiceShelfBaseUrl, baseUrl),
      SettingsService.setSetting(SettingKey.invoiceShelfToken, token),
      SettingsService.setSetting(SettingKey.invoiceShelfCompanyId, companyId),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      SettingsService.setSetting(SettingKey.invoiceShelfEnabled, '0'),
      SettingsService.setSetting(SettingKey.invoiceShelfToken, ''),
      SettingsService.setSetting(SettingKey.invoiceShelfCompanyId, ''),
    ]);
  }
}
