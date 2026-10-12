import 'dart:math' as math;
import 'package:flutter/animation.dart';

import 'yg_map_camera.dart';
import 'yg_map_geometry.dart';
import 'yg_map_view.dart';

/// Curvas del prototipo.
const Curve ygCamCurve = Cubic(.2, .85, .25, 1);
const Curve ygPopCurve = Cubic(.34, 1.4, .5, 1);
const Curve ygDrawCurve = Cubic(.6, 0, .2, 1);
const Curve ygCssEase = Cubic(.25, .1, .25, 1);

/// Interpolación animada (equivale a una `transition` CSS).
class YgTween<T> {
  YgTween(T v, this._lerp) : _from = v, _to = v;

  T _from;
  T _to;
  final T Function(T, T, double) _lerp;
  double _e = 0;
  double _d = 0;
  Curve _c = Curves.linear;

  T get value {
    if (_d <= 0 || _e >= _d) return _to;
    return _lerp(_from, _to, _c.transform(_e / _d));
  }

  T get target => _to;
  bool get active => _e < _d;

  /// Anima hacia [target] en [dur] segundos (0 = salto directo).
  void go(T target, double dur, [Curve curve = Curves.linear]) {
    if (target == _to) return;
    if (dur <= 0) {
      snap(target);
      return;
    }
    _from = value;
    _to = target;
    _e = 0;
    _d = dur;
    _c = curve;
  }

  void snap(T target) {
    _from = _to = target;
    _e = 0;
    _d = 0;
  }

  void step(double dt) {
    if (active) _e += dt;
  }
}

