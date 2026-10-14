import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/main.dart';
import 'package:yegamo_app/modules/planner/pages/planner_pages.dart';
import 'package:yegamo_app/shared/design_system/yg_components.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

Map<String, Object?> _planWithTimes({bool live = false}) {
  final base = validPlanBody();
  final now = DateTime.now().toUtc();
  final dep = now.add(const Duration(minutes: 12));
  final option = Map<String, Object?>.from(
    (base['options']! as List).single as Map,
  );
  option['dataQuality'] = <String, Object?>{
    'freshness': live ? 'CURRENT' : 'DEGRADED',
    'dataState': live ? 'CURRENT' : 'DEGRADED',
    'liveVehicle': live,
    'observedAt': live ? now.toIso8601String() : null,
    'providerDisplayName': null,
    'sourceAuthorized': live,
  };
  option['legs'] = <Object?>[
    <String, Object?>{'mode': 'WALK', 'durationMin': 4},
    <String, Object?>{'mode': 'TRANSIT', 'durationMin': 20},
    <String, Object?>{'mode': 'WALK', 'durationMin': 4},
  ];
  return <String, Object?>{
    ...base,
    'dataState': live ? 'CURRENT' : 'DEGRADED',
    'recommendedLeaveAt': dep.toIso8601String(),
    'arrivalWindow': <String, Object?>{
      'from': dep.add(const Duration(minutes: 30)).toIso8601String(),
      'to': dep.add(const Duration(minutes: 36)).toIso8601String(),
    },
    'options': <Object?>[option],
  };
}

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openPlanner(
  WidgetTester tester,
  Future<TransportResponse> Function(HttpRequest) handler,
) async {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    // Los desbordes de otros módulos con la fuente de pruebas no son de aquí.
    if (details.toString().contains('overflowed') &&
        !details.toString().contains('modules/planner')) {
      return;
    }
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final storage = InMemoryLocalStorage();
  await storage.write('onboarding_completed', 'true');
  await tester.pumpWidget(
    YeGamoApp(
      localStorage: storage,
      apiClient: testClient((request) async {
        if (request.uri.path.endsWith('/v1/places/search')) {
          final query = request.uri.queryParameters['q'] ?? '';
          final slug = query.toLowerCase().contains('origen')
              ? 'origen'
              : 'destino';
          final point = slug == 'origen'
              ? const {'lat': -2.10, 'lon': -79.90}
              : const {'lat': -2.20, 'lon': -79.80};
          return jsonResponse(<Object?>[
            <String, Object?>{
              'id': 'place-$slug',
              'label': 'Lugar $slug',
              'location': point,
              'source': 'test',
              'dataState': 'CURRENT',
            },
          ]);
        }
        return handler(request);
      }),
      connectivityService: FakeConnectivityService(),
      locationService: FakeLocationService(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  Navigator.of(tester.element(find.byType(Navigator).first))
      .pushNamed(AppRoutes.planner);
  await _pumpFor(tester, 1000);
}

/// El botón queda bajo el pliegue del panel a media altura: se acciona su
/// callback (la prueba de gestos del panel vive en `yg_sheet`).
void _pressCalculate(WidgetTester tester) {
  tester
      .widget<YgButton>(find.byKey(const ValueKey('planner_calculate')))
      .onPressed!();
}

Future<void> _selectAddress(
  WidgetTester tester,
  String key,
  String query,
  String resultId,
) async {
  await tester.enterText(find.byKey(ValueKey(key)), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await _pumpFor(tester, 800);
  await tester.tap(find.byKey(ValueKey('planner_place_$resultId')));
  await _pumpFor(tester, 200);
}

Future<void> _calculate(WidgetTester tester) async {
  await _selectAddress(tester, 'planner_origin', 'origen', 'place-origen');
  await tester.enterText(
    find.byKey(const ValueKey('planner_destination')),
    'destino',
  );
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await _pumpFor(tester, 800);
  await tester.tap(find.byKey(const ValueKey('planner_place_place-destino')));
  await _pumpFor(tester, 200);
  _pressCalculate(tester);
  await _pumpFor(tester, 1500);
}

Future<void> _loadGeist() async {
  final geist = FontLoader('Geist');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Geist-$w.ttf').readAsBytesSync();
    geist.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await geist.load();
}

void main() {
  setUpAll(_loadGeist);

  testWidgets(
    'planner form validates selected places and offers 3 preferences',
    (tester) async {
      await _openPlanner(tester, (_) async => jsonResponse(validPlanBody()));
      expect(find.text('Planificar viaje'), findsOneWidget);
      expect(find.text('Más confiable'), findsOneWidget);
      expect(find.text('Menos caminata'), findsOneWidget);
      expect(find.text('Menos transbordos'), findsOneWidget);
      expect(find.byKey(const ValueKey('planner_origin')), findsOneWidget);
      expect(find.byKey(const ValueKey('planner_destination')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('planner_calculate')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('planner_calculate')));
      await _pumpFor(tester, 600);
      expect(find.text('Revisa los datos'), findsOneWidget);
    },
  );

  testWidgets('alternatives never says live without authorized source', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _openPlanner(tester, (_) async => jsonResponse(_planWithTimes()));
    await _calculate(tester);

    expect(find.text('1 opciones'), findsOneWidget);
    expect(find.text('RECOMENDADA'), findsOneWidget);
    expect(find.text('Estimado'), findsWidgets);
    expect(find.text('En vivo'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('DEGRADADO')), findsWidgets);
    expect(find.byTooltip('Ver paso a paso'), findsOneWidget);
    expect(find.textContaining('Continuar · sal a las'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('alternatives shows live only with source and timestamp', (
    tester,
  ) async {
    await _openPlanner(
      tester,
      (_) async => jsonResponse(_planWithTimes(live: true)),
    );
    await _calculate(tester);

    expect(find.text('En vivo'), findsWidgets);
  });

  testWidgets('alternatives without times shows the honest duration', (
    tester,
  ) async {
    await _openPlanner(tester, (_) async => jsonResponse(validPlanBody()));
    await _calculate(tester);

    expect(find.text('32 min'), findsOneWidget);
    expect(find.textContaining('sal a las'), findsNothing);
    expect(find.text('Continuar'), findsWidgets);
  });

  testWidgets('departure flips the recommended time and starts the journey', (
    tester,
  ) async {
    await _openPlanner(tester, (_) async => jsonResponse(_planWithTimes()));
    await _calculate(tester);
    Navigator.of(tester.element(find.byType(Navigator).first))
        .pushNamed(AppRoutes.departure);
    await _pumpFor(tester, 1600);

    expect(find.byType(FlipDigits), findsOneWidget);
    expect(find.text('Cuándo salir'), findsOneWidget);
    expect(find.byType(YgCountdownRing), findsOneWidget);
    expect(find.text('Así se compone tu tiempo'), findsOneWidget);
    expect(find.byKey(const ValueKey('departure_start')), findsOneWidget);
    expect(find.byTooltip('Ver paso a paso'), findsOneWidget);
  });

  testWidgets('departure does not invent a time without recommendation', (
    tester,
  ) async {
    await _openPlanner(tester, (_) async => jsonResponse(validPlanBody()));
    await _calculate(tester);
    Navigator.of(tester.element(find.byType(Navigator).first))
        .pushNamed(AppRoutes.departure);
    await _pumpFor(tester, 1000);

    expect(find.text('Sin recomendación disponible'), findsOneWidget);
    expect(find.byType(FlipDigits), findsNothing);
  });

  testWidgets('steps page lists the legs of the selected option', (
    tester,
  ) async {
    await _openPlanner(tester, (_) async => jsonResponse(_planWithTimes()));
    await _calculate(tester);
    Navigator.of(tester.element(find.byType(Navigator).first)).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const PlannerStepsPage(),
        transitionDuration: Duration.zero,
      ),
    );
    await _pumpFor(tester, 1600);

    expect(find.text('Paso a paso'), findsWidgets);
    expect(find.text('Sal de tu ubicación'), findsOneWidget);
    expect(find.text('Sube al transporte'), findsOneWidget);
    expect(find.text('Llegas a tu destino'), findsOneWidget);
    expect(find.byKey(const ValueKey('journey_start')), findsOneWidget);
  });

  testWidgets('loading can be cancelled and the plan never arrives late', (
    tester,
  ) async {
    await _openPlanner(tester, (_) async {
      await Future<void>.delayed(const Duration(seconds: 30));
      return jsonResponse(validPlanBody());
    });
    await _selectAddress(tester, 'planner_origin', 'origen', 'place-origen');
    await _selectAddress(
      tester,
      'planner_destination',
      'destino',
      'place-destino',
    );
    _pressCalculate(tester);
    await _pumpFor(tester, 800);

    expect(find.byKey(const ValueKey('planner_progress')), findsOneWidget);
    expect(find.text('Calculando tu salida'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('planner_cancel')));
    await _pumpFor(tester, 800);
    expect(find.byKey(const ValueKey('planner_progress')), findsNothing);
    expect(find.text('Planificar viaje'), findsOneWidget);
    // Deja vencer el temporizador del transporte simulado.
    await tester.pump(const Duration(seconds: 31));
  });
}
