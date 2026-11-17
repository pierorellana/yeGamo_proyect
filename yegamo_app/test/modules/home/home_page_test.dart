import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/main.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';
import '../../support/fakes.dart';

Future<void> _pumpHome(
  WidgetTester tester, {
  bool online = true,
  LocationAccess access = LocationAccess.granted,
}) async {
  final storage = InMemoryLocalStorage();
  await storage.write('onboarding_completed', 'true');
  await tester.pumpWidget(
    YeGamoApp(
      localStorage: storage,
      apiClient: testClient((_) async => unavailableResponse()),
      connectivityService: FakeConnectivityService(online: online),
      locationService: FakeLocationService(permission: access),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('home never invents a departure time and keeps its keys', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(find.byKey(const ValueKey('home_planner')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_search')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_settings')), findsOneWidget);
    expect(find.byTooltip('Ajustes'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget);
    expect(find.textContaining('EN VIVO'), findsNothing);
    expect(find.text('En vivo'), findsNothing);
  });

  testWidgets('home shows the offline banner and retry', (tester) async {
    await _pumpHome(tester, online: false);

    expect(find.text('Sin conexión'), findsWidgets);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('home explains missing location instead of failing', (
    tester,
  ) async {
    await _pumpHome(tester, access: LocationAccess.denied);

    expect(find.text('Sin ubicación, sin problema'), findsOneWidget);
    expect(find.text('Elegir origen'), findsOneWidget);
    expect(find.text('Elige un origen'), findsOneWidget);
  });
}
