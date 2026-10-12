import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/shared/map/yg_map_camera.dart';
import 'package:yegamo_app/shared/map/yg_map_geometry.dart';
import 'package:yegamo_app/shared/map/yg_map_view.dart';

void main() {
  final line = <YgPt>[
    [0, 0],
    [30, 40],
    [30, 140],
  ];

  group('geometría del mapa', () {
    test('L y PL', () {
      expect(ygL([0, 0], [3, 4]), 5);
      expect(ygPL(line), 150);
      expect(ygPL([[1, 1]]), 0);
    });

    test('AT devuelve punto y ángulo y se satura en los extremos', () {
      final a = ygAT(line, 25);
      expect(a[0], closeTo(15, 1e-9));
      expect(a[1], closeTo(20, 1e-9));
      expect(a[2], closeTo(math.atan2(40, 30), 1e-9));
      final b = ygAT(line, 100);
      expect(b[0], 30);
      expect(b[1], closeTo(90, 1e-9));
      final end = ygAT(line, 999);
      expect([end[0], end[1]], [30, 140]);
      expect(end[2], closeTo(math.pi / 2, 1e-9));
    });

    test('ATF usa fracción acotada 0–1', () {
      expect(ygATF(line, -1)[1], 0);
      expect(ygATF(line, 0.5)[1], closeTo(65, 1e-9));
      expect(ygATF(line, 2)[1], 140);
    });

    test('SEG y SEGD', () {
      final p = ygSEG(line, 1.5);
      expect(p[0], 30);
      expect(p[1], closeTo(90, 1e-9));
      expect(ygSEG(line, 99)[1], 140);
      expect(ygSEGD(line, 1.5), closeTo(100, 1e-9));
      expect(ygSEGD(line, 0), 0);
      expect(ygSEGD(line, 2), 150);
    });

    test('RP redondea esquinas con Q', () {
      final d = ygRP(line, 10);
      expect(d.startsWith('M0 0 L'), isTrue);
      expect(d, contains('Q30 40'));
      expect(d.endsWith('L30 140'), isTrue);
      expect(ygRP(const [
        [0, 0],
        [10, 0],
      ], 5), 'M0 0 L10 0');
    });

    test('FIT encuadra el centro del caja y limita la escala', () {
      final c = ygFIT([
        [100, 100],
        [300, 500],
      ], 112, 700);
      expect(c[0], 200);
      expect(c[1], 300);
      expect(c[2], 168);
      expect(c[3], (112 + 700) / 2 + 6);
      expect(c[4], closeTo(math.min(232 / 200, (700 - 112 - 80) / 400), 1e-9));
      expect(c[5], 0);
      expect(
        ygFIT([
          [0, 0],
          [1, 1],
        ], 0, 800)[4],
        2.4,
      );
      expect(
        ygFIT([
          [0, 0],
          [9000, 9000],
        ], 0, 800)[4],
        0.25,
      );
    });

    test('datos demo coherentes', () {
      final d = YgMapData.instance;
      expect(d.alts, hasLength(3));
      expect(d.sims, hasLength(6));
      expect(d.slines, hasLength(5));
      expect(d.alts[0].rd, startsWith('M252 432'));
      for (final a in d.alts) {
        expect(a.all.length, a.w1.length + a.ride.length + a.w2.length);
      }
    });
  });

  group('tabla de cámara', () {
    test('home usa vcy y escala 1.3 sin inclinación', () {
      final c = ygCameraFor(const YgMapView(mode: YgMapMode.home, visibleBottom: 376));
      expect([c.cx, c.cy, c.sx, c.s, c.tilt], [290, 410, 195, 1.3, 0]);
      expect(c.sy, (112 + 376) / 2);
    });

    test('modos fijos', () {
      YgCam of(YgMapMode m) => ygCameraFor(YgMapView(mode: m));
      expect(of(YgMapMode.perm).s, .5);
      expect(of(YgMapMode.search).sy, 330);
      expect(of(YgMapMode.nocov).s, .2);
      expect(of(YgMapMode.nocov).cx, -110);
      expect(of(YgMapMode.arrived).s, 1.7);
    });

    test('active/getoff se inclinan 52° y 46°', () {
      final a = ygCameraFor(const YgMapView(mode: YgMapMode.active, visibleBottom: 672));
      expect(a.tilt, 52);
      expect(a.s, 2.2);
      final g = ygCameraFor(const YgMapView(mode: YgMapMode.getoff, visibleBottom: 708));
      expect(g.tilt, 46);
      expect(g.s, 2.6);
      expect(g.sy, lessThanOrEqualTo(560));
    });

    test('nearby centra en la parada seleccionada', () {
      final c = ygCameraFor(const YgMapView(mode: YgMapMode.nearby, sel: 2));
      expect([c.cx, c.cy], [168, 470]);
      expect(c.s, 2.0);
    });

    test('fit usa FIT de la ruta y planner/alts también', () {
      final fit = ygCameraFor(const YgMapView(mode: YgMapMode.home, fit: true));
      final alts = ygCameraFor(const YgMapView(mode: YgMapMode.alts));
      expect(fit.s, closeTo(alts.s, 1e-9));
      final load = ygCameraFor(const YgMapView(mode: YgMapMode.loading));
      expect(load.s, lessThan(alts.s));
    });

    test('estilos de ruta por modo', () {
      expect(ygRouteStyle(const YgMapView(mode: YgMapMode.home), 0), YgRouteStyle.prev);
      expect(ygRouteStyle(const YgMapView(mode: YgMapMode.home), 1), YgRouteStyle.off);
      expect(ygRouteStyle(const YgMapView(mode: YgMapMode.nearby), 2), YgRouteStyle.faint);
      expect(ygRouteStyle(const YgMapView(mode: YgMapMode.loading), 1), YgRouteStyle.draw);
      expect(ygRouteStyle(const YgMapView(mode: YgMapMode.alts, alt: 1), 1), YgRouteStyle.sel);
      expect(ygRouteStyle(const YgMapView(mode: YgMapMode.alts, alt: 1), 0), YgRouteStyle.alt);
      expect(ygRouteStyle(const YgMapView(mode: YgMapMode.active), 2), YgRouteStyle.off);
    });

    test('fracción recorrida', () {
      expect(ygDoneFraction(const YgMapView(mode: YgMapMode.alts)), 0);
      expect(ygDoneFraction(const YgMapView(mode: YgMapMode.arrived)), 1);
      final half = ygDoneFraction(
        const YgMapView(mode: YgMapMode.active, phase: YgTripPhase.ride, sp: 3),
      );
      expect(half, inExclusiveRange(0, 1));
      expect(
        ygDoneFraction(const YgMapView(mode: YgMapMode.active, phase: YgTripPhase.walk2)),
        1,
      );
    });

    test('puntos del viaje por fase', () {
      final ride = ygTripPoints(
        const YgMapView(mode: YgMapMode.active, phase: YgTripPhase.ride, sp: 1),
      );
      expect(ride.user, isNull);
      expect(ride.bus, isNotNull);
      final walk = ygTripPoints(
        const YgMapView(mode: YgMapMode.active, phase: YgTripPhase.walk, u: 0),
      );
      expect(walk.user!.sublist(0, 2), [196, 372]);
      expect(walk.bus, isNull);
    });
  });
}
