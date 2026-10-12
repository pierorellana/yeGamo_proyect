import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/connectivity_service.dart';
import '../../../shared/storage/local_storage.dart';
import '../models/home_models.dart';

class HomeRepository {
  HomeRepository({
    required ApiClient apiClient,
    required ConnectivityService connectivity,
    required LocalStorage storage,
  }) : this._(apiClient, connectivity, storage);

  HomeRepository._(this._apiClient, this._connectivity, this._storage);

  static const cacheKey = 'home_last_success';
  final ApiClient _apiClient;
  final ConnectivityService _connectivity;
  final LocalStorage _storage;

  Future<HomeSnapshot> load() async {
    if (!await _connectivity.isOnline) {
      final hasCache = await _storage.read(cacheKey) == 'true';
      return HomeSnapshot(state: hasCache ? UxState.offline : UxState.offline);
    }

    final responses = await Future.wait<ApiResponse<Object?>>([
      _apiClient.get<Object?>('transit/stops/nearby'),
      _apiClient.get<Object?>('favorites/places'),
      _apiClient.get<Object?>('notifications'),
    ]);
    final successful = responses
        .where((response) => response.isSuccess)
        .toList();
    if (successful.isNotEmpty) {
      await _storage.write(cacheKey, 'true');
      final hasData = successful.any((response) => _hasItems(response.data));
      return HomeSnapshot(
        state: hasData ? UxState.ok : UxState.empty,
        hasNearbyData: _hasItems(responses[0].data),
        hasSavedData: _hasItems(responses[1].data),
        hasNotifications: _hasItems(responses[2].data),
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
