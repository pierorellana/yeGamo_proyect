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
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';
import '../../support/fakes.dart';

Future<SessionManager> _signedIn(LocalStorage storage) async {
  final session = SessionManager(storage);
  await session.setAuthenticated(accessToken: 'test-token');
  return session;
}

Map<String, Object?> _leg(String mode, String instruction) => {
  'mode': mode,
  'from': {'lat': -2.17, 'lon': -79.9},
  'to': {'lat': -2.14, 'lon': -79.89},
  'durationMin': 5,
  'departureAt': null,
  'arrivalAt': null,
  'instructions': [instruction],
  'routeId': null,
  'fromStopId': null,
  'toStopId': null,
};

/// Respuesta con la forma exacta del schema `ActiveJourney` de OpenAPI.
Map<String, Object?> activeJourneyBody({
  String status = 'ACTIVE',
  String dataState = 'DEGRADED',
  int currentLegIndex = 0,
}) => <String, Object?>{
  'id': 'journey-1',
  'planId': 'plan-1',
  'optionId': 'option-1',
  'status': status,
  'currentLegIndex': currentLegIndex,
  'legs': [
    _leg('WALK', 'Camina hasta la parada'),
    _leg('TRANSIT', 'Aborda el servicio'),
  ],
  'eta': null,
  'dataState': dataState,
  'dataQuality': {
    'freshness': 'UNKNOWN',
    'dataState': dataState,
    'liveVehicle': false,
    'observedAt': null,
    'providerDisplayName': null,
    'sourceAuthorized': false,
  },
  'events': <Object?>[],
};

