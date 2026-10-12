import 'dart:async';

import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/services/api_client.dart';

/// Test-only catalog for the approved prototype baseline.
///
/// Nothing in this file is used by the production app. The values deliberately
/// describe screen structure and UX states, not transport availability or
/// provider data.
enum PrototypeUxState {
  ok,
  loading,
  empty,
  error,
  offline,
  stale,
  degraded,
  permission,
  nocoverage,
}

class PrototypeScreenFixture {
  const PrototypeScreenFixture({
    required this.number,
    required this.title,
    required this.route,
    required this.states,
  });

  final int number;
  final String title;
  final String route;
  final Set<PrototypeUxState> states;
}

const prototypeUxStates = <PrototypeUxState>[
  PrototypeUxState.ok,
  PrototypeUxState.loading,
  PrototypeUxState.empty,
  PrototypeUxState.error,
  PrototypeUxState.offline,
  PrototypeUxState.stale,
  PrototypeUxState.degraded,
  PrototypeUxState.permission,
  PrototypeUxState.nocoverage,
];

const prototypeScreenFixtures = <PrototypeScreenFixture>[
  PrototypeScreenFixture(
    number: 1,
    title: 'Splash',
    route: AppRoutes.splash,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.error,
    },
  ),
  PrototypeScreenFixture(
    number: 2,
    title: 'Onboarding',
    route: AppRoutes.onboarding,
    states: {PrototypeUxState.ok, PrototypeUxState.loading},
  ),
  PrototypeScreenFixture(
    number: 3,
    title: 'Permisos',
    route: AppRoutes.permissions,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.permission,
      PrototypeUxState.error,
      PrototypeUxState.offline,
    },
  ),
  PrototypeScreenFixture(
    number: 4,
    title: 'Inicio',
    route: AppRoutes.home,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.empty,
      PrototypeUxState.offline,
      PrototypeUxState.stale,
      PrototypeUxState.degraded,
      PrototypeUxState.permission,
      PrototypeUxState.nocoverage,
    },
  ),
  PrototypeScreenFixture(
    number: 5,
    title: 'Buscar',
    route: AppRoutes.search,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.empty,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.permission,
      PrototypeUxState.nocoverage,
    },
  ),
  PrototypeScreenFixture(
    number: 6,
    title: 'Cercano',
    route: AppRoutes.nearby,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.empty,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.stale,
      PrototypeUxState.degraded,
      PrototypeUxState.permission,
      PrototypeUxState.nocoverage,
    },
  ),
  PrototypeScreenFixture(
    number: 7,
    title: 'Planificador',
    route: AppRoutes.planner,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.empty,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.permission,
      PrototypeUxState.nocoverage,
    },
  ),
  PrototypeScreenFixture(
    number: 8,
    title: 'Cargando',
    route: AppRoutes.loading,
    states: {
      PrototypeUxState.loading,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.degraded,
    },
  ),
  PrototypeScreenFixture(
    number: 9,
    title: 'Alternativas',
    route: AppRoutes.alternatives,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.empty,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.stale,
      PrototypeUxState.degraded,
      PrototypeUxState.nocoverage,
    },
  ),
  PrototypeScreenFixture(
    number: 10,
    title: 'Hora de salida',
    route: AppRoutes.departure,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.stale,
      PrototypeUxState.degraded,
      PrototypeUxState.nocoverage,
    },
  ),
  PrototypeScreenFixture(
    number: 11,
    title: 'Paso a paso',
    route: AppRoutes.stepByStep,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.empty,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.stale,
      PrototypeUxState.degraded,
      PrototypeUxState.nocoverage,
    },
  ),
  PrototypeScreenFixture(
    number: 12,
    title: 'Viaje activo',
    route: AppRoutes.activeJourney,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.stale,
      PrototypeUxState.degraded,
      PrototypeUxState.permission,
      PrototypeUxState.nocoverage,
    },
  ),
  PrototypeScreenFixture(
    number: 13,
    title: 'Alerta de bajada',
    route: AppRoutes.getOffAlert,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.stale,
      PrototypeUxState.degraded,
      PrototypeUxState.nocoverage,
    },
  ),
  PrototypeScreenFixture(
    number: 14,
    title: 'Guardados',
    route: AppRoutes.saved,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.empty,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.stale,
    },
  ),
  PrototypeScreenFixture(
    number: 15,
    title: 'Rutinas',
    route: AppRoutes.commutes,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.empty,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.stale,
      PrototypeUxState.degraded,
    },
  ),
  PrototypeScreenFixture(
    number: 16,
    title: 'Avisos',
    route: AppRoutes.notifications,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.empty,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.stale,
      PrototypeUxState.degraded,
    },
  ),
  PrototypeScreenFixture(
    number: 17,
    title: 'Ajustes',
    route: AppRoutes.settings,
    states: {
      PrototypeUxState.ok,
      PrototypeUxState.loading,
      PrototypeUxState.empty,
      PrototypeUxState.error,
      PrototypeUxState.offline,
      PrototypeUxState.permission,
    },
  ),
];

