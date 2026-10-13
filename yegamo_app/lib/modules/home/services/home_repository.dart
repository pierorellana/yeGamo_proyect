import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';
import '../../../env/config/app_config.dart';
import '../../../shared/location/location_service.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/connectivity_service.dart';
import '../../../shared/session/session_service.dart';
import '../../../shared/storage/local_storage.dart';
import '../models/home_models.dart';

class HomeRepository {
  HomeRepository({
    required ApiClient apiClient,
    required ConnectivityService connectivity,
    required LocalStorage storage,
    required LocationService locationService,
    required SessionManager session,
    AppConfig config = const AppConfig(),
  }) : this._(
         apiClient,
         connectivity,
         storage,
         locationService,
         session,
         config,
       );

  HomeRepository._(
    this._apiClient,
    this._connectivity,
    this._storage,
    this._locationService,
    this._session,
    this._config,
  );

  static const cacheKey = 'home_last_success';
  final ApiClient _apiClient;
  final ConnectivityService _connectivity;
  final LocalStorage _storage;
  final LocationService _locationService;
  final SessionManager _session;
  final AppConfig _config;

  String get _nearbyRadiusM => _config.demoDataEnabled ? '3000' : '1000';

  Future<HomeSnapshot> load() async {
    if (!await _connectivity.isOnline) {
      final hasCache = await _storage.read(cacheKey) == 'true';
      return HomeSnapshot(state: hasCache ? UxState.offline : UxState.offline);
    }

    final position = await _locationService.currentPosition();
    if (position == null && _session.isGuest) {
      return const HomeSnapshot(state: UxState.permission);
    }

    final nearbyResponse = position == null
        ? null
        : await _apiClient.get<Object?>(
            'transit/stops/nearby',
            query: <String, String>{
              'lat': position.latitude.toString(),
              'lon': position.longitude.toString(),
              'radiusM': _nearbyRadiusM,
            },
          );
    final protectedResponses = _session.isAuthenticated
        ? await Future.wait<ApiResponse<Object?>>([
            _apiClient.get<Object?>('favorites/places'),
            _apiClient.get<Object?>('notifications'),
          ])
        : const <ApiResponse<Object?>>[];
    final responses = <ApiResponse<Object?>>[
      ?nearbyResponse,
      ...protectedResponses,
    ];
    final successful = responses
        .where((response) => response.isSuccess)
        .toList();
    if (successful.isNotEmpty) {
      await _storage.write(cacheKey, 'true');
      final hasData = successful.any((response) => _hasItems(response.data));
      return HomeSnapshot(
        state: hasData ? UxState.ok : UxState.empty,
        hasNearbyData: nearbyResponse != null && _hasItems(nearbyResponse.data),
        hasSavedData:
            protectedResponses.isNotEmpty &&
            _hasItems(protectedResponses[0].data),
        hasNotifications:
            protectedResponses.length > 1 &&
            _hasItems(protectedResponses[1].data),
      );
    }

    ApiError? error;
    for (final response in responses) {
      if (response.error != null) {
        error = response.error;
        break;
      }
    }
    return HomeSnapshot(state: _stateFor(error), error: error);
  }

  static bool _hasItems(Object? body) {
    if (body is List) return body.isNotEmpty;
    if (body is Map) {
      for (final key in const [
        'items',
        'results',
        'stops',
        'places',
        'notifications',
      ]) {
        if (body[key] is List && (body[key] as List).isNotEmpty) return true;
      }
    }
    return false;
  }

  static UxState _stateFor(ApiError? error) {
    if (error == null) return UxState.error;
    return UxStateMapping.fromError(
      code: error.code,
      dataState: error.dataState,
    );
  }
}
