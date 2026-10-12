import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'yg_map_base.dart';
import 'yg_map_camera.dart';
import 'yg_map_geometry.dart';
import 'yg_map_model.dart';
import 'yg_map_svg.dart';
import 'yg_map_view.dart';

const _moss = Color(0xFF4C583E);
const _cedar = Color(0xFF2C3424);
const _ink = Color(0xFF1E2419);
const _grey = Color(0xFF959581);
const _ice = Color(0xFFDADED8);
const _white = Color(0xFFFFFFFF);
const _text2 = Color(0xFF5B624F);
const _clay = Color(0xFF9C4F3A);

/// Perspectiva del prototipo (`perspective(1100px)`).
const double _persp = 1100;

class _Poly {
  _Poly(this.path)
    : metrics = path.computeMetrics().toList(),
      len = path.computeMetrics().fold(0.0, (a, m) => a + m.length);
  final Path path;
  final List<ui.PathMetric> metrics;
  final double len;

  Path slice(double a, double b) => ygPathSlice(metrics, len, a, b);
}

class _RouteGeo {
  _RouteGeo(YgAlt a)
    : ride = _Poly(ygParseSvgPath(a.rd)),
      w1 = _Poly(ygParseSvgPath(a.w1d)),
      w2 = _Poly(ygParseSvgPath(a.w2d)),
      w1dots = const [],
      w2dots = const [] {
    w1dots = _dots(w1, 8.6);
    w2dots = _dots(w2, 8.6);
  }
  final _Poly ride, w1, w2;
  List<Offset> w1dots, w2dots;
}

List<Offset> _dots(_Poly p, double spacing) {
  final out = <Offset>[];
  for (final m in p.metrics) {
    for (var d = 0.0; d <= m.length; d += spacing) {
      final t = m.getTangentForOffset(d);
      if (t != null) out.add(t.position);
    }
  }
  return out;
}

List<_RouteGeo>? _routeGeo;
List<_Poly>? _slineGeo;

List<_RouteGeo> get _routes =>
    _routeGeo ??= YgMapData.instance.alts.map(_RouteGeo.new).toList();
List<_Poly> get _slines =>
    _slineGeo ??= YgMapData.instance.slines
        .map((s) => _Poly(ygParseSvgPath(s.d)))
        .toList();

Path? _covPath;
Path get _cov => _covPath ??= ygParseSvgPath(
  'M-140 -200 C300 -300 900 -260 1120 120 C1250 500 1200 1100 1000 1450 C700 1650 100 1600 -160 1350 C-320 900 -320 200 -140 -200 Z',
);

/// Matrices de la cámara para un tamaño dado.
class YgMapMatrices {
  YgMapMatrices(this.k, this.full, this.tiltRad, this.s);

  /// Factor de escala diseño(390 px) → pantalla.
  final double k;

  /// Mundo → espacio de diseño (incluye perspectiva).
  final Matrix4 full;
  final double tiltRad;
  final double s;

  /// Matriz de un marcador de pie (`bb`): contra-rotado y a escala constante.
  Matrix4 billboard(Offset p) =>
      full *
      Matrix4.translationValues(p.dx, p.dy, 0) *
      Matrix4.rotationX(-tiltRad) *
      Matrix4.diagonal3Values(1 / s, 1 / s, 1);

  /// Matriz de un marcador plano sobre el suelo (vehículos).
  Matrix4 flat(Offset p, double angleDeg) =>
      full *
      Matrix4.translationValues(p.dx, p.dy, 0) *
      Matrix4.diagonal3Values(1 / s, 1 / s, 1) *
      Matrix4.rotationZ(angleDeg * math.pi / 180);
}

YgMapMatrices ygMapMatrices(YgMapModel m, Size size) {
  final k = size.width / 390;
  final tiltRad = m.tilt.value * math.pi / 180;
  final oy = m.oy.value;
  var mtl = Matrix4.identity();
  if (tiltRad.abs() > 1e-6) {
    final p = Matrix4.identity()..setEntry(3, 2, -1 / _persp);
    mtl =
        Matrix4.translationValues(195, oy, 0) *
        p *
        Matrix4.rotationX(tiltRad) *
        Matrix4.translationValues(-195, -oy, 0);
  }
  final s = m.sc.value;
  final full =
      mtl *
      Matrix4.translationValues(m.tx.value, m.ty.value, 0) *
      Matrix4.diagonal3Values(s, s, 1);
  return YgMapMatrices(k, full, tiltRad, s);
}

