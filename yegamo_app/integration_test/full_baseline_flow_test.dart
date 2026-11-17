import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/shared/design_system/yg_components.dart';
import 'package:yegamo_app/modules/journey/pages/journey_pages.dart';
import 'package:yegamo_app/modules/nearby/pages/nearby_page.dart';
import 'package:yegamo_app/modules/planner/pages/planner_pages.dart';
import 'package:yegamo_app/modules/search/pages/search_page.dart';

import 'package:yegamo_app/modules/onboarding/task_five_app.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test/fixtures/prototype_states.dart';
import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'first launch → journey → alert → retention covers the baseline flow',
    (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
      final clock = PrototypeFixtureClock(DateTime.utc(2026, 10, 12, 12));
      var progressCalls = 0;
      final transport = PrototypeFixtureTransport(
        clock: clock,
        onRequest: (request, fixtureClock) {
          final path = request.uri.path;
          if (path.endsWith('/journeys/plan')) {
            return _json(prototypeJourneyPlanFixture(fixtureClock));
          }
          if (path.endsWith('/start')) {
            return _json(prototypeActiveJourneyFixture(clock: fixtureClock));
          }
          if (path.contains('/progress')) {
            progressCalls += 1;
            return _json(
              prototypeActiveJourneyFixture(
                clock: fixtureClock,
                currentLegIndex: progressCalls.clamp(0, 1).toInt(),
              ),
            );
          }
          if (path.contains('/finish')) {
            return _json(
              prototypeActiveJourneyFixture(
                clock: fixtureClock,
                status: 'COMPLETED',
                currentLegIndex: 1,
              ),
            );
          }
          // Provider-dependent discovery remains unavailable in this fixture.
          // The planning response above is an explicit test fixture and is not
          // enabled by AppConfig or exposed as production data.
          return _json(const <String, Object?>{
            'code': 'PROVIDER_UNAVAILABLE',
            'message': 'Fixture sin fuente autorizada.',
            'details': <String, Object?>{
              'dataState': 'UNAVAILABLE',
              'retryable': false,
            },
            'traceId': 'fixture-unavailable',
          }, statusCode: 503);
        },
      );
      final storage = InMemoryLocalStorage();

      await tester.pumpWidget(
        TaskFiveApp(
          config: const AppConfig(reduceMotion: true, demoDataEnabled: false),
          apiClient: ApiClient(
            config: const AppConfig(apiBaseUrl: 'https://fixture.test'),
            transport: transport,
            maxRetries: 0,
            traceIdFactory: () => 'integration-trace',
          ),
          localStorage: storage,
          connectivityService: FakeConnectivityService(),
          locationService: FakeLocationService(
            permission: LocationAccess.denied,
          ),
        ),
      );

      // Bootstrap resolves to the first interactive onboarding surface. Splash
      // has its own route registration and is covered by the baseline catalog;
      // this end-to-end flow avoids coupling to its wall-clock animation.
      await tester.pumpAndSettle();
      expect(find.text('Sabe cuándo salir'), findsOneWidget);

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );

      for (var index = 0; index < 3; index++) {
        await tester.tap(find.byKey(const ValueKey('onboarding_next')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('permission_manual')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('permission_manual')));
      await tester.pumpAndSettle();
      expect(find.text('Inicio'), findsWidgets);

      // Discovery routes are exercised with provider-unavailable semantics.
      navigator.pushNamed(AppRoutes.search);
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      navigator.pushNamed(AppRoutes.nearby);
      await tester.pumpAndSettle();
      expect(find.byType(NearbyPage), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();

      navigator.pushNamed(AppRoutes.planner);
      await tester.pumpAndSettle();
      expect(find.byType(PlannerPage), findsOneWidget);

      navigator.pushNamed(AppRoutes.loading);
      await tester.pumpAndSettle();
      expect(find.byType(PlannerLoadingPage), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('planner_origin')),
        '-2.1700, -79.9000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('planner_destination')),
        '-2.2000, -79.8000',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('planner_calculate')));
      await tester.tap(find.byKey(const ValueKey('planner_calculate')));
      await tester.pumpAndSettle();
      expect(find.byType(AlternativesPage), findsOneWidget);
      expect(find.text('EN VIVO'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('alternatives_continue')));
      await tester.pumpAndSettle();
      expect(find.byType(DeparturePage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('departure_steps')));
      await tester.pumpAndSettle();
      expect(find.byType(PlannerStepsPage), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('journey_start')));
      await tester.pumpAndSettle();
      expect(find.byType(ActiveJourneyPage), findsOneWidget);
      expect(find.text('EN VIVO'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('journey_next_step')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journey_open_get_off')));
      await tester.pumpAndSettle();
      expect(find.byType(GetOffAlertPage), findsOneWidget);

      // The terminal arrived state is a journey state, not an 18th screen.
      navigator.pop();
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      navigator.pushNamed(
        AppRoutes.activeJourney,
        arguments: const <String, String>{
          'planId': '00000000-0000-4000-8000-000000000001',
          'optionId': '00000000-0000-4000-8000-000000000002',
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journey_next_step')));
      await tester.pumpAndSettle();
      expect(find.text('LLEGASTE A TU DESTINO'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('journey_finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalizar').last);
      await tester.pumpAndSettle();

      navigator.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(YgTabBar), matching: find.text('Guardados')));
      await tester.pumpAndSettle();
      expect(find.text('Guardados'), findsWidgets);
      await tester.tap(find.descendant(of: find.byType(YgTabBar), matching: find.text('Rutinas')));
      await tester.pumpAndSettle();
      expect(find.text('Rutinas'), findsWidgets);
      await tester.tap(find.descendant(of: find.byType(YgTabBar), matching: find.text('Avisos')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Avisos'), findsWidgets);
      navigator.pushNamed(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(find.text('Ajustes'), findsOneWidget);

      expect(progressCalls, 2);
      expect(
        transport.requests
            .where((request) => request.uri.path.contains('/progress'))
            .every((request) => (request.body! as Map)['location'] == null),
        isTrue,
      );
    },
  );
}

TransportResponse _json(Object body, {int statusCode = 200}) =>
    TransportResponse(
      statusCode: statusCode,
      headers: const {'x-trace-id': 'integration-trace'},
      body: body,
    );
