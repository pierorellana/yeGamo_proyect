import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/yg_motion.dart';

/// Flotación 3D de ilustraciones (`efloat`/`ifloat`): 5 s, perspectiva 400,
/// rotateX 8°, rotateY −8° y elevación. Se detiene con movimiento reducido.
class YgFloat extends StatelessWidget {
  const YgFloat({super.key, required this.child, this.lift = 4});

  final Widget child;

  /// Elevación máxima en px lógicos (`translateY`).
  final double lift;

  @override
  Widget build(BuildContext context) {
    return YgLoop(
      duration: const Duration(seconds: 5),
      child: child,
      builder: (context, t, child) {
        final e = (1 - math.cos(t * 2 * math.pi)) / 2;
        final m = Matrix4.identity()
          ..setEntry(3, 2, -1 / 400)
          ..rotateX(8 * math.pi / 180 * e)
          ..rotateY(-8 * math.pi / 180 * e);
        return Transform.translate(
          offset: Offset(0, -lift * e),
          child: Transform(
            alignment: Alignment.center,
            transform: m,
            child: child,
          ),
        );
      },
    );
  }
}
