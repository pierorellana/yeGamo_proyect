import 'dart:convert';

import '../../../shared/location/location_service.dart';
import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/connectivity_service.dart';
import '../../../shared/session/session_service.dart';
import '../../../shared/storage/local_storage.dart';
import '../../planner/models/planner_models.dart';
import '../models/journey_models.dart';

class ActiveJourneyRepository {
  ActiveJourneyRepository(
    this._apiClient,
    this._storage,
    this._connectivity,
    this._locationReader,
    this._session,
  );

  static const cacheKey = YeGamoStorageKeys.activeJourney;
  final ApiClient _apiClient;
  final LocalStorage _storage;
  final ConnectivityService _connectivity;
  final PrivacyAwareLocationReader _locationReader;
  final SessionManager _session;

  /// Con cuenta el viaje se registra en el API. Como invitado (ADR-006: el API
  /// exige JWT para viajes activos) el seguimiento es local y se construye
  /// únicamente con los tramos reales de la opción elegida; nunca se simula.
  Future<ActiveJourneyResult> start(
    String planId,
    String optionId, {
    JourneyOption? option,
  }) async {
    if (!_session.isAuthenticated) return _startLocal(planId, option);
    if (!await _connectivity.isOnline) return _offlineResult();
    // Una clave por intento: reiniciar el mismo plan tras cancelar no debe
    // reproducir la respuesta del viaje anterior.
    final attempt = DateTime.now().microsecondsSinceEpoch;
    final response = await _apiClient.post<Object?>(
      'journeys/$planId/options/$optionId/start',
      idempotencyKey: 'journey-start-$planId-$optionId-$attempt',
    );
    return await _map(response);
  }

  Future<ActiveJourneyResult> _startLocal(
    String planId,
    JourneyOption? option,
  ) async {
    if (option == null || option.legs.isEmpty) {
      return const ActiveJourneyResult(
        error: ApiError(
          code: 'AUTH_REQUIRED',
          message:
              'Inicia sesión para registrar el viaje o vuelve a calcular el plan.',
        ),
      );
    }
    final journey = ActiveJourney(
      id: '$localIdPrefix${DateTime.now().microsecondsSinceEpoch}',
      planId: planId,
      optionId: option.id,
      status: JourneyStatus.active,
      dataState: option.dataQuality.dataState,
      legs: option.legs,
      dataQuality: option.dataQuality,
    );
    await _writeCache(journey);
    return ActiveJourneyResult(journey: journey);
  }

  /// Los viajes locales (invitado) nunca se envían al API.
  static const localIdPrefix = 'local-journey-';
  static bool isLocal(ActiveJourney journey) =>
      journey.id.startsWith(localIdPrefix);

  /// Recupera el viaje tras cerrar/reiniciar la app. Un viaje local (invitado) se
  /// restaura tal cual; uno de cuenta se refresca desde el API. Si el API ya no
  /// lo conoce o terminó, se descarta la caché; sin red se muestra la caché marcada
  /// como `OFFLINE_CACHE` (nunca como actual).
  Future<ActiveJourneyResult?> restore() async {
    final cached = await _readCache();
    if (cached == null || cached.isTerminal) {
      if (cached != null) await _storage.remove(cacheKey);
      return null;
    }
    if (isLocal(cached)) return ActiveJourneyResult(journey: cached);
    if (!_session.isAuthenticated) {
      // El viaje pertenecía a una cuenta cuya sesión ya no existe.
      await _storage.remove(cacheKey);
      return null;
    }
    if (!await _connectivity.isOnline) return _offlineResult(cached: cached);
    final response = await _apiClient.get<Object?>('active-journeys/${cached.id}');
    if (response.error?.statusCode == 404) {
      await _storage.remove(cacheKey);
      return null;
    }
    if (!response.isSuccess) return _offlineResult(cached: cached);
    final result = await _map(response, fallback: cached);
    if (result.journey?.isTerminal == true) {
      await _storage.remove(cacheKey);
      return null;
    }
    return result;
  }

  Future<ActiveJourneyResult> updateProgress(JourneyProgress progress) async {
    final cached = await _readCache();
    if (cached == null) {
      return const ActiveJourneyResult(
        error: ApiError(code: 'NO_ACTIVE_JOURNEY', message: 'No hay un viaje activo.'),
      );
    }
    if (isLocal(cached)) {
      final moved = cached.copyWith(currentLegIndex: progress.currentLegIndex);
      await _writeCache(moved);
      return ActiveJourneyResult(journey: moved);
    }
    final location = await _locationReader.readIfConsented();
    if (!await _connectivity.isOnline) return _offlineResult(cached: cached);
    final body = progress.toJson(preciseLocation: location);
    final response = await _apiClient.patch<Object?>(
      'active-journeys/${cached.id}/progress',
      body: body,
      idempotencyKey:
          'journey-progress-${cached.id}-${progress.currentLegIndex}-${body['occurredAt']}',
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
    if (isLocal(cached)) {
      await _storage.remove(cacheKey);
      return ActiveJourneyResult(
        journey: cached.copyWith(
          status: action == 'finish'
              ? JourneyStatus.finished
              : JourneyStatus.canceled,
        ),
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
    final ActiveJourney journey;
    try {
      journey = ActiveJourney.fromJson(Map<String, Object?>.from(body));
    } on FormatException catch (error) {
      return ActiveJourneyResult(
        error: ApiError(
          code: 'INVALID_RESPONSE',
          message: 'La respuesta del viaje no coincide con el contrato: ${error.message}',
        ),
      );
    }
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
      // Caché de una versión anterior o corrupta: se descarta, no se inventa.
      await _storage.remove(cacheKey);
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
