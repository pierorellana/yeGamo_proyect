import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/shared/design_system/yg_motion.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/map/yg_map.dart';
import 'package:yegamo_app/shared/map/yg_map_view.dart';

Widget _host(
  YgMapView view,
  YgMapController ctl, {
  required bool demo,
  bool reduced = false,
}) => MaterialApp(
  home: YgMotionScope(
    reduceMotion: reduced,
    child: Scaffold(
      body: SizedBox(
        width: 390,
        height: 844,
        child: YgMap(view: view, controller: ctl, showDemoOverlays: demo),
      ),
    ),
  ),
);

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  test('focusOn publishes a new camera target', () {
    final scope = YgMapScope();
    const point = GeoCoordinate(latitude: -2.17, longitude: -79.9);

    scope.focusOn(point);

    expect(scope.focusTarget?.latitude, point.latitude);
    expect(scope.focusTarget?.longitude, point.longitude);
    expect(scope.focusRequestVersion, 1);
  });

  for (final demo in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets('monta cada modo (demo=$demo, reducido=$reduced)', (
        tester,
      ) async {
        _size(tester);
        final ctl = YgMapController();
        for (final mode in YgMapMode.values) {
          for (final phase in [YgTripPhase.walk, YgTripPhase.ride]) {
            await tester.pumpWidget(
              _host(
                YgMapView(
                  mode: mode,
                  phase: phase,
                  u: .4,
                  sp: 2.5,
                  visibleBottom: 500,
                  tags: const ['14 · 4 min'],
                  subs: const ['180 m'],
                ),
                ctl,
                demo: demo,
                reduced: reduced,
              ),
            );
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final ds in YgMapDataState.values) {
    testWidgets('estado de datos $ds sin excepciones', (tester) async {
      _size(tester);
      final ctl = YgMapController();
      await tester.pumpWidget(
        _host(YgMapView(mode: YgMapMode.home, ds: ds), ctl, demo: true),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(
        _host(
          YgMapView(mode: YgMapMode.active, ds: ds, sp: 1),
          ctl,
          demo: true,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('con movimiento reducido no queda ningún bucle activo', (
    tester,
  ) async {
    _size(tester);
    final ctl = YgMapController();
    await tester.pumpWidget(
      _host(
        const YgMapView(mode: YgMapMode.active, sp: 2),
        ctl,
        demo: true,
        reduced: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _host(
        const YgMapView(mode: YgMapMode.loading),
        ctl,
        demo: true,
        reduced: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('sin demo el mapa termina de planear (sin bucles)', (
    tester,
  ) async {
    _size(tester);
    final ctl = YgMapController();
    await tester.pumpWidget(
      _host(const YgMapView(mode: YgMapMode.home), ctl, demo: false),
    );
    await tester.pumpWidget(
      _host(const YgMapView(mode: YgMapMode.alts), ctl, demo: false),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('tocar la parada seleccionada llama a onPickStop (solo demo)', (
    tester,
  ) async {
    _size(tester);
    final ctl = YgMapController();
    final picked = <int>[];
    final view = YgMapView(
      mode: YgMapMode.nearby,
      visibleBottom: 760,
      onPickStop: picked.add,
    );
    await tester.pumpWidget(_host(view, ctl, demo: false, reduced: true));
    await tester.tapAt(const Offset(195, 436));
    expect(picked, isEmpty);
    await tester.pumpWidget(_host(view, ctl, demo: true, reduced: true));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 436));
    expect(picked, [0]);
  });

  testWidgets('arrastrar con umbral de 6 px desplaza y no dispara taps', (
    tester,
  ) async {
    _size(tester);
    final ctl = YgMapController();
    final picked = <int>[];
    await tester.pumpWidget(
      _host(
        YgMapView(
          mode: YgMapMode.nearby,
          visibleBottom: 760,
          onPickStop: picked.add,
        ),
        ctl,
        demo: true,
        reduced: true,
      ),
    );
    final g = await tester.startGesture(const Offset(195, 436));
    await g.moveBy(const Offset(3, 0));
    expect(ctl.pan, Offset.zero);
    await g.moveBy(const Offset(20, 10));
    expect(ctl.dragging, isTrue);
    expect(ctl.pan.dx, closeTo(23, 1e-6));
    await g.up();
    expect(ctl.dragging, isFalse);
    expect(picked, isEmpty);
    expect(ctl.userMoved, isTrue);
    ctl.reset();
    expect(ctl.pan, Offset.zero);
  });

  testWidgets('el zoom del controlador no lanza y se limita a 0.5–3', (
    tester,
  ) async {
    _size(tester);
    final ctl = YgMapController();
    await tester.pumpWidget(
      _host(
        const YgMapView(mode: YgMapMode.home),
        ctl,
        demo: true,
        reduced: true,
      ),
    );
    for (var i = 0; i < 10; i++) {
      ctl.zoomBy(1.4);
    }
    await tester.pump();
    expect(ctl.zoom, 3.0);
    for (var i = 0; i < 20; i++) {
      ctl.zoomBy(1 / 1.4);
    }
    await tester.pump();
    expect(ctl.zoom, .5);
  });

  test('el controlador reenvía zoom y recentrado al mapa nativo', () async {
    final ctl = YgMapController();
    var nativeZoom = 0.0;
    var resetCount = 0;

    ctl.attachNativeCamera(
      zoomBy: (factor) async => nativeZoom = factor,
      reset: () async => resetCount++,
    );

    ctl.zoomBy(1.4);
    ctl.reset();
    await Future<void>.delayed(Duration.zero);

    expect(nativeZoom, 1.4);
    expect(resetCount, 1);
    ctl.detachNativeCamera();
  });
}
