import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/modules/planner/pages/planner_pages.dart';

import 'package:yegamo_app/modules/onboarding/task_five_app.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test/modules/test_support.dart';
import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('entry to manual permission and planning', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final storage = InMemoryLocalStorage();
    final apiClient = testClient((request) async {
      if (request.uri.path == '/v1/journeys/plan') {
        return jsonResponse(validPlanBody());
      }
      return unavailableResponse();
    });

    await tester.pumpWidget(
      TaskFiveApp(
        config: const AppConfig(reduceMotion: true),
        apiClient: apiClient,
        localStorage: storage,
        connectivityService: FakeConnectivityService(),
        locationService: FakeLocationService(permission: LocationAccess.denied),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sabe cuándo salir'), findsOneWidget);

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('onboarding_next')));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('permission_manual')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('permission_manual')));
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.pushNamed(AppRoutes.planner);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const ValueKey('planner_origin')),
      '-2.10, -79.90',
    );
    await tester.enterText(
      find.byKey(const ValueKey('planner_destination')),
      '-2.20, -79.80',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('planner_calculate')));
    await tester.tap(find.byKey(const ValueKey('planner_calculate')));
    // El cálculo es transitorio (Cargando); el VM decide cuándo avanzar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlternativesPage), findsOneWidget);
    expect(find.textContaining('EN VIVO'), findsNothing);
    expect(find.textContaining('32 min'), findsWidgets);
  });
}
