import 'dart:convert';

import '../../../shared/location/location_service.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/connectivity_service.dart';
import '../../../shared/storage/local_storage.dart';
import '../models/search_models.dart';

class SearchRepository {
  SearchRepository({
    required ApiClient apiClient,
    required ConnectivityService connectivity,
    required LocalStorage storage,
    LocationService? locationService,
  }) : this._(apiClient, connectivity, storage, locationService);

  SearchRepository._(
    this._apiClient,
    this._connectivity,
    this._storage,
    this._locationService,
  );

  static const recentsKey = 'search_recent_queries';
  final ApiClient _apiClient;
  final ConnectivityService _connectivity;
  final LocalStorage _storage;
  final LocationService? _locationService;

  Future<List<String>> recentQueries() async {
    final raw = await _storage.read(recentsKey);
    if (raw == null) return const <String>[];
    try {
      final values = jsonDecode(raw);
      if (values is! List) return const <String>[];
      return values.whereType<String>().take(5).toList(growable: false);
    } on FormatException {
      return const <String>[];
    }
  }

  Future<SearchSnapshot> search(String query) async {
    final recents = await recentQueries();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return SearchSnapshot(state: UxState.empty, recentQueries: recents);
    }
    if (!await _connectivity.isOnline) {
      return SearchSnapshot(state: UxState.offline, recentQueries: recents);
    }

    final queryParameters = <String, String>{'q': trimmed};
    final position = await _locationService?.currentPosition();
    if (position != null) {
      queryParameters['lat'] = position.latitude.toString();
      queryParameters['lon'] = position.longitude.toString();
    }

    final response = await _apiClient.get<Object?>(
      'places/search',
      query: queryParameters,
    );
    if (!response.isSuccess) {
      final error = response.error;
      return SearchSnapshot(
        state: error == null
            ? UxState.error
            : UxStateMapping.fromError(
                code: error.code,
                dataState: error.dataState,
              ),
        recentQueries: recents,
        error: error,
      );
    }

    final results = _parseResults(response.data);
    await _remember(trimmed, recents);
    return SearchSnapshot(
      state: results.isEmpty ? UxState.empty : UxState.ok,
      results: results,
      recentQueries: await recentQueries(),
    );
  }

  Future<void> _remember(String query, List<String> existing) async {
    final values = <String>[
      query,
      ...existing.where((value) => value != query),
    ].take(5).toList();
    await _storage.write(recentsKey, jsonEncode(values));
  }

  static List<PlaceResult> _parseResults(Object? body) {
    final values = body is List
        ? body
        : body is Map && body['results'] is List
        ? body['results'] as List
        : body is Map && body['places'] is List
        ? body['places'] as List
        : const <Object?>[];
    return values
        .whereType<Map>()
        .map((value) => PlaceResult.fromJson(Map<String, Object?>.from(value)))
        .toList(growable: false);
  }
}