/// Pinta el mapa completo: base + capas dinámicas + niebla/viñeta.
class YgMapPainter extends CustomPainter {
  YgMapPainter(this.m, this.family, Listenable repaint)
    : super(repaint: repaint);

  final YgMapModel m;
  final String? family;
  final Map<String, TextPainter> _tp = {};

  // ---- texto ----
  TextPainter _text(
    String s,
    double size,
    FontWeight w,
    Color color, {
    double ls = 0,
  }) {
    final key = '$s|$size|${w.value}|${color.toARGB32()}|$ls';
    return _tp[key] ??= TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: family,
          fontSize: size,
          fontWeight: w,
          color: color,
          letterSpacing: ls,
          height: 1.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Nombre de la parada demo, subtítulo y ETA.
  List<String> _stopTexts(int j) => [
    YgMapData.instance.stops[j].n,
    j < m.view.subs.length ? m.view.subs[j] : '',
    j < m.view.tags.length ? m.view.tags[j] : '',
  ];

  @override
  void paint(Canvas c, Size size) {
    final mm = ygMapMatrices(m, size);
    c.save();
    c.scale(mm.k);
    final h = size.height / mm.k;
    c.clipRect(Rect.fromLTWH(0, 0, 390, h));
    c.drawRect(Rect.fromLTWH(0, 0, 390, h), Paint()..color = const Color(0xFFF3F4EF));

    // Mundo
    c.save();
    c.transform(mm.full.storage);
    c.drawPicture(ygBaseMapPicture(family));
    _coverage(c);
    if (m.demo) _routesLayer(c);
    c.restore();

    if (m.demo) _markers(c, mm);

    // Niebla superior y viñeta
    final fo = m.fog.value.clamp(0.0, 1.0);
    if (fo > 0) {
      const f = Color(0xFFF4F5F1);
      c.drawRect(
        const Rect.fromLTWH(0, 0, 390, 340),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(0, 340),
            [
              f.withValues(alpha: fo),
              f.withValues(alpha: .92 * fo),
              f.withValues(alpha: 0),
            ],
            const [0, .28, 1],
          ),
      );
    }
    c.save();
    c.translate(195, h * .4);
    c.scale(1.2 * 390, .8 * h);
    c.drawRect(
      const Rect.fromLTWH(-3, -3, 6, 6),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          [_cedar.withValues(alpha: 0), _cedar.withValues(alpha: .07)],
          const [.6, 1],
        ),
    );
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(covariant YgMapPainter old) => old.family != family;

  // ---------------------------------------------------------------- mundo

