import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/modules/home/services/home_repository.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  test(
    'maps missing provider responses to recoverable degraded state',
    () async {
      final snapshot = await HomeRepository(
        apiClient: testClient((_) async => unavailableResponse()),
        connectivity: FakeConnectivityService(),
        storage: InMemoryLocalStorage(),
        locationService: FakeLocationService(
          permission: LocationAccess.granted,
          position: const GeoCoordinate(latitude: -2.17, longitude: -79.9),
        ),
        session: SessionManager(InMemoryLocalStorage()),
      ).load();

      expect(snapshot.state, UxState.degraded);
      expect(snapshot.error?.dataState, DataState.unavailable);
    },
  );

  test('does not make offline cache look current', () async {
    final storage = InMemoryLocalStorage();
    await storage.write('home_last_success', 'true');
    final snapshot = await HomeRepository(
      apiClient: testClient(
        (_) async => jsonResponse(const <String, Object?>{}),
      ),
      connectivity: FakeConnectivityService(online: false),
      storage: storage,
      locationService: FakeLocationService(),
      session: SessionManager(InMemoryLocalStorage()),
    ).load();

    expect(snapshot.state, UxState.offline);
  });

  test(
    'guest home sends nearby coordinates and no protected requests',
    () async {
      final transport = FunctionTransport((request) async {
        expect(request.uri.path, '/v1/transit/stops/nearby');
        expect(request.uri.queryParameters, <String, String>{
          'lat': '-2.17',
          'lon': '-79.9',
          'radiusM': '1000',
        });
        return jsonResponse(const <Object?>[]);
      });
      final snapshot = await HomeRepository(
        apiClient: ApiClient(
          config: const AppConfig(apiBaseUrl: 'https://api.test'),
          transport: transport,
          maxRetries: 0,
        ),
        connectivity: FakeConnectivityService(),
        storage: InMemoryLocalStorage(),
        locationService: FakeLocationService(
          permission: LocationAccess.granted,
          position: const GeoCoordinate(latitude: -2.17, longitude: -79.9),
        ),
        session: SessionManager(InMemoryLocalStorage()),
      ).load();

      expect(snapshot.state, UxState.empty);
      expect(transport.requests, hasLength(1));
    },
  );

  test('guest home does not send nearby without a position', () async {
    final transport = FunctionTransport((_) async {
      throw StateError('nearby must not be requested without a position');
    });
    final snapshot = await HomeRepository(
      apiClient: ApiClient(
        config: const AppConfig(apiBaseUrl: 'https://api.test'),
        transport: transport,
        maxRetries: 0,
      ),
      connectivity: FakeConnectivityService(),
      storage: InMemoryLocalStorage(),
      locationService: FakeLocationService(),
      session: SessionManager(InMemoryLocalStorage()),
    ).load();

    expect(snapshot.state, UxState.permission);
    expect(transport.requests, isEmpty);
  });

  test('demo guest home widens nearby radius for the seeded catalog', () async {
    final transport = FunctionTransport((request) async {
      expect(request.uri.path, '/v1/transit/stops/nearby');
      expect(request.uri.queryParameters['radiusM'], '3000');
      return jsonResponse(const <Object?>[]);
    });
    final snapshot = await HomeRepository(
      apiClient: ApiClient(
        config: const AppConfig(apiBaseUrl: 'https://api.test'),
        transport: transport,
        maxRetries: 0,
      ),
      connectivity: FakeConnectivityService(),
      storage: InMemoryLocalStorage(),
      locationService: FakeLocationService(
        permission: LocationAccess.granted,
        position: const GeoCoordinate(latitude: -2.17, longitude: -79.9),
      ),
      session: SessionManager(InMemoryLocalStorage()),
      config: const AppConfig(demoDataEnabled: true),
    ).load();

    expect(snapshot.state, UxState.empty);
    expect(transport.requests, hasLength(1));
  });
}
