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

  Future<List<SavedPlace>> list() async {
    final local = await _readLocal();
    if (!_session.isAuthenticated) return local;
    final response = await _apiClient.get<Object?>('favorites/places');
    if (response.isSuccess && response.data is List) {
      final remote = (response.data! as List)
          .whereType<Map>()
          .map((value) => SavedPlace.fromJson(Map<String, Object?>.from(value)))
          .toList(growable: false);
      await _writeLocal(remote);
      return remote;
    }
    return local;
  }

  Future<SavedOperationResult> add(SavedPlace place) async {
    final current = await _readLocal();
    final withoutDuplicate = current.where((item) => item.id != place.id).toList();
    await _writeLocal(<SavedPlace>[...withoutDuplicate, place]);
    if (_session.isAuthenticated) {
      final response = await _apiClient.post<Object?>(
        'favorites/places',
        body: place.toJson(),
        idempotencyKey: 'favorite-${place.id}',
      );
      if (!response.isSuccess && response.error?.statusCode != 409) {
        return SavedOperationResult(items: await _readLocal(), error: response.error);
      }
    }
    return SavedOperationResult(items: await _readLocal());
  }

  Future<SavedOperationResult> remove(String id) async {
    final current = await _readLocal();
    await _writeLocal(current.where((item) => item.id != id).toList());
    if (_session.isAuthenticated) {
      final response = await _apiClient.delete<Object?>('favorites/places/$id');
      if (!response.isSuccess && response.error?.statusCode != 404) {
        return SavedOperationResult(items: await _readLocal(), error: response.error);
      }
    }
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
  const SavedOperationResult({required this.items, this.error});

  final List<SavedPlace> items;
  final ApiError? error;
}
