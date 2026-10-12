import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import 'scene_clock.dart';

/// Escena del splash (01-splash): solo tipografía. Keyframes `splL`, `splPop`,
/// `splRl` y `splT` de Main.dc.html (líneas 159–173), en lienzo de 390×844.
class SplashScene extends StatelessWidget {
  const SplashScene({super.key, required this.clock, this.footer});

  final SceneClock clock;

  /// Pie honesto bajo el logotipo; `null` lo omite.
  final String? footer;

  static const _letters = ['y', 'e', 'G', 'a', 'm', 'o'];
  static const _letterCurve = Cubic(.2, 1, .3, 1);

  @override
  Widget build(BuildContext context) {
    return ClockBuilder(
      clock: clock,
      builder: (context, t) {
        return Stack(
          children: [
            Positioned(
              top: 344,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  _word(t),
                  const SizedBox(height: 20),
                  CustomPaint(
                    size: const Size(132, 14),
                    painter: _RoutePainter(
                      line: segP(t, 1000, 1500, const Cubic(.6, 0, .2, 1)),
                      origin: segP(t, 900, 500, const Cubic(.34, 1.6, .5, 1)),
                      dest: segP(t, 2400, 550, const Cubic(.34, 1.8, .5, 1)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fadeUp(
                    segP(t, 1200, 800, Curves.ease),
                    const Text(
                      'Sal a tiempo.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        letterSpacing: -.075,
                        color: YgColors.text3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (footer != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 44,
                child: _fadeUp(
                  segP(t, 1600, 800, Curves.ease),
                  Text(
                    footer!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      letterSpacing: 1.1,
                      color: YgColors.cedar,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _fadeUp(double p, Widget child) => Opacity(
    opacity: p.clamp(0.0, 1.0),
    child: Transform.translate(offset: Offset(0, 6 * (1 - p)), child: child),
  );

  Widget _word(double t) {
    return SizedBox(
      height: 52,
      child: ClipRect(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _letters.length; i++)
              _letter(i, segP(t, 250 + 50.0 * i, 900, _letterCurve)),
          ],
        ),
      ),
    );
  }

  Widget _letter(int i, double p) {
    return Opacity(
      opacity: p.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 52 * (1 - p)),
        child: Text(
          _letters[i],
          style: TextStyle(
            fontSize: 44,
            height: 52 / 44,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.98,
            color: i == 2 ? YgColors.cypress : YgColors.moss,
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.line,
    required this.origin,
    required this.dest,
  });

  final double line;
  final double origin;
  final double dest;

  @override
  void paint(Canvas canvas, Size size) {
    if (line > 0) {
      canvas.drawLine(
        const Offset(7, 7),
        Offset(7 + 118 * line, 7),
        Paint()
          ..color = YgColors.olive
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
    if (origin > 0) {
      canvas.drawCircle(const Offset(7, 7), 4.5 * origin, Paint()..color = Colors.white);
      canvas.drawCircle(
        const Offset(7, 7),
        4.5 * origin,
        Paint()
          ..color = YgColors.moss
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * origin,
      );
    }
    if (dest > 0) {
      canvas.drawCircle(const Offset(125, 7), 5 * dest, Paint()..color = YgColors.moss);
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.line != line || old.origin != origin || old.dest != dest;
}