/// Deterministic clock for fixture payloads. Production code never reads it.
class PrototypeFixtureClock {
  PrototypeFixtureClock(this._now);

  DateTime _now;

  DateTime get now => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

/// In-memory transport used only by widget/integration tests.
class PrototypeFixtureTransport implements HttpTransport {
  PrototypeFixtureTransport({required this.clock, this.onRequest});

  final PrototypeFixtureClock clock;
  final FutureOr<TransportResponse> Function(
    HttpRequest request,
    PrototypeFixtureClock clock,
  )?
  onRequest;
  final List<HttpRequest> requests = <HttpRequest>[];

  @override
  Future<TransportResponse> send(HttpRequest request) async {
    requests.add(request);
    final response = onRequest?.call(request, clock);
    return response is Future<TransportResponse>
        ? response
        : response ?? _unavailable();
  }

  TransportResponse _unavailable() => TransportResponse(
    statusCode: 503,
    headers: const {'x-trace-id': 'fixture-unavailable'},
    body: const <String, Object?>{
      'code': 'PROVIDER_UNAVAILABLE',
      'message': 'Fixture sin fuente autorizada.',
      'details': <String, Object?>{
        'dataState': 'UNAVAILABLE',
        'retryable': false,
      },
      'traceId': 'fixture-unavailable',
    },
  );
}

Map<String, Object?> prototypeJourneyPlanFixture(
  PrototypeFixtureClock clock,
) => <String, Object?>{
  'planId': '00000000-0000-4000-8000-000000000001',
  'recommendedLeaveAt': clock.now
      .add(const Duration(minutes: 12))
      .toIso8601String(),
  'arrivalWindow': <String, Object?>{
    'from': clock.now.add(const Duration(minutes: 40)).toIso8601String(),
    'to': clock.now.add(const Duration(minutes: 50)).toIso8601String(),
  },
  'dataState': 'DEGRADED',
  'options': <Object?>[
    <String, Object?>{
      'id': '00000000-0000-4000-8000-000000000002',
      'durationMin': 32,
      'walkMin': 8,
      'transfers': 1,
      'reliability': <String, Object?>{
        'score': 70,
        'level': 'MEDIUM',
        'sampleSize': 4,
      },
      'dataQuality': <String, Object?>{
        'freshness': 'UNKNOWN',
        'dataState': 'DEGRADED',
        'liveVehicle': false,
        'observedAt': null,
        'providerDisplayName': null,
        'sourceAuthorized': false,
      },
      'legs': <Object?>[
        <String, Object?>{
          'mode': 'WALK',
          'durationMin': 8,
          'from': <String, Object?>{'lat': -2.17, 'lon': -79.90},
          'to': <String, Object?>{'lat': -2.17, 'lon': -79.90},
          'instructions': <String>['Camina al punto de origen manual.'],
        },
        <String, Object?>{
          'mode': 'TRANSIT',
          'durationMin': 24,
          'from': <String, Object?>{'lat': -2.17, 'lon': -79.90},
          'to': <String, Object?>{'lat': -2.20, 'lon': -79.80},
          'instructions': <String>['Continúa con la información disponible.'],
        },
      ],
    },
  ],
};

Map<String, Object?> prototypeActiveJourneyFixture({
  required PrototypeFixtureClock clock,
  String status = 'ACTIVE',
  int currentStep = 0,
  String dataState = 'DEGRADED',
}) => <String, Object?>{
  'id': '00000000-0000-4000-8000-000000000003',
  'planId': '00000000-0000-4000-8000-000000000001',
  'optionId': '00000000-0000-4000-8000-000000000002',
  'status': status,
  'dataState': dataState,
  'currentStep': currentStep,
  'totalSteps': 2,
  'instruction': 'Camina hasta el siguiente tramo.',
  'nextStop': 'Parada de referencia',
  'eta': null,
  'observedAt': null,
  'sourceAuthorized': false,
  'liveVehicle': false,
  'fixtureAt': clock.now.toIso8601String(),
};
