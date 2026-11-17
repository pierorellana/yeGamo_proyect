import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yegamo_app/main.dart';
import 'package:yegamo_app/shared/design_system/yg_components.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';
import '../support/fakes.dart';

void main() {
  test('keeps exactly the approved 17 named baseline routes', () {
    expect(AppRoutes.baseline, hasLength(17));
    expect(AppRoutes.baselineNames.toSet(), hasLength(17));
    expect(AppRoutes.baselineNames, contains(AppRoutes.activeJourney));
    expect(AppRoutes.baselineNames, contains(AppRoutes.getOffAlert));
  });

  testWidgets('root shell keeps four tabs and exposes settings as a route', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await storage.write('onboarding_completed', 'true');
    await tester.pumpWidget(
      YeGamoApp(
        localStorage: storage,
        connectivityService: FakeConnectivityService(online: false),
        locationService: FakeLocationService(),
      ),
    );
    await tester.pump();

    expect(find.byType(IndexedStack), findsOneWidget);
    expect(find.byType(YgTabBar), findsOneWidget);
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Guardados'), findsOneWidget);
    expect(find.text('Rutinas'), findsOneWidget);
    expect(find.text('Avisos'), findsOneWidget);

    Navigator.of(tester.element(find.byType(YgTabBar))).pushNamed(
      AppRoutes.settings,
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajustes'), findsWidgets);
    expect(find.byType(YgTabBar), findsNothing);
  });

  testWidgets('root tabs change without replacing the IndexedStack', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await storage.write('onboarding_completed', 'true');
    await tester.pumpWidget(
      YeGamoApp(
        localStorage: storage,
        connectivityService: FakeConnectivityService(online: false),
        locationService: FakeLocationService(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Rutinas'));
    await tester.pump();

    expect(find.text('Rutinas'), findsWidgets);
    expect(find.byType(IndexedStack), findsOneWidget);
  });
}
