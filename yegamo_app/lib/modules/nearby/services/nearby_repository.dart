import '../../../env/config/app_config.dart';
import '../../../shared/location/location_service.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/connectivity_service.dart';
import '../models/nearby_models.dart';

class NearbyRepository {
  NearbyRepository({
    required ApiClient apiClient,
    required ConnectivityService connectivity,
    required LocationService locationService,
    AppConfig config = const AppConfig(),
  }) : this._(apiClient, connectivity, locationService, config);

  NearbyRepository._(
    this._apiClient,
    this._connectivity,
    this._locationService,
    this._config,
  );

  final ApiClient _apiClient;
  final ConnectivityService _connectivity;
  final LocationService _locationService;
  final AppConfig _config;

  String get _nearbyRadiusM => _config.demoDataEnabled ? '3000' : '1000';

  Future<NearbySnapshot> load({GeoCoordinate? manualOrigin}) async {
    final position = manualOrigin ?? await _locationService.currentPosition();
    if (position == null) {
      final permission = await _locationService.checkPermission();
      return NearbySnapshot(
        state: permission == LocationAccess.granted
            ? UxState.noCoverage
            : UxState.permission,
      );
    }
    if (!await _connectivity.isOnline) {
      return NearbySnapshot(state: UxState.offline, origin: position);
    }

    final response = await _apiClient.get<Object?>(
      'transit/stops/nearby',
      query: <String, String>{
        'lat': position.latitude.toString(),
        'lon': position.longitude.toString(),
        'radiusM': _nearbyRadiusM,
      },
    );
    if (!response.isSuccess) {
      final error = response.error;
      return NearbySnapshot(
        state: error == null
            ? UxState.error
            : UxStateMapping.fromError(
                code: error.code,
                dataState: error.dataState,
              ),
        error: error,
      );
    }
    final stops = _parseStops(response.data);
    return NearbySnapshot(
      state: stops.isEmpty ? UxState.empty : UxState.ok,
      stops: stops,
      origin: position,
    );
  }

  static List<NearbyStop> _parseStops(Object? body) {
    final values = body is List
        ? body
        : body is Map && body['stops'] is List
        ? body['stops'] as List
        : const <Object?>[];
    return values
        .whereType<Map>()
        .map((value) => NearbyStop.fromJson(Map<String, Object?>.from(value)))
        .toList(growable: false);
  }
}
