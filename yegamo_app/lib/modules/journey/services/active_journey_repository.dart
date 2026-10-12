import 'dart:convert';

import '../../../shared/location/location_service.dart';
import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/connectivity_service.dart';
import '../../../shared/storage/local_storage.dart';
import '../models/journey_models.dart';

class ActiveJourneyRepository {
  ActiveJourneyRepository(
    this._apiClient,
    this._storage,
    this._connectivity,
    this._consentStore,
    this._locationReader,
  );

  static const cacheKey = YeGamoStorageKeys.activeJourney;
  final ApiClient _apiClient;
  final LocalStorage _storage;
  final ConnectivityService _connectivity;
  final LocationConsentStore _consentStore;
  final PrivacyAwareLocationReader _locationReader;

  Future<ActiveJourneyResult> start(String planId, String optionId) async {
    final consent = await _consentStore.read();
    if (!await _connectivity.isOnline) return _offlineResult();
    final response = await _apiClient.post<Object?>(
      'active-journeys',
      body: {
        'planId': planId,
        'optionId': optionId,
        'locationConsent': consent,
      },
      idempotencyKey: 'journey-start-$planId-$optionId',
    );
    return await _map(response);
  }

  Future<ActiveJourneyResult> updateProgress(JourneyProgress progress) async {
    final cached = await _readCache();
    if (cached == null) {
      return const ActiveJourneyResult(
        error: ApiError(code: 'NO_ACTIVE_JOURNEY', message: 'No hay un viaje activo.'),
      );
    }
    final location = await _locationReader.readIfConsented();
    if (!await _connectivity.isOnline) return _offlineResult(cached: cached);
    final response = await _apiClient.patch<Object?>(
      'active-journeys/${cached.id}/progress',
      body: progress.toJson(preciseLocation: location),
      idempotencyKey: 'journey-progress-${cached.id}-${progress.sequence}',
    );
    return await _map(response, fallback: cached);
  }

  Future<ActiveJourneyResult> finish() => _terminal('finish');

  Future<ActiveJourneyResult> cancel() => _terminal('cancel');

  Future<ActiveJourneyResult> _terminal(String action) async {
    final cached = await _readCache();
    if (cached == null) {
      return const ActiveJourneyResult(
        error: ApiError(code: 'NO_ACTIVE_JOURNEY', message: 'No hay un viaje activo.'),
      );
    }
    if (!await _connectivity.isOnline) {
      final terminal = cached.copyWith(
        status: action == 'finish'
            ? JourneyStatus.finished
            : JourneyStatus.canceled,
        dataState: DataState.offlineCache,
      );
      await _writeCache(terminal);
      return ActiveJourneyResult(journey: terminal);
    }
    final response = await _apiClient.post<Object?>(
      'active-journeys/${cached.id}/$action',
      idempotencyKey: 'journey-$action-${cached.id}',
    );
    final result = await _map(response, fallback: cached);
    if (result.journey?.isTerminal == true) await _storage.remove(cacheKey);
    return result;
  }

  Future<ActiveJourneyResult> _offlineResult({ActiveJourney? cached}) async {
    final journey = cached ?? await _readCache();
    if (journey == null) {
      return const ActiveJourneyResult(
        error: ApiError(
          code: 'OFFLINE_NO_CACHE',
          message: 'Sin conexión y sin un viaje cacheado.',
          dataState: DataState.offlineCache,
          retryable: true,
        ),
      );
    }
    return ActiveJourneyResult(
      journey: journey.copyWith(dataState: DataState.offlineCache),
    );
  }

  Future<ActiveJourneyResult> _map(
    ApiResponse<Object?> response, {
    ActiveJourney? fallback,
  }) async {
    if (!response.isSuccess) {
      return ActiveJourneyResult(error: response.error);
    }
    final body = response.data;
    if (body is! Map) {
      return const ActiveJourneyResult(
        error: ApiError(
          code: 'INVALID_RESPONSE',
          message: 'La respuesta del viaje no coincide con el contrato.',
        ),
      );
    }
    final journey = ActiveJourney.fromJson(Map<String, Object?>.from(body));
    await _writeCache(journey);
    return ActiveJourneyResult(journey: journey);
  }

  Future<ActiveJourney?> _readCache() async {
    final raw = await _storage.read(cacheKey);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map
          ? ActiveJourney.fromJson(Map<String, Object?>.from(value))
          : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeCache(ActiveJourney journey) {
    return _storage.write(cacheKey, jsonEncode(journey.toJson()));
  }
}

class ActiveJourneyResult {
  const ActiveJourneyResult({this.journey, this.error});

  final ActiveJourney? journey;
  final ApiError? error;
}
