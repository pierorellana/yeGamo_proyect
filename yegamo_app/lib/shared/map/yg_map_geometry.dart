// Geometría pura del mapa (sin dependencias de Flutter). Port directo de las
// funciones L/PL/AT/ATF/SEG/SEGD/RP/FIT y de los datos de `MapLayer.dc.html`.
//
// Los datos de este archivo son DEMO (rutas, paradas y buses simulados): solo
// se dibujan cuando `showDemoOverlays` está activo.
import 'dart:math' as math;

typedef YgPt = List<double>;

/// Distancia entre dos puntos.
double ygL(YgPt a, YgPt b) {
  final dx = b[0] - a[0], dy = b[1] - a[1];
  return math.sqrt(dx * dx + dy * dy);
}

/// Longitud de una polilínea.
double ygPL(List<YgPt> p) {
  double s = 0;
  for (var i = 1; i < p.length; i++) {
    s += ygL(p[i - 1], p[i]);
  }
  return s;
}

/// Punto [x, y, ángulo] a la distancia [d] a lo largo de la polilínea.
List<double> ygAT(List<YgPt> p, double d) {
  for (var i = 1; i < p.length; i++) {
    final l = ygL(p[i - 1], p[i]);
    if (d <= l) {
      final k = l == 0 ? 0.0 : d / l;
      return [
        p[i - 1][0] + (p[i][0] - p[i - 1][0]) * k,
        p[i - 1][1] + (p[i][1] - p[i - 1][1]) * k,
        math.atan2(p[i][1] - p[i - 1][1], p[i][0] - p[i - 1][0]),
      ];
    }
    d -= l;
  }
  final n = p.length;
  return [
    p[n - 1][0],
    p[n - 1][1],
    math.atan2(p[n - 1][1] - p[n - 2][1], p[n - 1][0] - p[n - 2][0]),
  ];
}

/// Como [ygAT] pero con una fracción 0–1 de la longitud total.
List<double> ygATF(List<YgPt> p, double f) =>
    ygAT(p, ygPL(p) * math.max(0.0, math.min(1.0, f)));

/// Punto [x, y, ángulo] en el segmento fraccionario [sp] (0..n-1).
List<double> ygSEG(List<YgPt> p, double sp) {
  final n = p.length - 1;
  final x = math.max(0.0, math.min(n.toDouble(), sp));
  final i = math.min(x.floor(), n - 1);
  final k = x - i;
  final a = p[i], b = p[i + 1];
  return [
    a[0] + (b[0] - a[0]) * k,
    a[1] + (b[1] - a[1]) * k,
    math.atan2(b[1] - a[1], b[0] - a[0]),
  ];
}

/// Distancia recorrida hasta el segmento fraccionario [sp].
double ygSEGD(List<YgPt> p, double sp) {
  final n = p.length - 1;
  final x = math.max(0.0, math.min(n.toDouble(), sp));
  final i = math.min(x.floor(), n - 1);
  double d = 0;
  for (var j = 0; j < i; j++) {
    d += ygL(p[j], p[j + 1]);
  }
  return d + ygL(p[i], p[i + 1]) * (x - i);
}

double _f(double v) => (v * 10).round() / 10;

