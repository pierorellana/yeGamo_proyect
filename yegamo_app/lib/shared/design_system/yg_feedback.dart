import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'yg_controls.dart';
import 'yg_icon.dart';
import 'yg_motion.dart';
import 'yg_surfaces.dart';
import 'yg_tokens.dart';

enum YgBadgeTone { moss, cypress, olive }

/// Insignia de línea (`.lb`): número de línea en un rectángulo de radio 6.
class YgLineBadge extends StatelessWidget {
  const YgLineBadge(this.label, {super.key, this.tone = YgBadgeTone.moss});

  final String label;
  final YgBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      YgBadgeTone.moss => YgColors.moss,
      YgBadgeTone.cypress => YgColors.cypress,
      YgBadgeTone.olive => YgColors.olive,
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
          height: 1.1,
        ),
      ),
    );
  }
}

/// «En vivo»: punto sólido con pulso (`.live`). Solo debe mostrarse con
/// fuente autorizada y timestamp reciente.
class YgLiveLabel extends StatelessWidget {
  const YgLiveLabel({super.key, this.text = 'En vivo'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        YgLoop(
          duration: const Duration(milliseconds: 1600),
          builder: (context, t, _) => Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: YgColors.cypress,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: YgColors.cypress.withValues(alpha: .5 * (1 - t)),
                  spreadRadius: 6 * t,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: YgColors.cypress,
          ),
        ),
      ],
    );
  }
}

/// «Estimado»: círculo punteado (`.est`). Nunca depende solo del color.
class YgEstLabel extends StatelessWidget {
  const YgEstLabel({super.key, this.text = 'Estimado'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 9,
          height: 9,
          child: CustomPaint(painter: _DashedCirclePainter()),
        ),
        const SizedBox(width: 6),
        Text(text, style: _labelStyle),
      ],
    );
  }
}

/// «Programado»: cuadro de borde sólido (`.sched`).
class YgSchedLabel extends StatelessWidget {
  const YgSchedLabel({super.key, this.text = 'Programado'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: YgColors.cedar, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: _labelStyle),
      ],
    );
  }
}

const _labelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: YgColors.text3,
);

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  Color get color => YgColors.cedar;
  double get width => 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.shortestSide - width) / 2;
    final c = size.center(Offset.zero);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    const n = 8;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a,
        math.pi / n,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => false;
}

