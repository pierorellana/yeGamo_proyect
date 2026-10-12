import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'yg_map_svg.dart';

// Mapa base estático de Guayaquil (SVG 1000×1400 de `MapLayer.dc.html`),
// grabado UNA vez en un [ui.Picture] y reutilizado bajo la transformación de
// cámara.

const _land = Color(0xFFF3F4EF);
const _blk = Color(0xFFE3E6DD);
const _blko = Color(0xFFE9EBE4);
const _water = Color(0xFFC8D3CC);
const _shore = Color(0xFFB6C3BA);
const _park = Color(0xFFD3DBC6);

ui.Picture? _cache;
String? _cacheFamily;

/// Devuelve (y cachea) el [ui.Picture] del mapa base.
ui.Picture ygBaseMapPicture(String? fontFamily) {
  if (_cache != null && _cacheFamily == fontFamily) return _cache!;
  final rec = ui.PictureRecorder();
  _BaseBuilder(Canvas(rec), fontFamily).paint();
  _cacheFamily = fontFamily;
  return _cache = rec.endRecording();
}

/// Número de baldosas de patrón dibujadas (para pruebas de rendimiento).
int ygBaseTileCount = 0;

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double w, {bool round = false}) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = round ? StrokeCap.round : StrokeCap.butt
  ..strokeJoin = round ? StrokeJoin.round : StrokeJoin.miter;

class _BaseBuilder {
  _BaseBuilder(this.c, this.family);

  final Canvas c;
  final String? family;

  Path d(String s) => ygParseSvgPath(s);