double _lerpD(double a, double b, double t) => a + (b - a) * t;
Color _lerpC(Color a, Color b, double t) => Color.lerp(a, b, t)!;
Offset _lerpO(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;

YgTween<double> _td(double v) => YgTween<double>(v, _lerpD);

/// Estado visual de una ruta (`ride`/`glow`/`mwalk`).
class YgRouteVis {
  final ride = YgTween<double>(0, _lerpD);
  final width = YgTween<double>(5.5, _lerpD);
  final color = YgTween<Color>(const Color(0xFF4C583E), _lerpC);
  final glow = _td(0);
  final walkO = _td(0);
  final walkC = YgTween<Color>(const Color(0xFF4C583E), _lerpC);
  YgRouteStyle style = YgRouteStyle.off;
  double drawT0 = 0;
  bool _init = false;

  Iterable<YgTween> get all => [ride, width, color, glow, walkO, walkC];
}

/// Parámetros de ruta por estilo: (color, ancho, opacidad).
({Color c, double w, double o}) ygRouteParams(YgRouteStyle s) {
  switch (s) {
    case YgRouteStyle.off:
      return (c: const Color(0xFF4C583E), w: 5.5, o: 0);
    case YgRouteStyle.sel:
      return (c: const Color(0xFF4C583E), w: 5.5, o: 1);
    case YgRouteStyle.alt:
      return (c: const Color(0xFFABAD98), w: 4.5, o: 1);
    case YgRouteStyle.faint:
      return (c: const Color(0xFFD3D6CA), w: 3.5, o: 1);
    case YgRouteStyle.prev:
      return (c: const Color(0xFF4C583E), w: 4, o: .42);
    case YgRouteStyle.draw:
      return (c: const Color(0xFFA3A792), w: 5.5, o: 1);
  }
}

({Color c, double o}) ygWalkParams(YgRouteStyle s) {
  switch (s) {
    case YgRouteStyle.sel:
      return (c: const Color(0xFF4C583E), o: 1);
    case YgRouteStyle.alt:
      return (c: const Color(0xFFABAD98), o: 1);
    case YgRouteStyle.prev:
      return (c: const Color(0xFF768064), o: .55);
    case YgRouteStyle.draw:
      return (c: const Color(0xFF959581), o: 1);
    case YgRouteStyle.off:
    case YgRouteStyle.faint:
      return (c: const Color(0xFF4C583E), o: 0);
  }
}

/// Modelo de render del mapa: cámara, transiciones y simulación. Es el
/// equivalente de `renderVals()` + las transiciones CSS del prototipo.
class YgMapModel {
  YgMapView view = const YgMapView();
  bool demo = false;
  bool rm = false;
  double zoom = 1;
  Offset pan = Offset.zero;

  /// Reloj de animación continuo (segundos).
  double clock = 0;
  double dt = 0;

  // Cámara
  final tx = _td(0);
  final ty = _td(0);
  final sc = _td(1);
  final tilt = _td(0);
  final oy = _td(0);

  final fog = _td(0);
  final cov = _td(0);
  final doneF = _td(0);
  final doneO = _td(0);
  final routes = List.generate(3, (_) => YgRouteVis());
  final slineO = List.generate(5, (_) => _td(0));
  final stopSel = List.generate(3, (_) => _td(0));
  final stopSmall = List.generate(3, (_) => _td(0));
  final userPos = YgTween<Offset>(Offset.zero, _lerpO);
  final busPos = YgTween<Offset>(Offset.zero, _lerpO);
  final busAng = _td(0);

  bool userShown = false;
  bool busShown = false;
  bool simsShown = false;
  bool stopsShown = false;
  bool hasLoops = false;

  bool _init = false;
  String? _lastKey;
  double _glideUntil = 0;
  final Map<String, double> _ang = {};

  Iterable<YgTween> get _all => [
    tx, ty, sc, tilt, oy, fog, cov, doneF, doneO,
    userPos, busPos, busAng,
    ...slineO, ...stopSel, ...stopSmall,
    for (final r in routes) ...r.all,
  ];

  bool get animating => _all.any((t) => t.active);

  /// Necesita seguir recibiendo frames.
  bool get needsTicks => animating || hasLoops || _drawing;

  bool get _drawing =>
      !rm &&
      view.mode == YgMapMode.loading &&
      demo &&
      clock - routes[0].drawT0 < 2.6;

  void step(double d) {
    dt = d;
    for (final t in _all) {
      t.step(d);
    }
    if (hasLoops || _drawing || animating) clock += d;
  }

  /// Ángulo suavizado (grados) con desenvuelto para evitar saltos de 360°.
  double smoothAngle(String key, double rad, {bool snap = false}) {
    var a = rad * 180 / math.pi;
    final prev = _ang[key];
    if (prev == null || snap || rm) {
      _ang[key] = a;
      return a;
    }
    while (a - prev > 180) {
      a -= 360;
    }
    while (a - prev < -180) {
      a += 360;
    }
    final next = prev + (a - prev) * (1 - math.exp(-dt * 9));
    _ang[key] = next;
    return next;
  }

  double _d(double s) => rm ? 0 : s;

  /// Aplica una nueva vista/estado de cámara. [wall] es el tiempo de frame.
  void apply({
    required YgMapView view,
    required bool demo,
    required bool rm,
    required double zoom,
    required Offset pan,
    required bool dragging,
    required double wall,
  }) {
    final rmChanged = rm != this.rm;
    this.view = view;
    this.demo = demo;
    this.rm = rm;
    this.zoom = zoom;
    this.pan = pan;
    final first = !_init;
    _init = true;
    final mode = view.mode;
    final cam = ygCameraFor(view);
    final tiltT = rm ? 0.0 : cam.tilt;
    final s = cam.s * zoom;
    final txT = cam.sx - s * cam.cx + pan.dx;
    final tyT = cam.sy - s * cam.cy + pan.dy;
    final trip = ygIsTrip(mode);
    final key = '${mode.index}${view.fit ? 'f' : ''}';
    if (key != _lastKey) {
      _lastKey = key;
      _glideUntil = wall + 1.4;
    }
    final gliding = wall < _glideUntil;
    final userMoved = pan != Offset.zero || zoom != 1;
    double camDur;
    Curve camCurve = ygCamCurve;
    if (rm || dragging) {
      camDur = 0;
    } else if (gliding || !trip || view.fit || userMoved) {
      camDur = 1.3;
    } else {
      camDur = 1;
      camCurve = Curves.linear;
    }
    if (first || rmChanged) {
      tx.snap(txT);
      ty.snap(tyT);
      sc.snap(s);
      tilt.snap(tiltT);
      oy.snap(cam.sy);
    } else {
      tx.go(txT, camDur, camCurve);
      ty.go(tyT, camDur, camCurve);
      sc.go(s, camDur, camCurve);
      tilt.go(tiltT, _d(1.4), ygCamCurve);
      oy.go(cam.sy, _d(1.4), ygCamCurve);
    }
    fog.go(tiltT > 0 ? 1 : 0, first ? 0 : _d(1.2), ygCssEase);
    if (first) fog.snap(tiltT > 0 ? 1 : 0);
    cov.go(mode == YgMapMode.nocov ? 1 : 0, _d(.8), ygCssEase);
    if (first) cov.snap(mode == YgMapMode.nocov ? 1 : 0);

    final d = YgMapData.instance;
    final a = ygAltFor(view);
    final tp = ygTripPoints(view);
    final doneShown = demo && (trip || mode == YgMapMode.arrived);

    // Rutas
    for (var i = 0; i < 3; i++) {
      final r = routes[i];
      final st = demo ? ygRouteStyle(view, i) : YgRouteStyle.off;
      if (st == YgRouteStyle.draw && r.style != YgRouteStyle.draw) {
        r.drawT0 = clock;
      }
      r.style = st;
      final p = ygRouteParams(st);
      final w = ygWalkParams(st);
      final snapAll = first || rmChanged || !r._init;
      r._init = true;
      void tw<T>(YgTween<T> t, T v) {
        if (snapAll) {
          t.snap(v);
        } else {
          t.go(v, _d(.6), ygCssEase);
        }
      }

      tw(r.ride, p.o);
      tw(r.width, p.w);
      tw(r.color, p.c);
      tw(r.glow, st == YgRouteStyle.sel ? 1.0 : 0.0);
      tw(r.walkO, w.o);
      tw(r.walkC, w.c);
    }
    final df = demo ? ygDoneFraction(view) : 0.0;
    if (first) {
      doneF.snap(df);
    } else {
      doneF.go(df, _d(1));
    }
    doneO.go(doneShown ? 1 : 0, _d(.5), ygCssEase);
    if (first) doneO.snap(doneShown ? 1 : 0);

    // Simuladores / líneas de seguimiento
    const simModes = {
      YgMapMode.home,
      YgMapMode.nearby,
      YgMapMode.showcase,
      YgMapMode.active,
      YgMapMode.getoff,
    };
    simsShown =
        demo &&
        simModes.contains(mode) &&
        view.ds != YgMapDataState.offline &&
        view.locOn;
    for (var i = 0; i < d.slines.length; i++) {
      final on = simsShown && !(trip && d.slines[i].n == a.n);
      if (first) {
        slineO[i].snap(on ? 1 : 0);
      } else {
        slineO[i].go(on ? 1 : 0, _d(.6), ygCssEase);
      }
    }

    // Paradas
    final wasStops = stopsShown;
    stopsShown = demo && (mode == YgMapMode.nearby || mode == YgMapMode.home);
    for (var j = 0; j < 3; j++) {
      final sel = mode == YgMapMode.nearby && j == view.sel ? 1.0 : 0.0;
      final small = mode == YgMapMode.home ? 1.0 : 0.0;
      if (first || !wasStops || !stopsShown) {
        stopSel[j].snap(sel);
        stopSmall[j].snap(small);
      } else {
        stopSel[j].go(sel, _d(.45), ygPopCurve);
        stopSmall[j].go(small, _d(.45), ygPopCurve);
      }
    }

    // Usuario
    final wasUser = userShown;
    final up = tp.user;
    userShown =
        demo &&
        view.locOn &&
        up != null &&
        mode != YgMapMode.perm &&
        mode != YgMapMode.nocov &&
        mode != YgMapMode.search;
    if (up != null) {
      final o = Offset(up[0], up[1]);
      if (first || !wasUser) {
        userPos.snap(o);
      } else {
        userPos.go(o, _d(1));
      }
    }

    // Bus del viaje
    final wasBus = busShown;
    final bp = tp.bus;
    busShown = demo && trip && bp != null;
    if (bp != null) {
      final o = Offset(bp[0], bp[1]);
      final ang = smoothTripAngle(bp[2]);
      if (first || !wasBus) {
        busPos.snap(o);
        busAng.snap(ang);
      } else {
        busPos.go(o, _d(1));
        busAng.go(ang, _d(1));
      }
    }

    hasLoops =
        !rm &&
        demo &&
        (userShown ||
            simsShown ||
            busShown ||
            mode == YgMapMode.loading ||
            mode == YgMapMode.getoff);
  }

  double _tripAngle = 0;
  bool _tripAngleInit = false;

  /// Desenvuelve el ángulo del bus del viaje respecto al anterior.
  double smoothTripAngle(double rad) {
    var a = rad * 180 / math.pi;
    if (_tripAngleInit) {
      while (a - _tripAngle > 180) {
        a -= 360;
      }
      while (a - _tripAngle < -180) {
        a += 360;
      }
    }
    _tripAngleInit = true;
    _tripAngle = a;
    return a;
  }
}
