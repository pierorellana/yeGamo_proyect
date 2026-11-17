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
      final localById = {for (final item in local) item.id: item};
      final remote = (response.data! as List)
          .whereType<Map>()
          .map((item) {
            final routine = CommuteRoutine.fromJson(Map<String, Object?>.from(item));
            final known = localById[routine.id];
            // El API no guarda los textos de origen/destino: se conservan los locales.
            return known == null
                ? routine
                : CommuteRoutine(
                    id: routine.id,
                    label: routine.label,
                    origin: known.origin,
                    destination: known.destination,
                    hour: routine.hour,
                    minute: routine.minute,
                    days: routine.days,
                    status: routine.status,
                    timeZoneName: routine.timeZoneName,
                    timeZoneOffsetMinutes: routine.timeZoneOffsetMinutes,
                    originPoint: routine.originPoint,
                    destinationPoint: routine.destinationPoint,
                  );
          })
          .toList(growable: false);
      final merged = <CommuteRoutine>[
        ...remote,
        // Los remotos que desaparecieron del servidor se descartan: solo
        // sobreviven las rutinas locales aún sin sincronizar.
        ...local.where((item) => !item.isRemote),
      ];
      await _writeLocal(merged);
      return merged;
    }
    return local;
  }

  Future<CommuteOperationResult> save(CommuteRoutine routine) async {
    final items = await _readLocal();
    final others = items.where((item) => item.id != routine.id).toList();
    if (!_session.isAuthenticated) {
      final next = [...others, routine];
      await _writeLocal(next);
      return CommuteOperationResult(items: next);
    }
    if (!routine.hasLocations) {
      final next = [...others, routine];
      await _writeLocal(next);
      return CommuteOperationResult(
        items: next,
        notice:
            'Guardada solo en este dispositivo: indica origen y destino como «lat, lon» para sincronizarla.',
      );
    }
    final response = routine.isRemote
        ? await _apiClient.patch<Object?>(
            'commute-profiles/${routine.id}',
            body: routine.toApiJson(),
          )
        : await _apiClient.post<Object?>(
            'commute-profiles',
            body: routine.toApiJson(),
            idempotencyKey: 'commute-${routine.id}',
          );
    if (response.isSuccess && response.data is Map) {
      final saved = CommuteRoutine.fromJson(
        Map<String, Object?>.from(response.data! as Map),
      );
      final synced = routine.copyWith(id: saved.id);
      final next = [...others, synced];
      await _writeLocal(next);
      return CommuteOperationResult(items: next);
    }
    final next = [...others, routine];
    await _writeLocal(next);
    return CommuteOperationResult(items: next, error: response.error);
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
    if (_session.isAuthenticated && routine.isRemote) {
      final action = paused ? 'pause' : 'resume';
      final response = await _apiClient.post<Object?>(
        'commute-profiles/${routine.id}/$action',
        idempotencyKey: 'commute-$action-${routine.id}',
      );
      if (!response.isSuccess) {
        return CommuteOperationResult(items: items, error: response.error);
      }
    }
    await _writeLocal(next);
    return CommuteOperationResult(items: next);
  }

  Future<CommuteOperationResult> remove(String id) async {
    final items = await _readLocal();
    final target = items.where((item) => item.id == id).firstOrNull;
    if (_session.isAuthenticated && (target?.isRemote ?? false)) {
      final response = await _apiClient.delete<Object?>(
        'commute-profiles/$id',
        idempotencyKey: 'commute-delete-$id',
      );
      if (!response.isSuccess && response.error?.statusCode != 404) {
        return CommuteOperationResult(items: items, error: response.error);
      }
    }
    final next = items.where((item) => item.id != id).toList();
    await _writeLocal(next);
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
  const CommuteOperationResult({required this.items, this.error, this.notice});

  final List<CommuteRoutine> items;
  final ApiError? error;

  /// Aviso no fatal (p. ej. «solo en este dispositivo»).
  final String? notice;
}
