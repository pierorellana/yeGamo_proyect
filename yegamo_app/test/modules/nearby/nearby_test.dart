import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/nearby/services/nearby_repository.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';

import '../test_support.dart';

void main() {
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
}
