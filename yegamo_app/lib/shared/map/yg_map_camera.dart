import 'dart:math' as math;

import 'yg_map_geometry.dart';
import 'yg_map_view.dart';

/// Altura (px de prototipo) a partir de la cual empieza el área libre del mapa.
const double ygMapTop = 112;

/// Encuadre de cámara: el punto de mundo ([cx], [cy]) se coloca en la
/// pantalla en ([sx], [sy]) con escala [s] e inclinación [tilt] (grados).
class YgCam {
  const YgCam(this.cx, this.cy, this.sx, this.sy, this.s, this.tilt);

  factory YgCam.fromList(List<double> c) =>
      YgCam(c[0], c[1], c[2], c[3], c[4], c[5]);

  final double cx, cy, sx, sy, s, tilt;
}

/// Posiciones derivadas del viaje activo (`userP`, `busP`, `focus`).
class YgTripPoints {
  const YgTripPoints({this.user, this.bus, required this.focus});

  /// Posición del usuario (null durante el trayecto en bus).
  final YgPt? user;

  /// Posición del bus del viaje (`[x, y, ángulo]`) o null.
  final List<double>? bus;
  final YgPt focus;
}

bool ygIsTrip(YgMapMode m) =>
    m == YgMapMode.active || m == YgMapMode.getoff || m == YgMapMode.showcase;

YgAlt ygAltFor(YgMapView v) {
  final alts = YgMapData.instance.alts;
  return alts[v.alt.clamp(0, alts.length - 1)];
}

YgTripPhase ygPhaseFor(YgMapView v) =>
    v.mode == YgMapMode.showcase ? YgTripPhase.ride : v.phase;

YgTripPoints ygTripPoints(YgMapView v) {
  final d = YgMapData.instance;
  final a = ygAltFor(v);
  YgPt? userP = d.home;
  List<double>? busP;
  YgPt focus = d.home;
  if (ygIsTrip(v.mode)) {
    switch (ygPhaseFor(v)) {
      case YgTripPhase.walk:
        userP = ygATF(a.w1, v.u);
        focus = userP;
      case YgTripPhase.wait:
        userP = a.ride[0];
        busP = ygATF(a.ap, v.w);
        focus = a.ride[0];
      case YgTripPhase.ride:
        busP = ygSEG(a.ride, v.sp);
        focus = busP;
        userP = null;
      case YgTripPhase.walk2:
        userP = ygATF(a.w2, v.u);
        focus = userP;
      case YgTripPhase.done:
        userP = d.work;
        focus = d.work;
    }
  }
  if (v.mode == YgMapMode.arrived) userP = d.work;
  return YgTripPoints(user: userP, bus: busP, focus: focus);
}

/// Tabla de cámara por modo (`renderVals` del prototipo). [vb] es el límite
/// inferior del área libre.
YgCam ygCameraFor(YgMapView v) {
  final d = YgMapData.instance;
  final mode = v.mode;
  final a = ygAltFor(v);
  final vb = v.visibleBottom > 0 ? v.visibleBottom : 700.0;
  const top = ygMapTop;
  final vcy = (top + vb) / 2;
  final trip = ygIsTrip(mode);
  final phase = ygPhaseFor(v);
  final tp = ygTripPoints(v);
  final last = a.ride.last;
  final allPts = [...d.alts[0].all, ...d.alts[1].all, ...d.alts[2].all];
  if (v.fit &&
      (mode == YgMapMode.home ||
          mode == YgMapMode.nearby ||
          trip ||
          mode == YgMapMode.arrived)) {
    return YgCam.fromList(
      ygFIT(
        mode == YgMapMode.nearby
            ? [...d.stops.map((x) => x.p), d.home]
            : a.all,
        top,
        vb,
      ),
    );
  }
  switch (mode) {
    case YgMapMode.home:
      return YgCam(290, 410, 195, vcy, 1.3, 0);
    case YgMapMode.perm:
      return const YgCam(470, 600, 195, 320, 0.5, 0);
    case YgMapMode.search:
      return const YgCam(470, 560, 195, 330, 0.55, 0);
    case YgMapMode.nearby:
      final so = d.stops[v.sel.clamp(0, d.stops.length - 1)];
      return YgCam(so.p[0], so.p[1], 195, vcy, 2.0, 0);
    case YgMapMode.loading:
      return YgCam.fromList(ygFIT(allPts, top, vb));
    case YgMapMode.planner:
    case YgMapMode.alts:
    case YgMapMode.depart:
    case YgMapMode.steps:
      return YgCam.fromList(ygFIT(a.all, top, vb));
    case YgMapMode.getoff:
      return YgCam(last[0], last[1], 195, math.min(560, vcy + 120), 2.6, 46);
    case YgMapMode.active:
    case YgMapMode.showcase:
      return YgCam(
        tp.focus[0],
        tp.focus[1],
        195,
        math.min(600, vcy + (phase == YgTripPhase.ride ? 110 : 90)),
        2.2,
        52,
      );
    case YgMapMode.arrived:
      return YgCam(754, 698, 195, vcy, 1.7, 0);
    case YgMapMode.nocov:
      return const YgCam(-110, 900, 195, 330, 0.2, 0);
  }
}

/// Estilo de una ruta (`ride`/`glow`/`mwalk`): off, sel, alt, faint, prev, draw.
enum YgRouteStyle { off, sel, alt, faint, prev, draw }

YgRouteStyle ygRouteStyle(YgMapView v, int i) {
  final mode = v.mode;
  var st = YgRouteStyle.off;
  if (mode == YgMapMode.home) {
    st = i == 0 ? YgRouteStyle.prev : YgRouteStyle.off;
  } else if (mode == YgMapMode.nearby) {
    st = YgRouteStyle.faint;
  } else if (mode == YgMapMode.loading) {
    st = YgRouteStyle.draw;
  } else if (mode == YgMapMode.alts ||
      mode == YgMapMode.depart ||
      mode == YgMapMode.steps) {
    st = i == v.alt ? YgRouteStyle.sel : YgRouteStyle.alt;
  } else if (ygIsTrip(mode) || mode == YgMapMode.arrived) {
    st = i == v.alt ? YgRouteStyle.sel : YgRouteStyle.off;
  }
  if (mode == YgMapMode.showcase) {
    st = i == 0 ? YgRouteStyle.sel : YgRouteStyle.faint;
  }
  return st;
}

/// Fracción recorrida del tramo en bus (`doneF`).
double ygDoneFraction(YgMapView v) {
  if (!(ygIsTrip(v.mode) || v.mode == YgMapMode.arrived)) return 0;
  final a = ygAltFor(v);
  final phase = ygPhaseFor(v);
  if (phase == YgTripPhase.ride && ygIsTrip(v.mode)) {
    return ygSEGD(a.ride, v.sp) / ygPL(a.ride);
  }
  if (phase == YgTripPhase.walk2 ||
      phase == YgTripPhase.done ||
      v.mode == YgMapMode.arrived) {
    return 1;
  }
  return 0;
}
