import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../onboarding/widgets/scene_clock.dart';

/// `.radar` de 03-permisos: tres anillos de 240 px que se expanden cada 3,2 s
/// (desfasados 1,06 s) y un punto central blanco con anillo cedar, centrado
/// en (195, 300) del lienzo de 390×844.
class PermissionRadar extends StatelessWidget {
  const PermissionRadar({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 195,
      top: 300,
      width: 0,
      height: 0,
      child: IgnorePointer(
        child: SceneClockHost(
          builder: (context, clock) => ClockBuilder(
            clock: clock,
            builder: (context, t) => CustomPaint(
              painter: _RadarPainter(
                [
                  for (final d in const [0.0, 1060.0, 2120.0])
                    loopPhase(t, d, 3200),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter(this.phases);

  final List<double?> phases;

  @override
  void paint(Canvas canvas, Size size) {
    for (final ph in phases) {
      if (ph == null) continue;
      final p = Curves.easeOut.transform(ph);
      final scale = .1 + .9 * p;
      canvas.drawCircle(
        Offset.zero,
        120 * scale - .75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0x664C583E).withValues(alpha: .4 * (1 - p)),
      );
    }
    // Punto central: sombra 1 px, fondo blanco y anillo interior de 5 px.
    canvas.drawCircle(
      Offset.zero,
      10.5,
      Paint()..color = const Color(0x1F2C3424),
    );
    canvas.drawCircle(Offset.zero, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset.zero,
      7.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = YgColors.cedar,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) {
    for (var i = 0; i < phases.length; i++) {
      if (old.phases[i] != phases[i]) return true;
    }
    return false;
  }
}