  void paint() {
    final waterW = d(
      'M-2600 820 C-1500 860 -1000 1050 -880 1330 C-800 1560 -720 1820 -380 2300 L-380 4000 L-2600 4000 Z',
    );
    const eastWaterD =
        'M846 -400 C830 -60 824 180 813 380 C806 520 800 640 803 760 C806 900 812 1010 797 1150 C790 1260 806 1420 812 1800 L3600 1800 L3600 -400 Z';
    final waterE = d(eastWaterD);

    const bigRect = Rect.fromLTRB(-2600, -2600, 3600, 4000);
    c.drawRect(bigRect, _fill(_land));
    _tiles(
      bounds: bigRect,
      w: 46,
      h: 40,
      x: 4,
      y: 4,
      rw: 38,
      rh: 32,
      r: 3,
      deg: -12,
      color: _blko,
      skip: [waterW, waterE],
    );
    c.drawPath(waterW, _fill(_water));
    _text('Golfo de Guayaquil', -2050, 2050, const Color(0xFFA9B8AF), 72,
        italic: true, ls: 7.2);

    // Patrones de manzanas
    void blocks(String pd, double w, double h, double x, double y, double rw,
        double rh, double r, double deg) {
      final p = d(pd);
      c.save();
      c.clipPath(p);
      _tiles(
        bounds: p.getBounds(),
        w: w,
        h: h,
        x: x,
        y: y,
        rw: rw,
        rh: rh,
        r: r,
        deg: deg,
        color: _blk,
      );
      c.restore();
    }

    blocks('M-60 120 L430 110 L470 300 L430 620 L360 730 L-60 780 Z', 30, 22,
        2.5, 2.5, 25, 17, 2.5, -24);
    blocks('M-60 -180 L460 -180 L440 120 L-60 130 Z', 30, 22, 2.5, 2.5, 25, 17,
        2.5, -24);
    blocks('M430 -180 L880 -180 L850 380 L640 470 L450 470 L440 290 Z', 26, 24,
        2.5, 2.5, 21, 19, 2, 8);
    blocks('M430 470 L650 470 L840 410 L840 1110 L400 1110 L360 740 Z', 22, 19,
        2, 2, 18, 15, 1.5, 3);
    blocks('M-60 760 L380 720 L400 1110 L840 1110 L840 1560 L-60 1560 Z', 28,
        22, 2.5, 2.5, 23, 17, 2, -4);

    c.drawPath(
      d('M846 -400 C830 -60 824 180 813 380 C806 520 800 640 803 760 C806 900 812 1010 797 1150 C790 1260 806 1420 812 1800'),
      _stroke(_shore, 5),
    );
    c.drawPath(waterE, _fill(_water));
    final eastLand = d(
      'M1150 -400 C1120 200 1130 700 1160 1100 C1175 1350 1150 1600 1180 1800 L3600 1800 L3600 -400 Z',
    );
    c.drawPath(eastLand, _fill(_land));
    c.save();
    c.clipPath(eastLand);
    _tiles(
      bounds: eastLand.getBounds(),
      w: 46,
      h: 40,
      x: 4,
      y: 4,
      rw: 38,
      rh: 32,
      r: 3,
      deg: -12,
      color: _blko,
    );
    c.restore();

    c.drawPath(
      d('M930 690 C905 780 908 905 936 1010 C962 1085 1040 1092 1080 1010 C1105 930 1100 780 1068 712 C1032 650 962 640 930 690 Z'),
      _fill(_park),
    );

    const estD =
        'M540 -400 C505 -60 470 120 452 250 C440 340 410 420 402 480 C396 530 420 560 410 600 C400 640 392 668 380 690 C352 740 300 790 220 850 C150 900 60 915 -400 935';
    const est2D = 'M452 250 C410 232 350 214 280 200 C200 186 120 190 -400 210';
    c.drawPath(d(estD), _stroke(_shore, 39, round: true));
    c.drawPath(d(est2D), _stroke(_shore, 21, round: true));
    c.drawPath(d(estD), _stroke(_water, 34, round: true));
    c.drawPath(d(est2D), _stroke(_water, 17, round: true));
    c.drawPath(
      d('M788 470 C791 580 793 680 795 780 C797 860 800 900 798 960'),
      _stroke(_park, 16, round: true),
    );
    void parkRect(double x, double y, double w, double h, double r) =>
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
          _fill(_park),
        );
    parkRect(536, 588, 50, 36, 4);
    parkRect(700, 676, 22, 18, 3);
    parkRect(590, 960, 70, 46, 6);
    parkRect(56, 420, 44, 30, 5);
    const ctrC = Color(0xFFBAC6AA);
    c.drawOval(Rect.fromCenter(center: const Offset(768, 430), width: 72, height: 54), _fill(_park));
    c.drawOval(Rect.fromCenter(center: const Offset(768, 430), width: 48, height: 34), _stroke(ctrC, 1.2));
    c.drawOval(Rect.fromCenter(center: const Offset(768, 430), width: 24, height: 16), _stroke(ctrC, 1.2));
    c.drawPath(
      d('M560 -330 C680 -360 800 -300 820 -200 C840 -110 720 -60 600 -80 C500 -100 470 -300 560 -330 Z'),
      _fill(_park),
    );
    // Aeropuerto
    c.save();
    c.translate(680, 40);
    c.rotate(-8 * math.pi / 180);
    c.translate(-680, -40);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(520, 8, 330, 66), const Radius.circular(8)),
      _fill(const Color(0xFFE2E5DC)),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(530, 34, 310, 12), const Radius.circular(6)),
      _fill(const Color(0xFFD2D6CA)),
    );
    final rw = Path()
      ..moveTo(545, 40)
      ..lineTo(825, 40);
    _dashed(rw, _stroke(const Color(0xFFFFFFFF), 1.2), 8, 8);
    c.restore();

    // Autopistas
    const hwcC = Color(0xFFD2D6CA);
    const white = Color(0xFFFFFFFF);
    final hw1 = d(
      'M-400 90 C0 100 240 120 360 150 C470 178 520 230 600 270 C690 312 740 290 813 215 L1150 140',
    );
    c.drawPath(hw1, _stroke(hwcC, 13, round: true));
    c.drawPath(hw1, _stroke(white, 9, round: true));
    final hw2 = d('M60 640 C-200 700 -500 900 -760 1290');
    c.drawPath(hw2, _stroke(hwcC, 13, round: true));
    c.drawPath(hw2, _stroke(white, 9, round: true));
    // Avenidas
    const rd2C = Color(0xFFFAFBF8);
    for (final s in const [
      'M450 160 L840 140',
      'M520 100 L540 470',
      'M120 560 L168 470 L210 380 L250 280 L300 150',
      'M-400 560 L40 530 L168 470 L240 560 L330 650 L420 720',
      'M150 420 L290 330 L380 300 L470 290 L560 330 L640 420 L700 540 L735 640 L760 730',
      'M420 740 L430 1560',
      'M200 1000 L400 990',
      'M380 900 L800 890',
      'M400 1000 L800 990',
    ]) {
      c.drawPath(d(s), _stroke(rd2C, 4.5, round: true));
    }
    for (final s in const [
      'M690 110 L660 300 L630 470',
      'M615 470 L622 760 L632 1110 L640 1560',
      'M565 476 L578 800 L592 1560',
      'M776 470 L783 760 L790 1110 L800 1560',
      'M-200 100 L60 250 L150 340 L252 432 L334 520 L420 588',
      'M420 588 L488 618 L560 634 L640 646 L735 660 L790 668',
    ]) {
      c.drawPath(d(s), _stroke(white, 7, round: true));
    }
    c.drawPath(
      d('M420 720 L560 722 L680 716 L790 724'),
      _stroke(const Color(0xFFE1E6D7), 8, round: true),
    );
    // Edificios
    const bs = Color(0xFFC9CEC0);
    final brFill = _fill(_blko);
    final brStroke = _stroke(const Color(0xFFD2D6CA), .6);
    for (final b in const [
      [596, 601, 18, 14], [664, 601, 22, 18], [694, 605, 14, 14], //
      [752, 603, 16, 20], [634, 687, 20, 16], [672, 685, 20, 16],
      [748, 695, 20, 16], [659, 749, 22, 18], [694, 745, 26, 20],
      [728, 755, 20, 22], [640, 775, 16, 16], [704, 785, 18, 18],
      [746, 789, 24, 16], [672, 805, 20, 22],
    ]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(b[0] + .0, b[1] + .0, b[2] + .0, b[3] + .0),
          const Radius.circular(2),
        ),
        _fill(bs),
      );
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(b[0] - 4.0, b[1] - 5.0, b[2] + .0, b[3] + .0),
        const Radius.circular(2),
      );
      c.drawRRect(r, brFill);
      c.drawRRect(r, brStroke);
    }

    // Etiquetas
    const lbl = Color(0xFF7C8371);
    for (final l in const [
      ['URDESA', 60.0, 490.0],
      ['MIRAFLORES', 110.0, 690.0],
      ['KENNEDY', 372.0, 70.0],
      ['CENTRO', 470.0, 850.0],
      ['LAS PEÑAS', 736.0, 392.0],
      ['BARRIO CENTENARIO', 470.0, 1210.0],
      ['AEROPUERTO', 630.0, -14.0],
      ['DURÁN', 1250.0, 560.0],
    ]) {
      _text(l[0] as String, l[1] as double, l[2] as double, lbl, 10.5,
          w: FontWeight.w600, ls: 2.31);
    }
    const wl = Color(0xFF6C8378);
    _textAt('Río Guayas', 918, 470, -86, wl, 12, italic: true, ls: .96);
    const pl = Color(0xFF6B7D58);
    _textAt('Isla Santay', 1004, 900, -82, pl, 8.5, w: FontWeight.w500, ls: .34);
    _textAt('Malecón 2000', 810, 905, -89, pl, 8.5, w: FontWeight.w500, ls: .34);
    _text('Parque Centenario', 540, 583, pl, 8.5, w: FontWeight.w500, ls: .34);
    _text('Cerro Santa Ana', 744, 472, pl, 8.5, w: FontWeight.w500, ls: .34);
    _textPath(
      'Estero Salado',
      d('M70 912 C170 896 262 818 380 690'),
      .30,
      wl,
      12,
      italic: true,
      ls: .96,
    );
    const sl = Color(0xFF9EA392);
    _textPath(
      'AV. 9 DE OCTUBRE',
      d('M420 588 L488 618 L560 634 L640 646 L735 660 L790 668'),
      .16,
      sl,
      7.4,
      w: FontWeight.w600,
      ls: 1.036,
      dy: 2.6,
    );
    _textPath(
      'AV. V. E. ESTRADA',
      d('M60 250 L150 340 L252 432 L334 520'),
      .44,
      sl,
      7.4,
      w: FontWeight.w600,
      ls: 1.036,
      dy: 2.6,
    );
    _textAt('VÍA A LA COSTA', -520, 900, -38, const Color(0xFFCDD1C5), 64,
        w: FontWeight.w600, ls: 17.92);
  }

  // ---- helpers ----

  void _dashed(Path p, Paint paint, double on, double off) {
    for (final m in p.computeMetrics()) {
      var dd = 0.0;
      while (dd < m.length) {
        c.drawPath(m.extractPath(dd, math.min(m.length, dd + on)), paint);
        dd += on + off;
      }
    }
  }

  void _tiles({
    required Rect bounds,
    required double w,
    required double h,
    required double x,
    required double y,
    required double rw,
    required double rh,
    required double r,
    required double deg,
    required Color color,
    List<Path> skip = const [],
  }) {
    final a = deg * math.pi / 180;
    final ca = math.cos(a), sa = math.sin(a);
    // Bounds del rectángulo en el espacio rotado del patrón (rotación inversa).
    var minx = 1e18, miny = 1e18, maxx = -1e18, maxy = -1e18;
    for (final p in [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ]) {
      final px = p.dx * ca + p.dy * sa, py = -p.dx * sa + p.dy * ca;
      minx = math.min(minx, px);
      maxx = math.max(maxx, px);
      miny = math.min(miny, py);
      maxy = math.max(maxy, py);
    }
    final i0 = (minx / w).floor() - 1, i1 = (maxx / w).ceil() + 1;
    final j0 = (miny / h).floor() - 1, j1 = (maxy / h).ceil() + 1;
    final path = Path();
    for (var i = i0; i <= i1; i++) {
      for (var j = j0; j <= j1; j++) {
        final lx = i * w + x, ly = j * h + y;
        if (skip.isNotEmpty) {
          // Centro de la baldosa en coordenadas de mundo.
          final cx = lx + rw / 2, cy = ly + rh / 2;
          final wx = cx * ca - cy * sa, wy = cx * sa + cy * ca;
          if (!bounds.inflate(60).contains(Offset(wx, wy))) continue;
          var hidden = false;
          for (final s in skip) {
            if (s.contains(Offset(wx, wy))) {
              hidden = true;
              break;
            }
          }
          if (hidden) continue;
        }
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(lx, ly, rw, rh),
            Radius.circular(r),
          ),
        );
        ygBaseTileCount++;
      }
    }
    c.save();
    c.rotate(a);
    c.drawPath(path, _fill(color));
    c.restore();
  }

  TextStyle _style(Color color, double size, FontWeight? w, bool italic, double ls) =>
      TextStyle(
        fontFamily: family,
        color: color,
        fontSize: size,
        fontWeight: w ?? FontWeight.w400,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: ls,
        height: 1,
      );

  TextPainter _tp(String s, TextStyle st) =>
      TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)
        ..layout();

  void _text(String s, double x, double y, Color color, double size,
      {FontWeight? w, bool italic = false, double ls = 0}) {
    final tp = _tp(s, _style(color, size, w, italic, ls));
    tp.paint(c, Offset(x, y - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
  }

  void _textAt(String s, double x, double y, double deg, Color color, double size,
      {FontWeight? w, bool italic = false, double ls = 0}) {
    c.save();
    c.translate(x, y);
    c.rotate(deg * math.pi / 180);
    _text(s, 0, 0, color, size, w: w, italic: italic, ls: ls);
    c.restore();
  }

  void _textPath(String s, Path path, double startFrac, Color color, double size,
      {FontWeight? w, bool italic = false, double ls = 0, double dy = 0}) {
    final metric = path.computeMetrics().first;
    var pos = metric.length * startFrac;
    final style = _style(color, size, w, italic, ls);
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      final tp = _tp(ch, style);
      final mid = pos + tp.width / 2;
      if (mid > metric.length) break;
      final tan = metric.getTangentForOffset(mid);
      if (tan != null && ch.trim().isNotEmpty) {
        c.save();
        c.translate(tan.position.dx, tan.position.dy);
        c.rotate(math.atan2(tan.vector.dy, tan.vector.dx));
        tp.paint(
          c,
          Offset(
            -tp.width / 2,
            dy - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic),
          ),
        );
        c.restore();
      }
      pos += tp.width;
    }
  }
}
