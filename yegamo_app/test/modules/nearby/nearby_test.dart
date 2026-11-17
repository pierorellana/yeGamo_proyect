import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/modules/nearby/services/nearby_repository.dart';
import 'package:yegamo_app/modules/nearby/models/nearby_models.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/services/api_client.dart';

import '../test_support.dart';
import '../../support/fakes.dart';

void main() {
  test('parses source metadata from an OSM nearby stop', () {
    final stop = NearbyStop.fromJson({
      'id': 'stop-1',
      'name': 'Parada OSM',
      'distanceM': 120,
      'source': 'openstreetmap',
      'dataState': 'DEGRADED',
      'location': {'lat': -2.17, 'lon': -79.9},
    });

    expect(stop.source, 'openstreetmap');
    expect(stop.dataState, DataState.degraded);
  });

  test('requests manual origin when location permission is denied', () async {
    final snapshot = await NearbyRepository(
      apiClient: testClient(
        (_) async => jsonResponse(const <String, Object?>{}),
      ),
      connectivity: FakeConnectivityService(),
      locationService: FakeLocationService(permission: LocationAccess.denied),
    ).load();

    expect(snapshot.state.name, 'permission');
  });

  test(
    'maps nearby provider unavailable and never labels stops live',
    () async {
      final snapshot = await NearbyRepository(
        apiClient: testClient((_) async => unavailableResponse()),
        connectivity: FakeConnectivityService(),
        locationService: FakeLocationService(
          permission: LocationAccess.granted,
          position: const GeoCoordinate(latitude: -2.1, longitude: -79.9),
        ),
      ).load();

      expect(snapshot.state.name, 'degraded');
      expect(snapshot.error?.dataState, DataState.unavailable);
      expect(snapshot.stops, isEmpty);
    },
  );

  test('demo nearby uses the wider seeded catalog radius', () async {
    final transport = FunctionTransport((request) async {
      expect(request.uri.path, '/v1/transit/stops/nearby');
      expect(request.uri.queryParameters['radiusM'], '3000');
      return jsonResponse(const <Object?>[]);
    });
    final snapshot = await NearbyRepository(
      apiClient: ApiClient(
        config: const AppConfig(apiBaseUrl: 'https://api.test'),
        transport: transport,
        maxRetries: 0,
      ),
      connectivity: FakeConnectivityService(),
      locationService: FakeLocationService(
        permission: LocationAccess.granted,
        position: const GeoCoordinate(latitude: -2.17, longitude: -79.9),
      ),
      config: const AppConfig(demoDataEnabled: true),
    ).load();

    expect(snapshot.state, UxState.empty);
    expect(transport.requests, hasLength(1));
  });

  test('preserves nearby stop coordinates for the map', () async {
    final snapshot = await NearbyRepository(
      apiClient: testClient(
        (_) async => jsonResponse([
          <String, Object?>{
            'id': 'stop-1',
            'name': 'Parada Centro',
            'location': <String, Object?>{'lat': -2.17, 'lon': -79.90},
            'distanceM': 120,
            'dataState': 'DEGRADED',
          },
        ]),
      ),
      connectivity: FakeConnectivityService(),
      locationService: FakeLocationService(
        permission: LocationAccess.granted,
        position: const GeoCoordinate(latitude: -2.17, longitude: -79.90),
      ),
    ).load();

    expect(snapshot.stops.single.latitude, -2.17);
    expect(snapshot.stops.single.longitude, -79.90);
    expect(snapshot.origin?.latitude, -2.17);
  });
}
