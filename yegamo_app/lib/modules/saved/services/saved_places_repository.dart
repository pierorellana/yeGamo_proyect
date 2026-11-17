import 'dart:convert';

import '../../../shared/models/api_error.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/session/session_service.dart';
import '../../../shared/storage/local_storage.dart';
import '../models/saved_models.dart';

class SavedPlacesRepository {
  SavedPlacesRepository(this._storage, this._apiClient, this._session);

  final LocalStorage _storage;
  final ApiClient _apiClient;
  final SessionManager _session;

  /// Con sesión: lugares del servidor más los que solo existen en este
  /// dispositivo (sin coordenadas o aún sin sincronizar). Sin red conserva lo local.
  Future<List<SavedPlace>> list() async {
    final local = await _readLocal();
    if (!_session.isAuthenticated) return local;
    final response = await _apiClient.get<Object?>('favorites/places');
    if (response.isSuccess && response.data is List) {
      final remote = (response.data! as List)
          .whereType<Map>()
          .map((value) => SavedPlace.fromJson(Map<String, Object?>.from(value)))
          .toList(growable: false);
      final remoteIds = remote.map((item) => item.id).toSet();
      final merged = <SavedPlace>[
        ...remote,
        ...local.where((item) => !item.isRemote || !remoteIds.contains(item.id)),
      ];
      // Un lugar remoto que ya no existe en el servidor se descarta.
      final pruned = merged
          .where((item) => !item.isRemote || remoteIds.contains(item.id))
          .toList(growable: false);
      await _writeLocal(pruned);
      return pruned;
    }
    return local;
  }

  Future<SavedOperationResult> add(SavedPlace place) async {
    final current = await _readLocal();
    final withoutDuplicate = current.where((item) => item.id != place.id).toList();
    if (!_session.isAuthenticated) {
      await _writeLocal([...withoutDuplicate, place]);
      return SavedOperationResult(items: await _readLocal());
    }
    if (!place.hasLocation) {
      await _writeLocal([...withoutDuplicate, place]);
      return SavedOperationResult(
        items: await _readLocal(),
        notice:
            'Guardado solo en este dispositivo: falta la ubicación para sincronizarlo.',
      );
    }
    final response = await _apiClient.post<Object?>(
      'favorites/places',
      body: place.toApiJson(),
      idempotencyKey: 'favorite-${place.id}',
    );
    if (response.isSuccess && response.data is Map) {
      final saved = SavedPlace.fromJson(
        Map<String, Object?>.from(response.data! as Map),
      );
      await _writeLocal([
        ...withoutDuplicate,
        SavedPlace(
          id: saved.id,
          label: saved.label,
          subtitle: place.subtitle,
          latitude: saved.latitude ?? place.latitude,
          longitude: saved.longitude ?? place.longitude,
        ),
      ]);
      return SavedOperationResult(items: await _readLocal());
    }
    // Sin sincronizar: queda local y visible para reintentar en la próxima carga.
    await _writeLocal([...withoutDuplicate, place]);
    return SavedOperationResult(items: await _readLocal(), error: response.error);
  }

  Future<SavedOperationResult> remove(String id) async {
    final current = await _readLocal();
    final target = current.where((item) => item.id == id).firstOrNull;
    if (_session.isAuthenticated && (target?.isRemote ?? false)) {
      final response = await _apiClient.delete<Object?>(
        'favorites/places/$id',
        idempotencyKey: 'favorite-delete-$id',
      );
      if (!response.isSuccess && response.error?.statusCode != 404) {
        return SavedOperationResult(items: current, error: response.error);
      }
    }
    await _writeLocal(current.where((item) => item.id != id).toList());
    return SavedOperationResult(items: await _readLocal());
  }

  Future<List<SavedPlace>> _readLocal() async {
    final raw = await _storage.read(YeGamoStorageKeys.savedPlaces);
    if (raw == null) return const [];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => SavedPlace.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> _writeLocal(List<SavedPlace> items) {
    return _storage.write(
      YeGamoStorageKeys.savedPlaces,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}

class SavedOperationResult {
  const SavedOperationResult({required this.items, this.error, this.notice});

  final List<SavedPlace> items;
  final ApiError? error;

  /// Aviso no fatal (p. ej. «solo en este dispositivo»).
  final String? notice;
}