/// Pastilla de línea en vivo (`.pill-live`).
class YgPillLive extends StatelessWidget {
  const YgPillLive(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 24),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: YgColors.cypress,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Positioned(
          top: -3,
          right: -3,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: YgColors.aloe,
              shape: BoxShape.circle,
              border: Border.all(color: YgColors.moss, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pastilla de línea estimada (`.pill-est`): blanca, borde punteado.
class YgPillEst extends StatelessWidget {
  const YgPillEst(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: YgColors.cedar,
        radius: 12,
        strokeWidth: 1.5,
      ),
      child: Container(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: YgColors.text2,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(strokeWidth / 2),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

/// Rectángulo con borde punteado reutilizable (bus estimado, ilustraciones).
class YgDashedBox extends StatelessWidget {
  const YgDashedBox({
    super.key,
    required this.child,
    this.color = YgColors.cedar,
    this.radius = 12,
    this.background = Colors.white,
    this.padding,
    this.strokeWidth = 1.5,
    this.minWidth = 0,
    this.minHeight = 0,
  });

  final Widget child;
  final Color color;
  final double radius;
  final Color background;
  final EdgeInsetsGeometry? padding;
  final double strokeWidth;
  final double minWidth;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
        padding: padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

enum YgBannerTone { warn, off, plain }

/// Banner contextual (`.banner`): recuperable y no modal.
class YgBanner extends StatelessWidget {
  const YgBanner({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.tone = YgBannerTone.warn,
    this.actionLabel,
    this.onAction,
    this.floating = false,
  });

  final String title;
  final String? message;
  final String? icon;
  final YgBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Variante `.banner.top`: translúcida con sombra, bajo la barra superior.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final (bg, border) = floating
        ? (Colors.white.withValues(alpha: .98), YgColors.moss.withValues(alpha: .12))
        : switch (tone) {
            YgBannerTone.warn => (const Color(0xFFF1F2EA), const Color(0xFFD6D9C9)),
            YgBannerTone.off => (const Color(0xFFF1F2EE), YgColors.borderStrong),
            YgBannerTone.plain => (Colors.white, YgColors.border),
          };
    final body = Container(
      padding: floating
          ? const EdgeInsets.fromLTRB(12, 10, 10, 10)
          : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(floating ? 18 : 16),
        border: Border.all(color: border, width: floating ? .5 : 1),
        boxShadow: floating
            ? const [
                BoxShadow(
                  color: Color(0x1F2C3424),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            YgTile(icon: icon!, size: 32, radius: 9),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: YgText.sub.copyWith(fontSize: 14),
                  maxLines: floating ? 1 : null,
                  overflow: floating ? TextOverflow.ellipsis : null,
                ),
                if (message != null)
                  Text(
                    message!,
                    style: YgText.meta,
                    maxLines: floating ? 1 : null,
                    overflow: floating ? TextOverflow.ellipsis : null,
                  ),
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 12),
            YgButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: YgButtonVariant.secondary,
              size: YgButtonSize.sm,
            ),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: message == null ? title : '$title. $message',
      child: floating ? YgEnter(kind: YgEnterKind.up, child: body) : body,
    );
  }
}

/// Aviso temporal (`.toast`): píldora con check, 2,8 s, entrada 3D.
abstract final class YgToast {
  static OverlayEntry? _current;

  static void show(BuildContext context, String text) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _current?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        text: text,
        reduce: YgMotionScope.reduced(context),
        onDone: () {
          if (_current == entry) _current = null;
          entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.text,
    required this.onDone,
    required this.reduce,
  });

  final String text;
  final VoidCallback onDone;
  final bool reduce;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: YgSize.floatY,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = _c.value;
              // 0–12 % entra, 12–86 % reposa, 86–100 % sale.
              double o, dy, rx;
              if (t < .12) {
                final k = Curves.easeOut.transform(t / .12);
                o = k;
                dy = -16 * (1 - k);
                rx = -70 * (1 - k);
              } else if (t < .86) {
                o = 1;
                dy = 0;
                rx = 0;
              } else {
                final k = (t - .86) / .14;
                o = 1 - k;
                dy = -12 * k;
                rx = 30 * k;
              }
              if (widget.reduce) rx = 0;
              return Opacity(
                opacity: o.clamp(0.0, 1.0),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, -1 / 400)
                    ..multiply(Matrix4.translationValues(0.0, dy, 0))
                    ..rotateX(rx * math.pi / 180),
                  child: child,
                ),
              );
            },
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                liveRegion: true,
                label: widget.text,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: YgColors.moss.withValues(alpha: .12),
                      width: .5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x242C3424),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: YgColors.cypress,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: YgIcon(
                            YgIcons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.text,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: YgColors.text,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum YgCompKind { walk, wait, bus, metro, transfer, margin }

class YgCompSegment {
  const YgCompSegment(this.kind, this.flex);

  final YgCompKind kind;
  final double flex;
}

/// Barra de composición del tiempo (`.comp`): caminata punteada, espera
/// rayada, bus, metro, transbordo y margen.
class YgCompBar extends StatelessWidget {
  const YgCompBar({super.key, required this.segments, this.height = 6});

  final List<YgCompSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              flex: math.max(1, (segments[i].flex * 100).round()),
              child: CustomPaint(
                painter: _CompPainter(segments[i].kind),
                child: const SizedBox(
                  height: double.infinity,
                  width: double.infinity,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompPainter extends CustomPainter {
  const _CompPainter(this.kind);

  final YgCompKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.save();
    canvas.clipRRect(rr);
    switch (kind) {
      case YgCompKind.walk:
        canvas.drawRect(Offset.zero & size, Paint()..color = YgColors.track);
        final p = Paint()..color = YgColors.olive;
        for (var x = 1.5; x < size.width; x += 5) {
          canvas.drawCircle(Offset(x, size.height / 2), 1.1, p);
        }
      case YgCompKind.wait:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFFE3E3DA),
        );
        final p = Paint()
          ..color = YgColors.cedar
          ..strokeWidth = 1.5;
        for (var x = -size.height; x < size.width + size.height; x += 5.5) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
        }
      case YgCompKind.bus:
        canvas.drawRect(Offset.zero & size, Paint()..color = YgColors.cypress);
      case YgCompKind.metro:
        canvas.drawRect(Offset.zero & size, Paint()..color = YgColors.cypress);
        final p = Paint()..color = YgColors.olive;
        for (var x = 8.0; x < size.width; x += 10) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), p);
        }
      case YgCompKind.transfer:
        canvas.drawRect(Offset.zero & size, Paint()..color = YgColors.moss);
      case YgCompKind.margin:
        canvas.restore();
        canvas.drawRRect(
          rr.deflate(.75),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = YgColors.muted,
        );
        return;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompPainter old) => old.kind != kind;
}

/// Medidor circular de fiabilidad (`.gauge`, 56 px).
class YgGauge extends StatelessWidget {
  const YgGauge({
    super.key,
    required this.score,
    this.size = 56,
    this.color,
  });

  final int score;
  final double size;
  final Color? color;

  Color get _color =>
      color ??
      (score >= 80
          ? YgColors.cypress
          : (score >= 60 ? YgColors.cedar : YgColors.clay));

  @override
  Widget build(BuildContext context) {
    final reduce = YgMotionScope.reduced(context);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score.clamp(0, 100) / 100),
        duration: reduce ? YgMotion.reduced : const Duration(milliseconds: 1100),
        curve: const Cubic(.3, 1, .4, 1),
        builder: (context, v, _) => CustomPaint(
          painter: _ArcPainter(
            progress: v,
            color: _color,
            width: 5 * size / 56,
          ),
          child: Center(
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: 17 * size / 56,
                fontWeight: FontWeight.w600,
                color: YgColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anillo de cuenta atrás (`.cnt`, 64 px): minutos para salir.
class YgCountdownRing extends StatelessWidget {
  const YgCountdownRing({
    super.key,
    required this.value,
    required this.progress,
    this.unit = 'min',
    this.size = 64,
  });

  final String value;
  final double progress;
  final String unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 600),
        builder: (context, v, _) => CustomPaint(
          painter: _ArcPainter(progress: v, color: YgColors.cypress, width: 4),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: YgColors.moss,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: YgColors.text3,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.width,
  });

  final double progress;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - width) / 2,
    );
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = YgColors.track,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress || old.color != color || old.width != width;
}

/// Spinner del prototipo (`.ls .sp`, `.ld-ring`): anillo con cabeza cypress.
class YgSpinner extends StatelessWidget {
  const YgSpinner({super.key, this.size = 20, this.width = 2});

  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: YgLoop(
        duration: const Duration(milliseconds: 800),
        builder: (context, t, _) => Transform.rotate(
          angle: t * 2 * math.pi,
          child: CustomPaint(painter: _SpinnerPainter(width)),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter(this.width);

  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 1 - width / 2,
    );
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = YgColors.borderStrong,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi / 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = YgColors.cypress,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter old) => old.width != width;
}
