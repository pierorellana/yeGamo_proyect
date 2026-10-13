import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';

/// Moneda con check (`.okc`): gira (`coin`, rotateY) y dibuja círculo y check
/// (`mdraw`). Con movimiento reducido aparece completa.
class ArrivalCoin extends StatefulWidget {
  const ArrivalCoin({super.key});

  @override
  State<ArrivalCoin> createState() => _ArrivalCoinState();
}

class _ArrivalCoinState extends State<ArrivalCoin>
    with SingleTickerProviderStateMixin {
  static const _total = 1300; // ms: check termina a 0,85 + 0,45 s
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (YgMotionScope.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _seg(double ms, double start, double dur, Curve curve) =>
      curve.transform(((ms - start) / dur).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Llegada confirmada',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 72,
          height: 72,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final ms = _c.value * _total;
              final coin = _seg(ms, 100, 1000, const Cubic(.3, 1.2, .4, 1));
              final glow = _seg(ms, 600, 700, Curves.ease);
              final circle = _seg(ms, 150, 800, const Cubic(.6, 0, .3, 1));
              final tick = _seg(ms, 850, 450, Curves.easeOut);
              final angle = -math.pi * (1 - coin);
              final scale = .6 + .4 * coin;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -12,
                    top: -12,
                    right: -12,
                    bottom: -12,
                    child: Opacity(
                      opacity: glow,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0x38768064), Color(0x00768064)],
                            stops: [0, .7],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: coin.clamp(0.0, 1.0),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, -1 / 500)
                        ..rotateY(angle)
                        ..multiply(Matrix4.diagonal3Values(scale, scale, 1)),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: CustomPaint(
                          size: const Size(56, 56),
                          painter: _CheckPainter(circle: circle, tick: tick),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.circle, required this.tick});

  final double circle;
  final double tick;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 88;
    canvas.scale(k);
    const color = YgColors.cypress;
    canvas.drawCircle(
      const Offset(44, 44),
      40,
      Paint()..color = const Color(0x144C583E),
    );
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (circle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(44, 44), radius: 40),
        -math.pi / 2,
        2 * math.pi * circle,
        false,
        stroke..strokeWidth = 4,
      );
    }
    if (tick > 0) {
      final path = Path()
        ..moveTo(27, 45)
        ..lineTo(39, 57)
        ..lineTo(62, 32);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * tick),
        stroke..strokeWidth = 5,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.circle != circle || old.tick != tick;
}

/// Estadística (`.stat`).
class ArrivalStat extends StatelessWidget {
  const ArrivalStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: YgColors.fill2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: YgText.meta),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -.34,
              color: YgColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja fija inferior de la llegada (`.sheet` de 568 px, sin arrastre).
class ArrivalSheetSurface extends StatelessWidget {
  const ArrivalSheetSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(YgRadius.sheet);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: YgShadows.sheet),
      child: ClipRRect(
        borderRadius: r,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(
              color: YgColors.moss.withValues(alpha: .08),
              width: .5,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF7FFFFFF), Color(0xF7FFFFFF), Color(0xF7F6F8F2)],
              stops: [0, .55, 1],
            ),
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}
