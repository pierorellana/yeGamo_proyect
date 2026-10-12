import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';

const _iosBlue = Color(0xFF007AFF);

/// 21-diálogo-ubicación: alerta nativa estilo iOS (270 px, desenfoque, botones
/// azules) que precede a la solicitud real del permiso. Cubre toda la
/// pantalla con el velo `.alert-bg`; el cuadro se centra en el lienzo de 844.
class IosLocationDialog extends StatelessWidget {
  const IosLocationDialog({
    super.key,
    required this.onOnce,
    required this.onAllow,
    required this.onDeny,
  });

  final VoidCallback onOnce;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final reduced = YgMotionScope.reduced(context);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Permiso de ubicación',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: reduced ? YgMotion.reduced : const Duration(milliseconds: 250),
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: ColoredBox(
          color: const Color(0x471E2419),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: reduced
                  ? YgMotion.reduced
                  : const Duration(milliseconds: 380),
              curve: const Cubic(.34, 1.4, .5, 1),
              builder: (context, v, child) => Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: reduced ? 1 : 1.15 - .15 * v,
                  child: child,
                ),
              ),
              child: _box(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _box() {
    return SizedBox(
      width: 270,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: ColoredBox(
            color: const Color(0xF5F6F6F4),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.black),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Text(
                      '¿Permitir que “yeGamo” use tu ubicación?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.34,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      'Se usa para encontrar paradas cercanas y planificar viajes desde tu posición.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF3C3C43),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        height: 104,
                        width: double.infinity,
                        child: CustomPaint(painter: _AlertMapPainter()),
                      ),
                    ),
                  ),
                  _AlertButton(
                    key: const ValueKey('permission_dialog_once'),
                    label: 'Permitir una vez',
                    onTap: onOnce,
                  ),
                  _AlertButton(
                    key: const ValueKey('permission_dialog_allow'),
                    label: 'Permitir al usar la app',
                    bold: true,
                    onTap: onAllow,
                  ),
                  _AlertButton(
                    key: const ValueKey('permission_dialog_deny'),
                    label: 'No permitir',
                    onTap: onDeny,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertButton extends StatelessWidget {
  const _AlertButton({
    super.key,
    required this.label,
    required this.onTap,
    this.bold = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0x4D3C3C43), width: .5),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              color: _iosBlue,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.alert-map` (override de la línea 650): cuadrícula suave, dos calles
/// blancas y el punto azul de ubicación con halo.
class _AlertMapPainter extends CustomPainter {
  const _AlertMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFFECEEE8));
    // repeating-linear-gradient(0deg, #ECEEE8 0 18px, #E3E6DE 18px 19px)
    final line = Paint()..color = const Color(0xFFE3E6DE);
    for (var y = size.height - 18; y > -1; y -= 19) {
      canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 1), line);
    }
    _band(canvas, rect, 20, .60, .63);
    _band(canvas, rect, 115, .46, .50);
    final c = Offset(size.width / 2, size.height * .52);
    canvas.drawCircle(c, 30, Paint()..color = const Color(0x29007AFF));
    canvas.drawCircle(c, 8.5, Paint()..color = Colors.white);
    canvas.drawCircle(c, 6, Paint()..color = const Color(0xF2007AFF));
  }

  /// `linear-gradient(<deg>, transparent a, #fff a, #fff b, transparent b)`.
  void _band(Canvas canvas, Rect r, double deg, double a, double b) {
    final rad = deg * math.pi / 180;
    final dx = math.sin(rad);
    final dy = -math.cos(rad);
    final len = (r.width * dx).abs() + (r.height * dy).abs();
    final c = r.center;
    final half = Offset(dx * len / 2, dy * len / 2);
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          c - half,
          c + half,
          const [
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Colors.white,
            Colors.white,
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
          [0, a, a, b, b, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_AlertMapPainter old) => false;
}