  void _coverage(Canvas c) {
    final o = m.cov.value.clamp(0.0, 1.0);
    if (o <= 0) return;
    c.drawPath(_cov, Paint()..color = _moss.withValues(alpha: .05 * o));
    final dash = Path();
    for (final mt in _cov.computeMetrics()) {
      for (var d = 0.0; d < mt.length; d += 52) {
        dash.addPath(mt.extractPath(d, math.min(mt.length, d + 30)), Offset.zero);
      }
    }
    c.drawPath(
      dash,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.butt
        ..color = _moss.withValues(alpha: o),
    );
    final tp = _text('Zona yeGamo · Guayaquil', 46, FontWeight.w600, _moss.withValues(alpha: o), ls: 1.84);
    tp.paint(c, Offset(-120, -250 - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
  }

  Paint _line(Color col, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = col;

  void _routesLayer(Canvas c) {
    final d = YgMapData.instance;
    final ds = m.view.ds;
    final t = m.clock;
    final a = ygAltFor(m.view);

    // Líneas de seguimiento
    for (var i = 0; i < d.slines.length; i++) {
      final o = m.slineO[i].value.clamp(0.0, 1.0);
      if (o <= 0.003) continue;
      var live = d.slines[i].live;
      if (ds == YgMapDataState.stale ||
          (ds == YgMapDataState.degraded && d.slines[i].deg)) {
        live = false;
      }
      final poly = _slines[i];
      if (live) {
        final x = m.rm ? 0.0 : ((t / 1.1) % 1) * 20.1;
        final pts = <Offset>[];
        for (final mt in poly.metrics) {
          for (var dd = (x % 10.1); dd <= mt.length; dd += 10.1) {
            final tg = mt.getTangentForOffset(dd);
            if (tg != null) pts.add(tg.position);
          }
        }
        c.drawPoints(
          ui.PointMode.points,
          pts,
          _line(_moss.withValues(alpha: .55 * o), 3.2),
        );
      } else {
        final x = m.rm ? 0.0 : ((t / 2.4) % 1) * 20.1;
        final path = Path();
        for (final mt in poly.metrics) {
          for (var dd = (x % 12) - 12; dd < mt.length; dd += 12) {
            final s0 = math.max(0.0, dd), e0 = math.min(mt.length, dd + 5);
            if (e0 > s0) path.addPath(mt.extractPath(s0, e0), Offset.zero);
          }
        }
        c.drawPath(path, _line(_grey.withValues(alpha: .7 * o), 2.6));
      }
    }

    // Brillos y rutas
    for (var i = 0; i < 3; i++) {
      final g = m.routes[i].glow.value.clamp(0.0, 1.0);
      if (g > 0.003) {
        c.drawPath(_routes[i].ride.path, _line(_white.withValues(alpha: g), 11));
      }
    }
    for (var i = 0; i < 3; i++) {
      final r = m.routes[i];
      final o = r.ride.value.clamp(0.0, 1.0);
      if (o <= 0.003) continue;
      final paint = _line(r.color.value.withValues(alpha: o), r.width.value);
      if (r.style == YgRouteStyle.draw && !m.rm) {
        final tl = t - r.drawT0 - (.15 + .45 * i);
        final p = ygDrawCurve.transform((tl / 1.5).clamp(0.0, 1.0));
        if (p > 0) c.drawPath(_routes[i].ride.slice(0, p), paint);
      } else {
        c.drawPath(_routes[i].ride.path, paint);
      }
    }
    // Cometas (modo loading)
    if (m.view.mode == YgMapMode.loading && !m.rm) {
      const delays = [0.0, .6, 1.1];
      for (var i = 0; i < 3; i++) {
        final q = ((t + delays[i]) / 1.7) % 1;
        final p = _routes[i].ride;
        c.drawPath(p.slice(q, math.min(1.0, q + .06)), _line(_cedar, 5));
      }
    }
    // Tramo recorrido
    final dO = m.doneO.value.clamp(0.0, 1.0);
    if (dO > 0.003) {
      final f = m.doneF.value.clamp(0.0, 1.0);
      if (f > 0) {
        c.drawPath(
          _routes[a.n == d.alts[0].n ? 0 : d.alts.indexWhere((x) => x.n == a.n)]
              .ride
              .slice(0, f),
          _line(const Color(0xFFC3C7B9).withValues(alpha: dO), 6.5),
        );
      }
    }
    // Caminatas punteadas
    for (var i = 0; i < 3; i++) {
      final r = m.routes[i];
      var o = r.walkO.value.clamp(0.0, 1.0);
      if (r.style == YgRouteStyle.draw) {
        if (m.rm) {
          o = 1;
        } else {
          final tl = t - r.drawT0 - (.15 + .45 * i);
          o = ygCssEase.transform((tl / .6).clamp(0.0, 1.0));
        }
      }
      if (o <= 0.003) continue;
      final paint = _line(r.walkC.value.withValues(alpha: o), 4);
      c.drawPoints(ui.PointMode.points, _routes[i].w1dots, paint);
      c.drawPoints(ui.PointMode.points, _routes[i].w2dots, paint);
    }
  }

  // ------------------------------------------------------------ marcadores

  void _markers(Canvas c, YgMapMatrices mm) {
    final d = YgMapData.instance;
    final v = m.view;
    final mode = v.mode;
    final a = ygAltFor(v);
    final trip = ygIsTrip(mode);
    final phase = ygPhaseFor(v);

    // Nodos
    const nodeModes = {
      YgMapMode.alts,
      YgMapMode.depart,
      YgMapMode.steps,
      YgMapMode.active,
      YgMapMode.getoff,
      YgMapMode.arrived,
      YgMapMode.showcase,
    };
    if (nodeModes.contains(mode)) {
      final full = trip || mode == YgMapMode.steps || mode == YgMapMode.arrived;
      for (var j = 0; j < a.ride.length; j++) {
        final isFirst = j == 0, isLast = j == a.ride.length - 1;
        if (!full && !isFirst && !isLast && j != a.xf) continue;
        var kind = _Node.mid;
        if (isFirst) kind = _Node.plain;
        if (j == a.xf) kind = _Node.xf;
        var pulse = false;
        if (isLast) {
          kind = _Node.al;
          pulse = mode == YgMapMode.getoff;
        }
        if (!isFirst &&
            !isLast &&
            j != a.xf &&
            trip &&
            phase == YgTripPhase.ride &&
            j <= v.sp) {
          kind = _Node.pass;
        }
        c.save();
        c.transform(mm.billboard(Offset(a.ride[j][0], a.ride[j][1])).storage);
        _node(c, kind, pulse);
        c.restore();
      }
    }

    // Paradas
    if (m.stopsShown) {
      for (var j = 0; j < d.stops.length; j++) {
        c.save();
        c.transform(mm.billboard(Offset(d.stops[j].p[0], d.stops[j].p[1])).storage);
        _stop(c, j);
        c.restore();
      }
    }

    // Destino
    const destModes = {
      YgMapMode.home,
      YgMapMode.planner,
      YgMapMode.loading,
      YgMapMode.alts,
      YgMapMode.depart,
      YgMapMode.steps,
      YgMapMode.active,
      YgMapMode.getoff,
      YgMapMode.arrived,
      YgMapMode.showcase,
    };
    if (mode == YgMapMode.nocov) {
      c.save();
      c.transform(mm.billboard(Offset(d.playas[0], d.playas[1])).storage);
      _pin(c, 'Playas · 96 km', _PinKind.far);
      c.restore();
    } else if (destModes.contains(mode)) {
      c.save();
      c.transform(mm.billboard(Offset(d.work[0], d.work[1])).storage);
      _pin(c, 'Trabajo', mode == YgMapMode.home ? _PinKind.soft : _PinKind.solid);
      c.restore();
    }

    // Buses simulados
    final ds = v.ds;
    if (m.simsShown) {
      for (var bi = 0; bi < d.sims.length; bi++) {
        final b = d.sims[bi];
        if (trip && b.n == a.n) continue;
        final dd = (b.off + m.clock * b.v) % b.len;
        final p = ygAT(b.line, dd);
        var live = b.live;
        if (ds == YgMapDataState.stale) live = false;
        if (ds == YgMapDataState.degraded && b.deg) live = false;
        final ang = m.smoothAngle('s$bi', p[2], snap: dd < b.v * 1.2);
        final pos = Offset(p[0], p[1]);
        _bus(
          c,
          mm,
          pos,
          ang,
          label: '${live ? '' : '≈'}${b.n}',
          live: live,
          trip: false,
          stale: ds == YgMapDataState.stale,
        );
      }
    }
    if (m.busShown) {
      final tl = (a.live && ds != YgMapDataState.degraded) ? true : v.alt == 0;
      _bus(
        c,
        mm,
        m.busPos.value,
        m.busAng.value,
        label:
            '${tl ? '' : '≈'}${a.n}${phase == YgTripPhase.ride ? ' · tú' : ''}',
        live: tl,
        trip: true,
        stale: false,
      );
    }

    // Usuario
    if (m.userShown) {
      c.save();
      c.transform(mm.billboard(m.userPos.value).storage);
      _me(c);
      c.restore();
    }
  }

  Paint _blurPaint(Color col, double blur) => Paint()
    ..color = col
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2);

  // Nodos
  void _node(Canvas c, _Node kind, bool pulse) {
    final t = m.clock;
    switch (kind) {
      case _Node.plain:
        c.drawCircle(const Offset(0, 3), 7, _blurPaint(_cedar.withValues(alpha: .25), 8));
        c.drawCircle(Offset.zero, 10.5, Paint()..color = _cedar);
        c.drawCircle(Offset.zero, 7, Paint()..color = _white);
      case _Node.mid:
        c.drawCircle(Offset.zero, 7, Paint()..color = _moss);
        c.drawCircle(Offset.zero, 4.5, Paint()..color = _white);
      case _Node.pass:
        c.drawCircle(Offset.zero, 7, Paint()..color = const Color(0xFFB9BDAE));
        c.drawCircle(Offset.zero, 4.5, Paint()..color = _white);
      case _Node.xf:
        c.drawCircle(Offset.zero, 14.5, Paint()..color = _white);
        c.drawCircle(Offset.zero, 11.5, Paint()..color = _cedar);
        c.drawCircle(Offset.zero, 8, Paint()..color = _white);
      case _Node.al:
        c.drawCircle(const Offset(0, 3), 10.5, _blurPaint(_cedar.withValues(alpha: .35), 10));
        c.drawCircle(Offset.zero, 10.5, Paint()..color = _white);
        c.drawCircle(Offset.zero, 7, Paint()..color = _cedar);
    }
    if (pulse && !m.rm) {
      final p = Curves.easeOut.transform((t / 1.5) % 1);
      final sc = .3 + .95 * p;
      c.drawCircle(
        Offset.zero,
        27 * sc,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * sc
          ..color = _cedar.withValues(alpha: 1 - p),
      );
    }
  }

  // Parada
  Path _busIcon() {
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(5, 3.5, 14, 14), const Radius.circular(3)))
      ..moveTo(5, 11)
      ..lineTo(19, 11)
      ..moveTo(8, 17.5)
      ..lineTo(8, 20)
      ..moveTo(16, 17.5)
      ..lineTo(16, 20);
    return p;
  }

