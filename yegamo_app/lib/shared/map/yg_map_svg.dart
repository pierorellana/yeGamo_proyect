import 'dart:math' as math;
import 'dart:ui';

final RegExp _tok = RegExp(r'[MLCQZmlcqz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?');

/// Parser mínimo de datos de path SVG (M, L, C, Q, Z en mayúsculas), suficiente
/// para el mapa base y las rutas del prototipo.
Path ygParseSvgPath(String d) {
  final t = _tok.allMatches(d).map((m) => m[0]!).toList();
  final path = Path();
  var i = 0;
  String? cmd;
  double num() => double.parse(t[i++]);
  while (i < t.length) {
    final s = t[i];
    if (RegExp(r'[A-Za-z]').hasMatch(s)) {
      cmd = s;
      i++;
      if (cmd == 'Z' || cmd == 'z') {
        path.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        path.moveTo(num(), num());
        cmd = 'L';
      case 'L':
        path.lineTo(num(), num());
      case 'C':
        path.cubicTo(num(), num(), num(), num(), num(), num());
      case 'Q':
        path.quadraticBezierTo(num(), num(), num(), num());
      default:
        i++;
    }
  }
  return path;
}

/// Extrae un tramo [a]..[b] (fracciones 0–1 de la longitud total) de [path].
Path ygPathSlice(List<PathMetric> metrics, double total, double a, double b) {
  final out = Path();
  var offset = 0.0;
  final from = a * total, to = b * total;
  for (final m in metrics) {
    final end = offset + m.length;
    final s = math.max(from, offset) - offset;
    final e = math.min(to, end) - offset;
    if (e > s) out.addPath(m.extractPath(s, e), Offset.zero);
    offset = end;
  }
  return out;
}