String _n(double v) {
  final s = v.toString();
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Polilínea con esquinas redondeadas (`RP`): devuelve datos de path SVG
/// (`M … L … Q …`).
String ygRP(List<YgPt> p, double r) {
  final b = StringBuffer('M${_n(p[0][0])} ${_n(p[0][1])}');
  for (var i = 1; i < p.length - 1; i++) {
    final a = p[i - 1], v = p[i], c = p[i + 1];
    final la = ygL(v, a), lb = ygL(v, c);
    final ra = math.min(r, la / 2), rb = math.min(r, lb / 2);
    final x1 = v[0] + (a[0] - v[0]) * ra / la;
    final y1 = v[1] + (a[1] - v[1]) * ra / la;
    final x2 = v[0] + (c[0] - v[0]) * rb / lb;
    final y2 = v[1] + (c[1] - v[1]) * rb / lb;
    b.write(
      ' L${_n(_f(x1))} ${_n(_f(y1))} Q${_n(v[0])} ${_n(v[1])} '
      '${_n(_f(x2))} ${_n(_f(y2))}',
    );
  }
  final e = p[p.length - 1];
  b.write(' L${_n(e[0])} ${_n(e[1])}');
  return b.toString();
}

/// Encuadre [cx, cy, sx, sy, s, tilt]: mundo (cx,cy) en pantalla (sx,sy).
List<double> ygFIT(List<YgPt> pts, double top, double bottom) {
  double minx = 1e9, miny = 1e9, maxx = -1e9, maxy = -1e9;
  for (final p in pts) {
    if (p[0] < minx) minx = p[0];
    if (p[0] > maxx) maxx = p[0];
    if (p[1] < miny) miny = p[1];
    if (p[1] > maxy) maxy = p[1];
  }
  final bw = math.max(60.0, maxx - minx), bh = math.max(60.0, maxy - miny);
  final avail = math.max(120.0, bottom - top - 80);
  var s = math.min(232 / bw, avail / bh);
  s = math.max(0.25, math.min(2.4, s));
  return [(minx + maxx) / 2, (miny + maxy) / 2, 168, (top + bottom) / 2 + 6, s, 0];
}

/// Alternativa de ruta demo.
class YgAlt {
  YgAlt({
    required this.n,
    required this.live,
    required this.w1,
    required this.ride,
    required this.w2,
    required this.ap,
    required this.xf,
  }) : rd = ygRP(ride, 24),
       w1d = ygRP(w1, 10),
       w2d = ygRP(w2, 8),
       all = [...w1, ...ride, ...w2];

  final String n;
  final bool live;
  final List<YgPt> w1;
  final List<YgPt> ride;
  final List<YgPt> w2;
  final List<YgPt> ap;
  final int xf;
  final String rd;
  final String w1d;
  final String w2d;
  final List<YgPt> all;
}

/// Bus simulado (DEMO).
class YgSim {
  YgSim({
    required this.n,
    required this.live,
    required this.deg,
    required this.v,
    required this.off,
    required this.line,
  }) : len = ygPL(line);

  final String n;
  final bool live;
  final bool deg;
  final double v;
  final double off;
  final List<YgPt> line;
  final double len;
}

class YgSimLine {
  const YgSimLine(this.d, this.live, this.deg, this.n);
  final String d;
  final bool live;
  final bool deg;
  final String n;
}

class YgStopData {
  const YgStopData(this.p, this.n);
  final YgPt p;
  final String n;
}

/// Datos demo del mapa (equivale a `data()`).
class YgMapData {
  YgMapData._() {
    final l14 = <YgPt>[
      [60, 250], [150, 340], [252, 432], [334, 520], [420, 588], //
      [488, 618], [560, 634], [640, 646], [735, 660], [800, 668],
    ];
    alts = [
      YgAlt(
        n: '14',
        live: true,
        w1: [[196, 372], [226, 386], [252, 432]],
        ride: [
          [252, 432], [334, 520], [420, 588], [488, 618], [560, 634], //
          [640, 646], [735, 660],
        ],
        w2: [[735, 660], [744, 680], [754, 698]],
        ap: [[150, 340], [252, 432]],
        xf: -1,
      ),
      YgAlt(
        n: 'A2',
        live: true,
        w1: [[196, 372], [176, 420], [168, 470]],
        ride: [
          [168, 470], [240, 560], [330, 650], [420, 720], [560, 722], //
          [680, 716], [748, 724],
        ],
        w2: [[748, 724], [754, 698]],
        ap: [[40, 530], [168, 470]],
        xf: 3,
      ),
      YgAlt(
        n: '59',
        live: false,
        w1: [[196, 372], [240, 350], [290, 330]],
        ride: [
          [290, 330], [380, 300], [470, 290], [560, 330], [640, 420], //
          [700, 540], [735, 640],
        ],
        w2: [[735, 640], [746, 668], [754, 698]],
        ap: [[150, 420], [290, 330]],
        xf: -1,
      ),
    ];
    sims = [
      YgSim(n: '14', live: true, deg: false, v: 10, off: 150, line: l14),
      YgSim(n: '14', live: false, deg: false, v: 10, off: 560, line: l14),
      YgSim(
        n: '59',
        live: false,
        deg: true,
        v: 9,
        off: 60,
        line: [
          [150, 420], [290, 330], [380, 300], [470, 290], [560, 330], //
          [640, 420], [700, 540], [735, 640], [760, 730],
        ],
      ),
      YgSim(
        n: 'A2',
        live: true,
        deg: true,
        v: 11,
        off: 40,
        line: [[40, 530], [168, 470], [240, 560], [330, 650], [420, 720]],
      ),
      YgSim(
        n: '22',
        live: false,
        deg: true,
        v: 7,
        off: 30,
        line: [[120, 560], [168, 470], [210, 380], [250, 280], [300, 150]],
      ),
      YgSim(
        n: 'T3',
        live: true,
        deg: false,
        v: 14,
        off: 100,
        line: [[420, 720], [560, 722], [680, 716], [790, 724]],
      ),
    ];
    slines = [0, 2, 3, 4, 5]
        .map(
          (i) => YgSimLine(
            ygRP(sims[i].line, 18),
            sims[i].live,
            sims[i].deg,
            sims[i].n,
          ),
        )
        .toList();
  }

  static final YgMapData instance = YgMapData._();

  late final List<YgAlt> alts;
  late final List<YgSim> sims;
  late final List<YgSimLine> slines;

  final YgPt home = const [196.0, 372.0];
  final YgPt work = const [754.0, 698.0];
  final YgPt playas = const [-760.0, 1290.0];
  final List<YgStopData> stops = const [
    YgStopData([252.0, 432.0], 'V. E. Estrada y Ficus'),
    YgStopData([290.0, 330.0], 'Circunvalación y Todos los Santos'),
    YgStopData([168.0, 470.0], 'Av. Las Monjas'),
  ];
}