  void _stop(Canvas c, int j) {
    final sel = m.stopSel[j].value;
    final small = m.stopSmall[j].value;
    final texts = _stopTexts(j);
    final name = _text(texts[0], 13, FontWeight.w600, _ink);
    final sub = texts[1].isEmpty ? null : _text(texts[1], 11.5, FontWeight.w400, _text2);
    final contentW = math.max(name.width, sub?.width ?? 0.0);
    final selC = sel.clamp(0.0, 1.0);
    final double tagW = math.min(contentW, 230 * math.max(0.0, sel)).toDouble();
    final h = 32 + 14 * sel;
    final icon = 23 + 11 * sel;
    final padL = 3 + 2 * sel;
    final padR = 3 + 11 * sel;
    final gap = 9 * sel;
    final w = 3 + padL + icon + gap + tagW + padR;
    final scale = 1 - .18 * small;
    c.scale(scale);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(11 + 4 * sel));
    c.drawRRect(rr.shift(const Offset(0, 6)), _blurPaint(_cedar.withValues(alpha: .16), 16));
    c.drawRRect(rr, Paint()..color = _white);
    c.drawRRect(
      rr.deflate(.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(const Color(0xFFCDD2C4), _cedar, selC)!,
    );
    final ix = rect.left + 1.5 + padL;
    final irect = Rect.fromLTWH(ix, -icon / 2, icon, icon);
    if (selC > 0) {
      c.drawRRect(
        RRect.fromRectAndRadius(irect, Radius.circular(8 + 3 * sel)),
        Paint()..color = _cedar.withValues(alpha: selC),
      );
    }
    c.save();
    c.translate(irect.center.dx - 7.5, irect.center.dy - 7.5);
    c.scale(15 / 24);
    c.drawPath(
      _busIcon(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(_moss, _white, selC)!,
    );
    c.restore();
    if (selC > 0 && tagW > 0.5) {
      c.save();
      final tx = ix + icon + gap;
      c.clipRect(Rect.fromLTWH(tx, -h / 2, tagW, h));
      final th = name.height + (sub?.height ?? 0.0);
      c.saveLayer(
        Rect.fromLTWH(tx, -h / 2, tagW + 2, h),
        Paint()..color = const Color(0xFF000000).withValues(alpha: selC),
      );
      name.paint(c, Offset(tx, -th / 2));
      sub?.paint(c, Offset(tx, -th / 2 + name.height));
      c.restore();
      c.restore();
    }
    final eta = texts[2];
    if (eta.isNotEmpty && selC < 1) {
      final tp = _text(eta, 10.5, FontWeight.w700, _white);
      final cw = tp.width + 12;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(w / 2 - 6, -h / 2 - 10, cw, 18),
        const Radius.circular(9),
      );
      c.saveLayer(
        r.outerRect.inflate(2),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 1 - selC),
      );
      c.drawRRect(r, Paint()..color = _cedar);
      tp.paint(c, Offset(r.left + 6, r.top + (18 - tp.height) / 2));
      c.restore();
    }
  }

  // Pin de destino
  void _pin(Canvas c, String label, _PinKind kind) {
    final tp = _text(label, 13, FontWeight.w600, kind == _PinKind.solid ? _white : (kind == _PinKind.far ? _ink : _cedar));
    final w = tp.width + 4 + 26 + 7 + 13;
    final accent = kind == _PinKind.far ? _clay : _cedar;
    final head = RRect.fromRectAndRadius(
      Rect.fromLTWH(-w / 2, -52, w, 34),
      const Radius.circular(17),
    );
    c.drawOval(Rect.fromCenter(center: const Offset(0, -2), width: 8, height: 4), Paint()..color = _cedar.withValues(alpha: .35));
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-1.25, -18, 2.5, 14), const Radius.circular(2)),
      Paint()..color = accent,
    );
    c.drawRRect(
      head.shift(const Offset(0, 10)),
      _blurPaint(_cedar.withValues(alpha: kind == _PinKind.solid ? .3 : .18), 22),
    );
    if (kind != _PinKind.solid) {
      c.drawRRect(head.inflate(1.5), Paint()..color = accent);
    }
    c.drawRRect(head, Paint()..color = kind == _PinKind.solid ? _cedar : _white);
    final icx = -w / 2 + 4 + 13;
    c.drawCircle(Offset(icx, -35), 13, Paint()..color = kind == _PinKind.solid ? _ice : accent);
    c.save();
    c.translate(icx - 7.5, -35 - 7.5);
    c.scale(15 / 24);
    final glyph = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = kind == _PinKind.solid ? _cedar : _white;
    if (kind == _PinKind.far) {
      final p = Path()
        ..moveTo(12, 21)
        ..cubicTo(12, 21, 5.5, 14.8, 5.5, 10)
        ..arcToPoint(const Offset(18.5, 10), radius: const Radius.circular(6.5))
        ..cubicTo(18.5, 14.8, 12, 21, 12, 21)
        ..close();
      c.drawPath(p, glyph);
      c.drawCircle(const Offset(12, 10), 2.3, glyph);
    } else {
      final p = Path()
        ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3.5, 7.5, 17, 12), const Radius.circular(2.5)))
        ..moveTo(9, 7.5)
        ..lineTo(9, 6)
        ..arcToPoint(const Offset(10.5, 4.5), radius: const Radius.circular(1.5))
        ..lineTo(13.5, 4.5)
        ..arcToPoint(const Offset(15, 6), radius: const Radius.circular(1.5))
        ..lineTo(15, 7.5)
        ..moveTo(3.5, 13)
        ..lineTo(20.5, 13);
      c.drawPath(p, glyph);
    }
    c.restore();
    tp.paint(c, Offset(-w / 2 + 4 + 26 + 7, -35 - tp.height / 2));
  }

  // Usuario
  void _me(Canvas c) {
    if (!m.rm) {
      final p = Curves.easeOut.transform((m.clock / 2.4) % 1);
      final sc = .4 + 1.3 * p;
      c.drawCircle(
        Offset.zero,
        26 * sc,
        Paint()..color = const Color(0xFF768064).withValues(alpha: .28 * (.9 * (1 - p))),
      );
    }
    c.drawCircle(const Offset(0, 4), 10, _blurPaint(_cedar.withValues(alpha: .28), 12));
    c.drawCircle(Offset.zero, 11, Paint()..color = _cedar.withValues(alpha: .12));
    c.drawCircle(Offset.zero, 10, Paint()..color = _white);
    c.drawCircle(Offset.zero, 6, Paint()..color = _moss);
  }

  // Bus + etiqueta
  void _bus(
    Canvas c,
    YgMapMatrices mm,
    Offset pos,
    double angDeg, {
    required String label,
    required bool live,
    required bool trip,
    required bool stale,
  }) {
    final t = m.clock;
    final loops = !m.rm;
    final w = trip ? 40.0 : 30.0, h = trip ? 24.0 : 18.0;
    c.save();
    c.transform(mm.flat(pos, angDeg).storage);
    // estela
    final wakeW = trip ? 44.0 : 30.0;
    final ph = loops ? (t % 2) : 1.0;
    final tri = Curves.easeInOut.transform(ph < 1 ? ph : 2 - ph);
    final wakeCol = trip ? _cedar : (live ? _moss : _grey);
    final wakeA = live || trip ? .4 : .45;
    c.save();
    final right = -w / 2 + w * .08;
    c.translate(right, 0);
    c.scale(.8 + .25 * tri, 1);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-wakeW, -5, wakeW, 10), const Radius.circular(5)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-wakeW, 0),
          Offset.zero,
          [
            wakeCol.withValues(alpha: 0),
            wakeCol.withValues(alpha: wakeA * (.55 + .45 * tri)),
          ],
        ),
    );
    c.restore();
    // cuerpo
    c.save();
    c.translate(-w / 2, -h / 2);
    c.scale(w / 42, h / 26);
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(1.5, 3, 39, 20), const Radius.circular(5));
    c.drawRRect(body.shift(const Offset(0, 3 * 26 / 18)), _blurPaint(_cedar.withValues(alpha: .3), 3 * 26 / 18));
    final wheel = Paint()..color = _cedar;
    for (final r in const [
      Rect.fromLTWH(6, 1, 7, 3.5),
      Rect.fromLTWH(28, 1, 7, 3.5),
      Rect.fromLTWH(6, 21.5, 7, 3.5),
      Rect.fromLTWH(28, 21.5, 7, 3.5),
    ]) {
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.5)), wheel);
    }
    final est = !live && !trip;
    final fill = trip ? _cedar : (est ? const Color(0xFFC9CBBD) : _moss);
    c.drawRRect(body, Paint()..color = fill);
    final strokeC = est ? _grey : _cedar;
    if (est) {
      final dash = Path();
      for (final mt in (Path()..addRRect(body)).computeMetrics()) {
        for (var d = 0.0; d < mt.length; d += 5) {
          dash.addPath(mt.extractPath(d, math.min(mt.length, d + 3)), Offset.zero);
        }
      }
      c.drawPath(
        dash,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = strokeC,
      );
    } else {
      c.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = strokeC,
      );
    }
    final win = Paint()..color = trip ? _ice : (est ? _white : const Color(0xFFF4F5F1));
    for (final r in const [
      Rect.fromLTWH(33, 6, 4.5, 14),
    ]) {
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), win);
    }
    for (final r in const [
      Rect.fromLTWH(7, 7, 5.5, 4.5),
      Rect.fromLTWH(14.5, 7, 5.5, 4.5),
      Rect.fromLTWH(22, 7, 5.5, 4.5),
      Rect.fromLTWH(7, 14.5, 5.5, 4.5),
      Rect.fromLTWH(14.5, 14.5, 5.5, 4.5),
      Rect.fromLTWH(22, 14.5, 5.5, 4.5),
    ]) {
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1)), win);
    }
    c.restore();
    // anillos
    if (live || trip) {
      if (loops) {
        final p = Curves.easeOut.transform((t / 1.8) % 1);
        final sc = .9 + .45 * p;
        c.save();
        c.scale(sc);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w + 14 - 2, height: h + 14 - 2),
            const Radius.circular(11),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _moss.withValues(alpha: .45 * (1 - p)),
        );
        c.restore();
      }
    } else if (loops) {
      final ph2 = (t / 3) % 1;
      final tri2 = Curves.easeInOut.transform(ph2 < .5 ? ph2 * 2 : 2 - ph2 * 2);
      final sc = .92 + .14 * tri2;
      final oval = Path()
        ..addOval(Rect.fromCenter(center: Offset.zero, width: w + 20 - 1, height: h + 20 - 1));
      final dash = Path();
      for (final mt in oval.computeMetrics()) {
        for (var d = 0.0; d < mt.length; d += 6) {
          dash.addPath(mt.extractPath(d, math.min(mt.length, d + 3)), Offset.zero);
        }
      }
      c.save();
      c.scale(sc);
      c.drawPath(
        dash,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _grey.withValues(alpha: .8 * (.5 + .5 * tri2)),
      );
      c.restore();
    }
    c.restore();

    // etiqueta
    c.save();
    c.transform(mm.billboard(pos).storage);
    c.translate(0, -14);
    _vtag(c, label, live: live, trip: trip, stale: stale);
    c.restore();
  }

  void _vtag(
    Canvas c,
    String label, {
    required bool live,
    required bool trip,
    required bool stale,
  }) {
    final big = trip;
    final tp = _text(
      label,
      big ? 12 : 11,
      FontWeight.w700,
      (live || trip) ? _white : _text2,
    );
    final hasDot = live || trip;
    final w = 7 + (hasDot ? 10.0 : 0) + tp.width + 7;
    final h = big ? 22.0 : 20.0;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(-w / 2, -h, w, h),
      Radius.circular(h / 2),
    );
    if (stale) {
      c.saveLayer(
        rr.outerRect.inflate(14),
        Paint()..color = const Color(0xFF000000).withValues(alpha: .6),
      );
    }
    c.drawRRect(
      rr.shift(const Offset(0, 3)),
      _blurPaint(_cedar.withValues(alpha: hasDot ? .18 : .12), 8),
    );
    if (hasDot) {
      c.drawRRect(rr, Paint()..color = trip ? _cedar : _moss);
      final bl = m.rm ? 1.0 : (((m.clock % 1.2) < .6) ? 1.0 : .625);
      c.drawCircle(
        Offset(rr.left + 7 + 3, -h / 2),
        3,
        Paint()..color = _ice.withValues(alpha: bl),
      );
    } else {
      c.drawRRect(rr, Paint()..color = _white);
      c.drawRRect(
        rr.deflate(.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _grey,
      );
    }
    tp.paint(c, Offset(rr.left + 7 + (hasDot ? 10 : 0), -h / 2 - tp.height / 2));
    if (stale) c.restore();
  }

  /// Parada tocada en [p] (coordenadas del widget) o null.
  int? hitStop(Offset p, Size size) {
    if (!m.stopsShown) return null;
    final mm = ygMapMatrices(m, size);
    final q = Offset(p.dx / mm.k, p.dy / mm.k);
    final d = YgMapData.instance;
    int? best;
    var bestD = 1e9;
    for (var j = 0; j < d.stops.length; j++) {
      final sp = MatrixUtils.transformPoint(
        mm.full,
        Offset(d.stops[j].p[0], d.stops[j].p[1]),
      );
      final sel = m.stopSel[j].value;
      final halfW = 16 + 40 * sel.clamp(0.0, 1.0) + 8;
      final dx = (q.dx - sp.dx).abs(), dy = (q.dy - sp.dy).abs();
      if (dx <= halfW && dy <= 28) {
        final dist = dx + dy;
        if (dist < bestD) {
          bestD = dist;
          best = j;
        }
      }
    }
    return best;
  }
}

enum _Node { plain, mid, pass, xf, al }

enum _PinKind { solid, soft, far }
