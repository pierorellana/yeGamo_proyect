import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/main.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

Future<void> _openNearby(
  WidgetTester tester, {
  LocationAccess access = LocationAccess.granted,
  GeoCoordinate? position = const GeoCoordinate(
    latitude: -2.17,
    longitude: -79.9,
  ),
  bool unavailable = false,
}) async {
  final storage = InMemoryLocalStorage();
  await storage.write('onboarding_completed', 'true');
  await tester.pumpWidget(
    YeGamoApp(
      localStorage: storage,
      apiClient: testClient(
        (_) async => unavailable
            ? unavailableResponse()
            : jsonResponse(<String, Object?>{
                'stops': <Object?>[
                  <String, Object?>{
                    'id': 's1',
                    'name': 'Parada Uno',
                    'distanceM': 180,
                    'dataState': 'CURRENT',
                  },
                ],
              }),
      ),
      connectivityService: FakeConnectivityService(),
      locationService: FakeLocationService(
        permission: access,
        position: position,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  Navigator.of(
    tester.element(find.byType(Scaffold).first),
  ).pushNamed(AppRoutes.nearby);
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('nearby lists stops and never labels them live', (tester) async {
    await _openNearby(tester);

    expect(find.text('Cerca de ti'), findsWidgets);
    expect(find.text('Parada Uno'), findsWidgets);
    expect(find.text('Llegadas no disponibles'), findsOneWidget);
    expect(find.textContaining('En vivo'), findsNothing);
  });

  testWidgets('nearby keeps the manual origin form reachable', (tester) async {
    await _openNearby(tester);
    await tester.dragFrom(const Offset(195, 450), const Offset(0, -400));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byKey(const ValueKey('nearby_manual_origin')), findsOneWidget);
    expect(find.byKey(const ValueKey('nearby_refresh')), findsOneWidget);
  });

  testWidgets('nearby asks for permission without inventing stops', (
    tester,
  ) async {
    await _openNearby(
      tester,
      access: LocationAccess.denied,
      position: null,
    );

    expect(find.text('Necesitamos tu ubicación'), findsOneWidget);
    expect(find.text('Parada Uno'), findsNothing);
  });

  testWidgets('nearby degraded provider shows an honest state', (tester) async {
    await _openNearby(tester, unavailable: true);

    expect(find.text('Datos limitados'), findsWidgets);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
