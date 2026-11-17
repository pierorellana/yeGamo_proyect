import 'dart:convert';

import '../../modules/commutes/models/commute_models.dart';
import '../../modules/saved/models/saved_models.dart';
import '../location/location_service.dart';
import '../services/api_client.dart';
import '../storage/local_storage.dart';

class GuestMigrationSummary {
  const GuestMigrationSummary({
    required this.imported,
    required this.duplicates,
    required this.rejected,
    required this.keptLocal,
    this.errorMessage,
  });

  const GuestMigrationSummary.nothing()
    : this(imported: 0, duplicates: 0, rejected: 0, keptLocal: 0);

  const GuestMigrationSummary.failed(String message, {int keptLocal = 0})
    : this(
        imported: 0,
        duplicates: 0,
        rejected: 0,
        keptLocal: keptLocal,
        errorMessage: message,
      );

  final int imported;
  final int duplicates;
  final int rejected;

  /// Elementos que siguen solo en este dispositivo (sin coordenadas o rechazados).
  final int keptLocal;
  final String? errorMessage;

  bool get ok => errorMessage == null;
}

/// Continuidad de datos al iniciar sesión: migra favoritos y rutinas del
/// invitado y sincroniza preferencias. Nunca borra datos locales antes de que el
/// API confirme; lo rechazado permanece en el dispositivo.
class AccountSyncService {
  AccountSyncService(this._storage, this._apiClient);

  static const dataVersion = '1';

  final LocalStorage _storage;
  final ApiClient _apiClient;

  Future<GuestMigrationSummary> migrateGuestData() async {
    final places = await _readList(YeGamoStorageKeys.savedPlaces, SavedPlace.fromJson);
    final routines = await _readList(YeGamoStorageKeys.commuteRoutines, CommuteRoutine.fromJson);

    // Solo lo que aún no tiene id del servidor y trae coordenadas válidas.
    final pendingPlaces = [
      for (final p in places)
        if (!p.isRemote && p.hasLocation) p,
    ];
    final pendingRoutines = [
      for (final r in routines)
        if (!r.isRemote && r.hasLocations) r,
    ];
    final localOnly =
        places.where((p) => !p.isRemote && !p.hasLocation).length +
        routines.where((r) => !r.isRemote && !r.hasLocations).length;
    if (pendingPlaces.isEmpty && pendingRoutines.isEmpty) {
      return GuestMigrationSummary(
        imported: 0,
        duplicates: 0,
        rejected: 0,
        keptLocal: localOnly,
      );
    }

    final items = <Map<String, Object?>>[
      for (final p in pendingPlaces) {'type': 'FAVORITE_PLACE', ...p.toApiJson()},
      for (final r in pendingRoutines) {'type': 'COMMUTE_PROFILE', ...r.toApiJson()},
    ];
    final fingerprint = jsonEncode(items).hashCode.toUnsigned(32).toRadixString(16);
    final response = await _apiClient.post<Object?>(
      'me/guest-migration',
      body: {'clientDataVersion': dataVersion, 'items': items},
      idempotencyKey: 'guest-migration-$fingerprint',
    );
    final body = response.data;
    if (!response.isSuccess || body is! Map || body['results'] is! List) {
      return GuestMigrationSummary.failed(
        response.error?.message ??
            'No pudimos migrar tus datos. Siguen guardados en este dispositivo.',
        keptLocal: pendingPlaces.length + pendingRoutines.length + localOnly,
      );
    }

    // Reemplaza ids locales por los del servidor (importados y duplicados).
    final results = (body['results'] as List).whereType<Map>().toList();
    final updatedPlaces = [...places];
    final updatedRoutines = [...routines];
    var rejected = 0;
    for (final result in results) {
      final index = (result['index'] as num?)?.toInt() ?? -1;
      final serverId = result['id'] as String?;
      final status = result['status'];
      if (status == 'REJECTED') {
        rejected++;
        continue;
      }
      if (serverId == null || index < 0) continue;
      if (index < pendingPlaces.length) {
        final local = pendingPlaces[index];
        final at = updatedPlaces.indexWhere((p) => p.id == local.id);
        if (at >= 0) {
          updatedPlaces[at] = SavedPlace(
            id: serverId,
            label: local.label,
            subtitle: local.subtitle,
            latitude: local.latitude,
            longitude: local.longitude,
          );
        }
      } else {
        final local = pendingRoutines[index - pendingPlaces.length];
        final at = updatedRoutines.indexWhere((r) => r.id == local.id);
        if (at >= 0) updatedRoutines[at] = local.copyWith(id: serverId);
      }
    }
    await _storage.write(
      YeGamoStorageKeys.savedPlaces,
      jsonEncode(updatedPlaces.map((p) => p.toJson()).toList()),
    );
    await _storage.write(
      YeGamoStorageKeys.commuteRoutines,
      jsonEncode(updatedRoutines.map((r) => r.toJson()).toList()),
    );
    return GuestMigrationSummary(
      imported: (body['importedCount'] as num?)?.toInt() ?? 0,
      duplicates: (body['skippedCount'] as num?)?.toInt() ?? 0,
      rejected: rejected,
      keptLocal: localOnly + rejected,
    );
  }

  /// Envía el consentimiento de ubicación local al perfil de la cuenta, que es
  /// lo que el API exige antes de aceptar ubicación precisa en un viaje.
  Future<bool> syncPreferences() async {
    final consent = await LocationConsentStore(_storage).read();
    final response = await _apiClient.patch<Object?>(
      'me/preferences',
      body: {'locationConsent': consent},
    );
    return response.isSuccess;
  }

  Future<List<T>> _readList<T>(
    String key,
    T Function(Map<String, Object?>) parse,
  ) async {
    final raw = await _storage.read(key);
    if (raw == null) return const [];
    try {
      final value = jsonDecode(raw);
      return value is List
          ? value.whereType<Map>().map((m) => parse(Map<String, Object?>.from(m))).toList()
          : const [];
    } on FormatException {
      return const [];
    }
  }
}
