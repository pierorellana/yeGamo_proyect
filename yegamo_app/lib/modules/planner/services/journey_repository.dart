import 'dart:convert';

import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/storage/local_storage.dart';
import '../models/planner_models.dart';

class JourneyRepository {
  JourneyRepository({required ApiClient apiClient, LocalStorage? storage, DateTime Function()? now})
    : this._(apiClient, storage, now ?? DateTime.now);

  JourneyRepository._(this._apiClient, this._storage, this._now);

  final ApiClient _apiClient;
  final LocalStorage? _storage;
  final DateTime Function() _now;

  /// Política de caché offline: solo se reutiliza un plan **real** cuando no hay
  /// red (no ante `503`, que significa que la fuente no está disponible), solo si
  /// tiene menos de [cacheTtl] (el API también expira los planes a las 24 h), y se
  /// etiqueta `OFFLINE_CACHE` con la hora en que se guardó. Máximo [cacheMax] planes.
  static const cacheTtl = Duration(hours: 24);
  static const cacheMax = 5;
  static const _networkErrors = {'NETWORK_ERROR', 'NETWORK_TIMEOUT'};

  static String cacheKeyFor(JourneyPlanRequest r) =>
      '${r.origin.latitude.toStringAsFixed(4)},${r.origin.longitude.toStringAsFixed(4)}>'
      '${r.destination.latitude.toStringAsFixed(4)},${r.destination.longitude.toStringAsFixed(4)}'
      '|${r.timeMode.apiValue}|${r.preference.apiValue}';

  Future<JourneyResult> plan(JourneyPlanRequest request) async {
    final result = await _planOnline(request);
    final plan = result.plan;
    if (plan != null) {
      await _cache(request, plan);
      return result;
    }
    if (_networkErrors.contains(result.error?.code)) {
      final cached = await _cached(request);
      if (cached != null) return cached;
    }
    return result;
  }

  Future<void> _cache(JourneyPlanRequest request, JourneyPlan plan) async {
    final storage = _storage;
    if (storage == null || plan.options.isEmpty) return;
    final entries = await _readCache();
    entries.remove(cacheKeyFor(request));
    entries[cacheKeyFor(request)] = {
      'savedAt': _now().toUtc().toIso8601String(),
      'plan': plan.toJson(),
    };
    while (entries.length > cacheMax) {
      entries.remove(entries.keys.first);
    }
    await storage.write(YeGamoStorageKeys.planCache, jsonEncode(entries));
  }

  Future<JourneyResult?> _cached(JourneyPlanRequest request) async {
    final entry = (await _readCache())[cacheKeyFor(request)];
    if (entry == null) return null;
    final savedAt = DateTime.tryParse('${entry['savedAt']}');
    final raw = entry['plan'];
    if (savedAt == null || raw is! Map) return null;
    if (_now().difference(savedAt) > cacheTtl) return null;
    final plan = JourneyPlan.fromJson(Map<String, Object?>.from(raw));
    final options = [
      for (final option in plan.options)
        JourneyOption(
          id: option.id,
          durationMin: option.durationMin,
          walkMin: option.walkMin,
          transfers: option.transfers,
          reliabilityScore: option.reliabilityScore,
          reliabilityLevel: option.reliabilityLevel,
          reliabilitySamples: option.reliabilitySamples,
          legs: option.legs,
          dataQuality: JourneyDataQuality(
            dataState: DataState.offlineCache,
            liveVehicle: false,
            sourceAuthorized: option.dataQuality.sourceAuthorized,
            // Hora real de captura del dato; nunca la actual.
            observedAt: savedAt,
            providerDisplayName: option.dataQuality.providerDisplayName,
          ),
        ),
    ];
    return JourneyResult(
      plan: plan.copyWith(dataState: DataState.offlineCache, options: options),
      fromCache: true,
    );
  }

  Future<Map<String, Map<String, Object?>>> _readCache() async {
    final raw = await _storage?.read(YeGamoStorageKeys.planCache);
    if (raw == null) return {};
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return {};
      return {
        for (final e in value.entries)
          if (e.value is Map) '${e.key}': Map<String, Object?>.from(e.value as Map),
      };
    } on FormatException {
      return {};
    }
  }

  Future<JourneyResult> _planOnline(JourneyPlanRequest request) async {
    final response = await _apiClient.post<Object?>(
      'journeys/plan',
      body: request.toJson(),
      idempotencyKey: 'plan-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!response.isSuccess) {
      return JourneyResult(error: response.error);
    }
    final body = response.data;
    if (body is! Map) {
      return const JourneyResult(
        error: ApiError(
          code: 'INVALID_RESPONSE',
          message: 'La respuesta no coincide con el contrato de planificación.',
        ),
      );
    }
    return JourneyResult(
      plan: JourneyPlan.fromJson(Map<String, Object?>.from(body)),
    );
  }

  Future<JourneyResult> getPlan(String planId) async {
    final response = await _apiClient.get<Object?>('journeys/$planId');
    if (!response.isSuccess) return JourneyResult(error: response.error);
    final body = response.data;
    if (body is! Map) {
      return const JourneyResult(
        error: ApiError(
          code: 'INVALID_RESPONSE',
          message: 'La respuesta no coincide con el contrato de planificación.',
        ),
      );
    }
    return JourneyResult(
      plan: JourneyPlan.fromJson(Map<String, Object?>.from(body)),
    );
  }
}

class JourneyResult {
  const JourneyResult({this.plan, this.error, this.fromCache = false});

  final JourneyPlan? plan;
  final ApiError? error;

  /// `true` si el plan viene de la caché offline (etiquetado OFFLINE_CACHE).
  final bool fromCache;
}