void main() {
  test('uses the canonical start and progress routes and bodies', () async {
    final storage = InMemoryLocalStorage();
    final consent = LocationConsentStore(storage);
    final requests = <HttpRequest>[];
    final client = testClient((request) async {
      requests.add(request);
      if (request.method == HttpMethod.post) {
        return jsonResponse(activeJourneyBody(), statusCode: 201);
      }
      return jsonResponse(activeJourneyBody(currentLegIndex: 1));
    });
    final location = FakeLocationService(
      permission: LocationAccess.granted,
      position: const GeoCoordinate(latitude: -2.123456, longitude: -79.9),
    );
    final repo = ActiveJourneyRepository(
      client,
      storage,
      FakeConnectivityService(),
      PrivacyAwareLocationReader(location, consent),
      await _signedIn(storage),
    );
    final vm = JourneyViewModel(repo);

    await vm.start('plan-1', 'option-1');
    await vm.updateProgress(const JourneyProgress(currentLegIndex: 1));

    final start = requests[0];
    expect(start.method, HttpMethod.post);
    expect(start.uri.path, '/v1/journeys/plan-1/options/option-1/start');
    expect(start.body, isNull);
    expect(start.headers['Idempotency-Key'], startsWith('journey-start-plan-1-option-1-'));

    final progress = requests[1];
    expect(progress.method, HttpMethod.patch);
    expect(progress.uri.path, '/v1/active-journeys/journey-1/progress');
    final body = progress.body! as Map<String, Object?>;
    // Exactamente los campos que acepta el API (additionalProperties: false).
    expect(body.keys.toSet(), {'currentLegIndex', 'occurredAt'});
    expect(body['currentLegIndex'], 1);
    expect(DateTime.parse(body['occurredAt']! as String).isUtc, isTrue);

    expect(vm.state.journey?.dataState, DataState.degraded);
    expect(vm.state.journey?.currentLegIndex, 1);
    expect(vm.state.journey?.totalLegs, 2);
    expect(vm.state.journey?.eta, isNull);
    final cache = await storage.read(YeGamoStorageKeys.activeJourney);
    expect(cache, isNot(contains('2.123456')));
  });

  test('sends precise location only with consent and keeps it out of the cache', () async {
    final storage = InMemoryLocalStorage();
    final consent = LocationConsentStore(storage);
    await consent.set(true);
    final requests = <HttpRequest>[];
    final client = testClient((request) async {
      requests.add(request);
      return jsonResponse(activeJourneyBody());
    });
    final repo = ActiveJourneyRepository(
      client,
      storage,
      FakeConnectivityService(),
      PrivacyAwareLocationReader(
        FakeLocationService(
          permission: LocationAccess.granted,
          position: const GeoCoordinate(latitude: -2.123456, longitude: -79.9),
        ),
        consent,
      ),
      await _signedIn(storage),
    );
    final vm = JourneyViewModel(repo);
    await vm.start('plan-1', 'option-1');
    await vm.updateProgress(const JourneyProgress(currentLegIndex: 1));

    final body = requests.last.body! as Map<String, Object?>;
    expect(body['location'], {'lat': -2.123456, 'lon': -79.9});
    expect(await storage.read(YeGamoStorageKeys.activeJourney), isNot(contains('2.123456')));
  });

  test('rejects a response that does not satisfy the contract', () async {
    final storage = InMemoryLocalStorage();
    final consent = LocationConsentStore(storage);
    final repo = ActiveJourneyRepository(
      testClient((_) async => jsonResponse({'id': 'j', 'currentStep': 1})),
      storage,
      FakeConnectivityService(),
      PrivacyAwareLocationReader(FakeLocationService(), consent),
      await _signedIn(storage),
    );
    final result = await repo.start('plan-1', 'option-1');

    expect(result.journey, isNull);
    expect(result.error?.code, 'INVALID_RESPONSE');
    expect(await storage.read(YeGamoStorageKeys.activeJourney), isNull);
  });

  test('guest journeys are local, built from the real plan option and never call the API', () async {
    final storage = InMemoryLocalStorage();
    final consent = LocationConsentStore(storage);
    final requests = <HttpRequest>[];
    final repo = ActiveJourneyRepository(
      testClient((request) async {
        requests.add(request);
        return jsonResponse(activeJourneyBody());
      }),
      storage,
      FakeConnectivityService(),
      PrivacyAwareLocationReader(FakeLocationService(), consent),
      SessionManager(storage),
    );
    final option = JourneyOption.fromJson({
      'id': 'opt-1',
      'durationMin': 10,
      'walkMin': 10,
      'transfers': 0,
      'reliability': {'score': null, 'level': null, 'sampleSize': null},
      'dataQuality': {'dataState': 'DEGRADED', 'liveVehicle': false, 'sourceAuthorized': false},
      'legs': [_leg('WALK', 'Uno'), _leg('WALK', 'Dos')],
    });

    final started = await repo.start('plan-1', 'opt-1', option: option);
    expect(started.journey?.legs, hasLength(2));
    expect(started.journey?.dataState, DataState.degraded);
    expect(started.journey?.sourceAuthorized, isFalse);
    expect(ActiveJourneyRepository.isLocal(started.journey!), isTrue);

    final moved = await repo.updateProgress(const JourneyProgress(currentLegIndex: 1));
    expect(moved.journey?.currentLegIndex, 1);
    final done = await repo.finish();
    expect(done.journey?.status, JourneyStatus.finished);
    expect(requests, isEmpty);
    expect(await storage.read(YeGamoStorageKeys.activeJourney), isNull);
  });

  test('a guest without a plan option gets an explicit sign-in error, not a fake journey', () async {
    final storage = InMemoryLocalStorage();
    final consent = LocationConsentStore(storage);
    final repo = ActiveJourneyRepository(
      testClient((_) async => jsonResponse(activeJourneyBody())),
      storage,
      FakeConnectivityService(),
      PrivacyAwareLocationReader(FakeLocationService(), consent),
      SessionManager(storage),
    );
    final result = await repo.start('plan-1', 'opt-1');
    expect(result.journey, isNull);
    expect(result.error?.code, 'AUTH_REQUIRED');
  });

  test('maps API statuses and never sends UI-only states', () {
    expect(JourneyStatusParsing.fromApi('COMPLETED'), JourneyStatus.finished);
    expect(JourneyStatusParsing.fromApi('CANCELLED'), JourneyStatus.canceled);
    expect(JourneyStatusParsing.fromApi('ABANDONED'), JourneyStatus.canceled);
    expect(JourneyStatusParsing.fromApi('PLANNED'), JourneyStatus.active);
    expect(JourneyStatus.getOffAlert.apiValue, 'ACTIVE');
    expect(JourneyStatus.arrived.apiValue, 'ACTIVE');
  });

  test('offline active journey is marked offline cache and does not fake ETA', () async {
    final storage = InMemoryLocalStorage();
    final consent = LocationConsentStore(storage);
    final repo = ActiveJourneyRepository(
      testClient((_) async => jsonResponse(activeJourneyBody())),
      storage,
      FakeConnectivityService(online: false),
      PrivacyAwareLocationReader(FakeLocationService(), consent),
      await _signedIn(storage),
    );
    final vm = JourneyViewModel(repo);

    await vm.start('plan-1', 'option-1');

    expect(vm.state.uxState, UxState.offline);
    expect(vm.state.journey, isNull);
  });

  test('permission is an explicit recoverable state', () async {
    final storage = InMemoryLocalStorage();
    final consent = LocationConsentStore(storage);
    final vm = JourneyViewModel(
      ActiveJourneyRepository(
        testClient((_) async => jsonResponse(activeJourneyBody())),
        storage,
        FakeConnectivityService(),
        PrivacyAwareLocationReader(FakeLocationService(), consent),
      await _signedIn(storage),
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
      await storage.write(YeGamoStorageKeys.sessionMode, 'authenticated');
      await storage.writeSecure('access_token', 'test-token');
      final ApiClient client = testClient((request) async {
        if (request.uri.path.contains('active-journeys') ||
            request.uri.path.endsWith('/start')) {
          final body = request.body;
          final step = body is Map && body['currentLegIndex'] is int
              ? body['currentLegIndex'] as int
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
      // Espera (con tope) a que el viaje responda; no depende de un retardo fijo.
      final journeys = tester
          .element(find.byType(Navigator).first)
          .read<JourneyViewModel>();
      for (var i = 0; i < 100 && journeys.state.journey == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 1500));
      return navigator;
    }

    testWidgets('viaje activo muestra instrucción, calidad y sin EN VIVO', (tester) async {
      await pumpJourney(tester, journeyFor: (_) => activeJourneyBody());

      expect(find.text('Camina hasta la parada'), findsOneWidget);
      expect(find.text('Paso 1 de 2'), findsOneWidget);
      expect(find.text('DEGRADADO'), findsOneWidget);
      expect(find.text('EN VIVO'), findsNothing);
      // Sin ETA en el viaje no se inventa una hora de llegada.
      expect(find.text('Sin estimación disponible'), findsOneWidget);
      expect(find.byKey(const ValueKey('journey_next_step')), findsOneWidget);
      expect(find.byKey(const ValueKey('journey_update_location')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('alerta de bajada es un estado de pantalla y se cierra con Entendido', (tester) async {
      final navigator = await pumpJourney(
        tester,
        journeyFor: (_) => activeJourneyBody(),
      );
      tester
          .element(find.byType(Navigator).first)
          .read<JourneyViewModel>()
          .showGetOffAlert();
      await tester.pump();
      expect(find.byKey(const ValueKey('journey_open_get_off')), findsOneWidget);

      navigator.pushNamed(AppRoutes.getOffAlert);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));

      // Sin nombres de parada en el contrato no se inventa ninguno.
      expect(find.text('Prepara tu bajada'), findsOneWidget);
      expect(find.text('PRÓXIMA PARADA · BÁJATE'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Prepara tu bajada'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('llegada es un estado del viaje con acciones', (tester) async {
      await pumpJourney(tester, journeyFor: (_) => activeJourneyBody());
      tester
          .element(find.byType(Navigator).first)
          .read<JourneyViewModel>()
          .markArrived();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('LLEGASTE A TU DESTINO'), findsOneWidget);
      expect(find.byKey(const ValueKey('journey_finish')), findsOneWidget);
      expect(find.text('Volver al inicio'), findsOneWidget);
      expect(find.text('EN VIVO'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
