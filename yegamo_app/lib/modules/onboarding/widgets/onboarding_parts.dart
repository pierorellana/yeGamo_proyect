import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import 'scene_clock.dart';

const _blobIn = Cubic(.2, 1, .3, 1);

/// `.blob`: mancha radial que entra (`blobIn`, 1,1 s) y respira (`blobBr`, 8 s).
class ObBlob extends StatelessWidget {
  const ObBlob({
    super.key,
    required this.clock,
    required this.left,
    required this.top,
    required this.size,
    required this.kind,
  });

  final SceneClock clock;
  final double left;
  final double top;
  final double size;

  /// 1, 2 o 3 (`.b1`, `.b2`, `.b3`).
  final int kind;

  Gradient get _gradient {
    switch (kind) {
      case 1:
        return const RadialGradient(
          radius: .7071,
          colors: [Color(0x52768064), Color(0x1F768064), Color(0x00768064)],
          stops: [0, .44, .70],
        );
      case 2:
        return const RadialGradient(
          radius: .7071,
          colors: [Color(0xF2DADED8), Color(0x00DADED8)],
          stops: [0, .70],
        );
      default:
        return const RadialGradient(
          radius: .7071,
          colors: [Color(0x33959581), Color(0x00959581)],
          stops: [0, .70],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: IgnorePointer(
        child: ClockBuilder(
          clock: clock,
          builder: (context, t) {
            final p = segP(t, 0, 1100, _blobIn);
            var scale = lerpD(.6, 1, p);
            var dx = 0.0;
            var dy = 0.0;
            final ph = loopPhase(t, 1100, 8000);
            if (ph != null) {
              final tri = ph < .5 ? ph * 2 : (1 - ph) * 2;
              final e = Curves.easeInOut.transform(tri);
              scale = 1 + .06 * e;
              dx = 4 * e;
              dy = -6 * e;
            }
            return Opacity(
              opacity: p.clamp(0.0, 1.0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.translationValues(dx, dy, 0)
                  ..multiply(Matrix4.diagonal3Values(scale, scale, 1)),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _gradient,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum ObDotKind { icon, dark, point, pointLight }

/// `.fdot`: punto/insignia flotante (`dotIn` + `dotFl`).
class ObFloatDot extends StatelessWidget {
  const ObFloatDot({
    super.key,
    required this.clock,
    required this.x,
    required this.y,
    this.icon,
    this.kind = ObDotKind.icon,
    this.inDelay = 0,
    this.floatDelay = 0,
  });

  final SceneClock clock;
  final double x;
  final double y;
  final String? icon;
  final ObDotKind kind;

  /// Retardos en ms de `dotIn` y `dotFl` (nth-of-type del prototipo).
  final double inDelay;
  final double floatDelay;

  @override
  Widget build(BuildContext context) {
    final isPoint = kind == ObDotKind.point || kind == ObDotKind.pointLight;
    final size = isPoint ? 10.0 : 40.0;
    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      width: size,
      height: size,
      child: ClockBuilder(
        clock: clock,
        builder: (context, t) {
          final p = segP(t, inDelay, 700, const Cubic(.34, 1.6, .5, 1));
          final ph = loopPhase(t, floatDelay, 6000);
          var dy = 0.0;
          if (ph != null) {
            final tri = ph < .5 ? ph * 2 : (1 - ph) * 2;
            dy = -8 * Curves.easeInOut.transform(tri);
          }
          return Opacity(
            opacity: p.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, dy),
              child: _body(size),
            ),
          );
        },
      ),
    );
  }

  Widget _body(double size) {
    switch (kind) {
      case ObDotKind.point:
        return const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: YgColors.olive,
            boxShadow: [
              BoxShadow(color: Color(0x29768064), spreadRadius: 4),
            ],
          ),
        );
      case ObDotKind.pointLight:
        return const DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: YgColors.aloe),
        );
      case ObDotKind.dark:
      case ObDotKind.icon:
        final dark = kind == ObDotKind.dark;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? YgColors.moss : Colors.white,
            boxShadow: const [
              BoxShadow(color: Color(0x0D2C3424), spreadRadius: 1),
              BoxShadow(
                color: Color(0x1F2C3424),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: YgIcon(
              icon!,
              size: 18,
              color: dark ? Colors.white : YgColors.cypress,
            ),
          ),
        );
    }
  }
}

/// Sombra de las tarjetas flotantes del onboarding.
const obCardShadow = [
  BoxShadow(color: Color(0x0D2C3424), spreadRadius: 1),
  BoxShadow(color: Color(0x0A2C3424), blurRadius: 4, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x242C3424), blurRadius: 48, offset: Offset(0, 24)),
];

/// Estilos de texto del prototipo para tarjetas.
const obXs = TextStyle(
  fontSize: 12,
  height: 1.35,
  letterSpacing: -.12,
  color: YgColors.text2,
);

/// Ángulo CSS (`linear-gradient(<deg>, …)`) sobre un rectángulo.
(Offset, Offset) cssGradientLine(Rect r, double deg) {
  final a = deg * math.pi / 180;
  final dx = math.sin(a);
  final dy = -math.cos(a);
  final len = (r.width * dx).abs() + (r.height * dy).abs();
  final c = r.center;
  final half = Offset(dx * len / 2, dy * len / 2);
  return (c - half, c + half);
}

/// Dibuja un camino cúbico recortado a la fracción [p] de su longitud
/// (`stroke-dasharray:1 1` + `mdraw`).
Path partialPath(Path full, double p) {
  final out = Path();
  for (final m in full.computeMetrics()) {
    out.addPath(m.extractPath(0, m.length * p.clamp(0.0, 1.0)), Offset.zero);
  }
  return out;
}

/// Trazo discontinuo manual (`stroke-dasharray: on off`).
void drawDashed(Canvas canvas, Path path, Paint paint, double on, double off) {
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      canvas.drawPath(m.extractPath(d, math.min(d + on, m.length)), paint);
      d += on + off;
    }
  }
}
