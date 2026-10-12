import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/modules/onboarding/task_five_app.dart';
import 'package:yegamo_app/modules/planner/models/planner_models.dart';
import 'package:yegamo_app/modules/planner/providers/planner_view_model.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/modules/journey/models/journey_models.dart';
import 'package:yegamo_app/modules/journey/providers/journey_view_model.dart';
import 'package:yegamo_app/modules/journey/services/active_journey_repository.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

Map<String, Object?> activeJourneyBody({
  String status = 'ACTIVE',
  String dataState = 'DEGRADED',
}) => <String, Object?>{
  'id': 'journey-1',
  'planId': 'plan-1',
  'optionId': 'option-1',
  'status': status,
  'dataState': dataState,
  'currentStep': 0,
  'totalSteps': 2,
  'instruction': 'Camina hasta la parada',
  'nextStop': 'Parada Central',
  'sourceAuthorized': false,
  'liveVehicle': false,
};

void main() {
  test('starts and progresses without persisting a precise coordinate', () async {
    final storage = InMemoryLocalStorage();
    final consent = LocationConsentStore(storage);
    final requests = <HttpRequest>[];
    final client = testClient((request) async {
      requests.add(request);
      if (request.uri.path.endsWith('/active-journeys')) {
        return jsonResponse(activeJourneyBody());
      }
      return jsonResponse({...activeJourneyBody(), 'currentStep': 1});
    });
    final location = FakeLocationService(
      permission: LocationAccess.granted,
      position: const GeoCoordinate(latitude: -2.1, longitude: -79.9),
    );
    final repo = ActiveJourneyRepository(
      client,
      storage,
      FakeConnectivityService(),
      consent,
      PrivacyAwareLocationReader(location, consent),
    );
    final vm = JourneyViewModel(repo);

    await vm.start('plan-1', 'option-1');
    await vm.updateProgress(const JourneyProgress(stepIndex: 1, sequence: 1));

    expect(vm.state.journey?.dataState, DataState.degraded);
    expect(requests.first.body, isA<Map<String, Object?>>());
    expect((requests.first.body! as Map)['location'], isNull);
    expect(
      requests[1].headers['Idempotency-Key'],
      'journey-progress-journey-1-1',
    );
    final cache = await storage.read(YeGamoStorageKeys.activeJourney);
    expect(cache, isNot(contains('-2.1')));
  });

  test('offline active journey is marked offline cache and does not fake ETA', () async {
    final storage = InMemoryLocalStorage();
    final consent = LocationConsentStore(storage);
    final repo = ActiveJourneyRepository(
      testClient((_) async => jsonResponse(activeJourneyBody())),
      storage,
      FakeConnectivityService(online: false),
      consent,
      PrivacyAwareLocationReader(FakeLocationService(), consent),
    );
    final vm = JourneyViewModel(repo);

    await vm.start('plan-1', 'option-1');

    expect(vm.state.uxState, UxState.offline);
    expect(vm.state.journey, isNull);
  });

  test('permission is an explicit recoverable state', () {
    final storage = InMemoryLocalStorage();
    final consent = LocationConsentStore(storage);
    final vm = JourneyViewModel(
      ActiveJourneyRepository(
        testClient((_) async => jsonResponse(activeJourneyBody())),
        storage,
        FakeConnectivityService(),
        consent,
        PrivacyAwareLocationReader(FakeLocationService(), consent),
      ),
    );

    vm.showPermissionRequired();

    expect(vm.state.uxState, UxState.permission);
  });

  group('pantallas del viaje', () {
    Future<NavigatorState> pumpJourney(
      WidgetTester tester, {
      required Map<String, Object?> Function(int step) journeyFor,
    }) async {
      final geist = FontLoader('Geist');
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        final bytes = File('assets/fonts/Geist-$w.ttf').readAsBytesSync();
        geist.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await geist.load();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final storage = InMemoryLocalStorage();
      await storage.write('onboarding_completed', 'true');
      final ApiClient client = testClient((request) async {
        if (request.uri.path.contains('active-journeys')) {
          final body = request.body;
          final step = body is Map && body['stepIndex'] is int
              ? body['stepIndex'] as int
              : 0;
          return jsonResponse(journeyFor(step));
        }
        return jsonResponse(validPlanBody());
      });
      await tester.pumpWidget(
        TaskFiveApp(
          config: const AppConfig(),
          apiClient: client,
          localStorage: storage,
          connectivityService: FakeConnectivityService(),
          locationService: FakeLocationService(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      final planner = tester.element(find.byType(Navigator).first).read<PlannerViewModel>();
      planner.setPoints(
        origin: const JourneyPoint(latitude: -2.1, longitude: -79.9),
        destination: const JourneyPoint(latitude: -2.2, longitude: -79.8),
      );
      await tester.runAsync(planner.calculate);
      navigator.pushNamed(
        AppRoutes.activeJourney,
        arguments: const <String, String>{
          'planId': '00000000-0000-0000-0000-000000000001',
          'optionId': '00000000-0000-0000-0000-000000000002',
        },
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 1500));
      return navigator;
    }

    testWidgets('viaje activo muestra instrucción, calidad y sin EN VIVO', (tester) async {
      await pumpJourney(tester, journeyFor: (_) => activeJourneyBody());

      expect(find.text('Camina hasta la parada'), findsOneWidget);
      expect(find.text('Próxima parada: Parada Central'), findsOneWidget);
      expect(find.text('DEGRADADO'), findsOneWidget);
      expect(find.text('EN VIVO'), findsNothing);
      // Sin ETA en el viaje no se inventa una hora de llegada.
      expect(find.text('Sin estimación disponible'), findsOneWidget);
      expect(find.byKey(const ValueKey('journey_next_step')), findsOneWidget);
      expect(find.byKey(const ValueKey('journey_update_location')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('alerta de bajada muestra la parada y se cierra con Entendido', (tester) async {
      final navigator = await pumpJourney(
        tester,
        journeyFor: (_) => activeJourneyBody(status: 'GET_OFF_ALERT'),
      );
      expect(find.byKey(const ValueKey('journey_open_get_off')), findsOneWidget);

      navigator.pushNamed(AppRoutes.getOffAlert);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));

      expect(find.text('Parada Central'), findsOneWidget);
      expect(find.text('PRÓXIMA PARADA · BÁJATE'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Parada Central'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('llegada es un estado del viaje con acciones', (tester) async {
      await pumpJourney(
        tester,
        journeyFor: (_) => <String, Object?>{
          ...activeJourneyBody(status: 'ARRIVED'),
          'currentStep': 2,
        },
      );

      expect(find.text('LLEGASTE A TU DESTINO'), findsOneWidget);
      expect(find.byKey(const ValueKey('journey_finish')), findsOneWidget);
      expect(find.text('Volver al inicio'), findsOneWidget);
      expect(find.text('EN VIVO'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
