import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/modules/journey/pages/journey_pages.dart';
import 'package:yegamo_app/modules/planner/pages/planner_pages.dart';

import 'package:yegamo_app/modules/onboarding/task_five_app.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test/modules/journey/journey_test.dart' show activeJourneyBody;
import '../test/modules/test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plans, starts active journey, keeps quality and saves a place', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final storage = InMemoryLocalStorage();
    await storage.write(YeGamoStorageKeys.onboardingCompleted, 'true');
    final apiClient = testClient((request) async {
      if (request.uri.path == '/v1/journeys/plan') {
        return jsonResponse(validPlanBody());
      }
      if (request.uri.path == '/v1/active-journeys') {
        return jsonResponse(activeJourneyBody());
      }
      if (request.uri.path.contains('/progress')) {
        return jsonResponse({...activeJourneyBody(), 'currentStep': 1});
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
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    await navigator.pushNamed(AppRoutes.planner);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('planner_origin')), '-2.10, -79.90');
    await tester.enterText(find.byKey(const ValueKey('planner_destination')), '-2.20, -79.80');
    await tester.ensureVisible(find.byKey(const ValueKey('planner_calculate')));
    await tester.tap(find.byKey(const ValueKey('planner_calculate')));
    await tester.pumpAndSettle();
    navigator.pushNamed(AppRoutes.stepByStep);
    await tester.pumpAndSettle();
    expect(find.byType(PlannerStepsPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('journey_start')));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveJourneyPage), findsOneWidget);
    expect(find.textContaining('EN VIVO'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('journey_update_location')));
    await tester.pump();
    expect(find.textContaining('Permiso requerido'), findsOneWidget);

    await navigator.pushNamed(AppRoutes.saved);
    await tester.pumpAndSettle();
    expect(find.text('Guardados'), findsWidgets);
  });
}
