import 'dart:convert';

import '../../../shared/models/api_error.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/session/session_service.dart';
import '../../../shared/storage/local_storage.dart';
import '../models/commute_models.dart';

class CommutesRepository {
  CommutesRepository(this._storage, this._apiClient, this._session);

  final LocalStorage _storage;
  final ApiClient _apiClient;
  final SessionManager _session;

  Future<List<CommuteRoutine>> list() async {
    final local = await _readLocal();
    if (!_session.isAuthenticated) return local;
    final response = await _apiClient.get<Object?>('commute-profiles');
    if (response.isSuccess && response.data is List) {
      final remote = (response.data! as List)
          .whereType<Map>()
          .map((item) => CommuteRoutine.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false);
      await _writeLocal(remote);
      return remote;
    }
    return local;
  }

  Future<CommuteOperationResult> save(CommuteRoutine routine) async {
    final items = await _readLocal();
    final next = <CommuteRoutine>[
      ...items.where((item) => item.id != routine.id),
      routine,
    ];
    await _writeLocal(next);
    if (_session.isAuthenticated) {
      final response = await _apiClient.post<Object?>(
        'commute-profiles',
        body: routine.toJson(),
        idempotencyKey: 'commute-${routine.id}',
      );
      if (!response.isSuccess && response.error?.statusCode != 409) {
        return CommuteOperationResult(items: next, error: response.error);
      }
    }
    return CommuteOperationResult(items: next);
  }

  Future<CommuteOperationResult> setPaused(
    CommuteRoutine routine,
    bool paused,
  ) async {
    final updated = routine.copyWith(
      status: paused ? CommuteStatus.paused : CommuteStatus.active,
    );
    final items = await _readLocal();
    final next = items.map((item) => item.id == routine.id ? updated : item).toList();
    await _writeLocal(next);
    if (_session.isAuthenticated) {
      final action = paused ? 'pause' : 'resume';
      final response = await _apiClient.post<Object?>(
        'commute-profiles/${routine.id}/$action',
        idempotencyKey: 'commute-$action-${routine.id}',
      );
      if (!response.isSuccess) {
        return CommuteOperationResult(items: next, error: response.error);
      }
    }
    return CommuteOperationResult(items: next);
  }

  Future<CommuteOperationResult> remove(String id) async {
    final next = (await _readLocal()).where((item) => item.id != id).toList();
    await _writeLocal(next);
    if (_session.isAuthenticated) {
      final response = await _apiClient.delete<Object?>('commute-profiles/$id');
      if (!response.isSuccess && response.error?.statusCode != 404) {
        return CommuteOperationResult(items: next, error: response.error);
      }
    }
    return CommuteOperationResult(items: next);
  }

  Future<List<CommuteRoutine>> _readLocal() async {
    final raw = await _storage.read(YeGamoStorageKeys.commuteRoutines);
    if (raw == null) return const [];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => CommuteRoutine.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> _writeLocal(List<CommuteRoutine> items) => _storage.write(
    YeGamoStorageKeys.commuteRoutines,
    jsonEncode(items.map((item) => item.toJson()).toList()),
  );
}

class CommuteOperationResult {
  const CommuteOperationResult({required this.items, this.error});

  final List<CommuteRoutine> items;
  final ApiError? error;
}
