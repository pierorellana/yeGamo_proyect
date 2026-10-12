import 'dart:convert';

import '../../../env/config/app_config.dart';
import '../../../shared/location/location_service.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/session/session_service.dart';
import '../../../shared/storage/local_storage.dart';
import '../models/settings_models.dart';

class SettingsRepository {
  SettingsRepository(this._storage, this._apiClient, this._session, this._config)
    : _consent = LocationConsentStore(_storage),
      _privacy = PrivacyDataRepository(_storage);

  final LocalStorage _storage;
  final ApiClient _apiClient;
  final SessionManager _session;
  final AppConfig _config;
  final LocationConsentStore _consent;
  final PrivacyDataRepository _privacy;

  Future<SettingsState> load() async => SettingsState(
    locationConsent: await _consent.read(),
    reduceMotion: _config.reduceMotion,
    demoCatalogEnabled: _config.demoDataEnabled && !_config.isProduction,
  );

  Future<SettingsState> setLocationConsent(bool value) async {
    await _consent.set(value);
    return load();
  }

  Future<SettingsState> exportLocalData() async {
    final data = await _privacy.exportLocalData();
    await _storage.write(
      YeGamoStorageKeys.privacyExportedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
    return (await load()).copyWithExport(jsonEncode(data));
  }

  Future<SettingsState> deleteData() async {
    if (_session.isAuthenticated) {
      final response = await _apiClient.delete<Object?>(
        'me',
        idempotencyKey: 'privacy-delete-account',
      );
      if (!response.isSuccess) {
        return (await load()).withMessage(
          response.error?.message ?? 'No fue posible solicitar la eliminación.',
        );
      }
    }
    await _privacy.deleteLocalData();
    await _session.signOut();
    return load();
  }

  Future<void> signOut() => _session.signOut();
}

extension on SettingsState {
  SettingsState copyWithExport(String value) => SettingsState(
    locationConsent: locationConsent,
    reduceMotion: reduceMotion,
    demoCatalogEnabled: demoCatalogEnabled,
    lastExport: value,
    message: message,
  );

  SettingsState withMessage(String value) => SettingsState(
    locationConsent: locationConsent,
    reduceMotion: reduceMotion,
    demoCatalogEnabled: demoCatalogEnabled,
    lastExport: lastExport,
    message: value,
  );
}
