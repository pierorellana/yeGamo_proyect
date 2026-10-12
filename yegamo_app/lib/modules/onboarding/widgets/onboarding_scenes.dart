import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../shared/design_system/yg_components.dart';
import 'entry_frame.dart';
import 'onboarding_parts.dart';
import 'scene_clock.dart';

/// Copy fijo del producto para las tres páginas (Main.dc.html 713, 734, 759).
class ObSlideCopy {
  const ObSlideCopy(this.title, this.body);

  final String title;
  final String body;
}

const obSlides = <ObSlideCopy>[
  ObSlideCopy(
    'Sabe cuándo salir',
    'Dinos a qué hora debes llegar. yeGamo calcula tu salida, qué tomar y cuándo llegas.',
  ),
  ObSlideCopy(
    'Contigo de puerta a puerta',
    'Sigue cada tramo en el mapa y recibe un aviso antes de tu parada.',
  ),
  ObSlideCopy(
    'Rangos honestos, no promesas',
    'Siempre verás una ventana de llegada y si el dato es en vivo o estimado.',
  ),
];

/// Una página del carril (`.ob-pg`): ilustración de 390×416 a y=112 y texto a
/// y=548. Su reloj arranca cuando la página queda activa (`.ob-pg.on`).
class ObPage extends StatelessWidget {
  const ObPage({super.key, required this.index, required this.active});

  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final reduced = YgMotionScope.reduced(context);
    final copy = obSlides[index];
    return AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: reduced ? YgMotion.reduced : const Duration(milliseconds: 550),
      child: SceneClockHost(
        active: active,
        builder: (context, clock) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 112,
                width: 390,
                height: 416,
                child: ExcludeSemantics(
                  child: switch (index) {
                    0 => ObHeroFan(clock: clock),
                    1 => ObHeroRoute(clock: clock),
                    _ => ObHeroWindow(clock: clock),
                  },
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                top: 548,
                child: ClockBuilder(
                  clock: clock,
                  builder: (context, t) {
                    return Column(
                      children: [
                        _txtIn(
                          segP(t, 120, 600, YgMotion.easeOut),
                          Text(
                            copy.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.78,
                              color: YgColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _txtIn(
                          segP(t, 220, 600, YgMotion.easeOut),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text(
                              copy.body,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                letterSpacing: -.15,
                                color: YgColors.text3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _txtIn(double p, Widget child) => Opacity(
    opacity: p.clamp(0.0, 1.0),
    child: Transform.translate(offset: Offset(0, 12 * (1 - p)), child: child),
  );
}

// ───────────────────────── Página 1 · tarjetas en abanico ─────────────────

const _fanMapSvg =
    '<svg width="164" height="112" viewBox="0 0 164 112" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="164" height="112" rx="16" fill="#F3F5EF"/>'
    '<path d="M0 40 H164 M0 80 H164 M50 0 V112 M110 0 V112" stroke="#FFFFFF" stroke-width="7"/>'
    '<path d="M22 94 C58 94 54 56 86 52 C118 48 126 24 142 18" fill="none" stroke="#4C583E" stroke-width="4" stroke-linecap="round"/>'
    '<circle cx="22" cy="94" r="5.5" fill="#FFFFFF" stroke="#2C3424" stroke-width="3"/>'
    '<circle cx="142" cy="18" r="6" fill="#2C3424"/></svg>';

class ObHeroFan extends StatelessWidget {
  const ObHeroFan({super.key, required this.clock});

  final SceneClock clock;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ObBlob(clock: clock, left: 30, top: 36, size: 330, kind: 1),
        ObBlob(clock: clock, left: 176, top: 150, size: 220, kind: 2),
        ObBlob(clock: clock, left: -20, top: 120, size: 200, kind: 3),
        _Fan(clock: clock, rot: -14, dy: 0, delay: 140, child: _fanOne()),
        _Fan(clock: clock, rot: 14, dy: 0, delay: 200, child: _fanThree()),
        _Fan(clock: clock, rot: 0, dy: -8, delay: 0, child: _fanTwo()),
        ObFloatDot(
          clock: clock, x: 52, y: 64, icon: YgIcons.ubicacion,
          inDelay: 500, floatDelay: 1200,
        ),
        ObFloatDot(
          clock: clock, x: 336, y: 92, icon: YgIcons.bus, kind: ObDotKind.dark,
        ),
        ObFloatDot(
          clock: clock, x: 34, y: 316, icon: YgIcons.caminar,
          inDelay: 600, floatDelay: 2400,
        ),
        ObFloatDot(clock: clock, x: 352, y: 300, icon: YgIcons.campana),
        ObFloatDot(
          clock: clock, x: 100, y: 30, kind: ObDotKind.point,
          inDelay: 500, floatDelay: 1200,
        ),
        ObFloatDot(
          clock: clock, x: 300, y: 44, kind: ObDotKind.pointLight,
          inDelay: 600, floatDelay: 2400,
        ),
        ObFloatDot(
          clock: clock, x: 318, y: 380, kind: ObDotKind.point,
          inDelay: 500, floatDelay: 1200,
        ),
        ObFloatDot(clock: clock, x: 72, y: 388, kind: ObDotKind.pointLight),
      ],
    );
  }

  Widget _fanOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            YgLineBadge('14'),
            SizedBox(width: 8),
            YgLiveLabel(),
          ],
        ),
        const SizedBox(height: 16),
        Text('4 min', style: dispStyle(28)),
        const SizedBox(height: 4),
        const Text('Urdesa Central', style: obXs),
        const SizedBox(height: 12),
        const _FanRow(icon: YgIcons.bus, text: 'Próximo bus'),
      ],
    );
  }

  Widget _fanThree() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SvgPicture.string(_fanMapSvg, width: 164, height: 112),
        const SizedBox(height: 12),
        const Text(
          '34 min',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
            letterSpacing: -.13,
            color: YgColors.text,
          ),
        ),
        const SizedBox(height: 2),
        const Text('Casa → Trabajo', style: obXs),
      ],
    );
  }

  Widget _fanTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SAL A LAS', style: YgText.overline),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: YgColors.cypress,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const YgIcon(YgIcons.reloj, size: 17, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('07:42', style: dispStyle(48)),
        const SizedBox(height: 8),
        const Text.rich(
          TextSpan(
            style: obXs,
            children: [
              TextSpan(text: 'Llegas '),
              TextSpan(
                text: '08:14–08:20',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: YgColors.text,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const YgCompBar(
          segments: [
            YgCompSegment(YgCompKind.walk, 6),
            YgCompSegment(YgCompKind.wait, 3),
            YgCompSegment(YgCompKind.bus, 18),
            YgCompSegment(YgCompKind.walk, 4),
          ],
        ),
        const SizedBox(height: 8),
        const _FanRow(icon: YgIcons.escudo, text: 'Fiabilidad alta · 92%'),
        const Spacer(),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: YgColors.moss,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              YgIcon(YgIcons.campana, size: 14, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Avisarme 07:32',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.13,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FanRow extends StatelessWidget {
  const _FanRow({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          YgIcon(icon, size: 14, color: YgColors.cypress),
          const SizedBox(width: 8),
          Text(text, style: obXs),
        ],
      ),
    );
  }
}

class _Fan extends StatelessWidget {
  const _Fan({
    required this.clock,
    required this.rot,
    required this.dy,
    required this.delay,
    required this.child,
  });

  final SceneClock clock;
  final double rot;
  final double dy;
  final double delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 97,
      top: 72,
      width: 196,
      height: 264,
      child: ClockBuilder(
        clock: clock,
        builder: (context, t) {
          final p = segP(t, delay, 1000, const Cubic(.2, 1.1, .3, 1));
          final ty = lerpD(48, dy, p);
          final r = lerpD(0, rot, p) * 3.141592653589793 / 180;
          final s = lerpD(.9, 1, p);
          final m = Matrix4.translationValues(0, ty, 0)
            ..multiply(Matrix4.rotationZ(r))
            ..multiply(Matrix4.diagonal3Values(s, s, 1));
          return Opacity(
            opacity: p.clamp(0.0, 1.0),
            // transform-origin: 50% 135%
            child: Transform(
              alignment: const Alignment(0, 1.7),
              transform: m,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: obCardShadow,
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Página 2 · mini-mapa con ruta ──────────────────

Path _routePath() => Path()
  ..moveTo(64, 356)
  ..cubicTo(124, 344, 112, 262, 188, 236)
  ..cubicTo(262, 210, 300, 196, 300, 132)
  ..cubicTo(300, 96, 300, 76, 318, 58);

class ObHeroRoute extends StatefulWidget {
  const ObHeroRoute({super.key, required this.clock});

  final SceneClock clock;

  @override
  State<ObHeroRoute> createState() => _ObHeroRouteState();
}

class _ObHeroRouteState extends State<ObHeroRoute> {
  late final Path _path = _routePath();
  late final ui.PathMetric _metric = _path.computeMetrics().first;

  @override
  Widget build(BuildContext context) {
    final clock = widget.clock;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ObBlob(clock: clock, left: 60, top: 60, size: 280, kind: 1),
        Positioned.fill(
          child: ClockBuilder(
            clock: clock,
            builder: (context, t) => CustomPaint(
              painter: _RouteMapPainter(
                path: _path,
                draw: segP(t, 200, 1600, YgMotion.drawCurve),
              ),
            ),
          ),
        ),
        _bus(),
        _pin(clock, 64, 356, '1', false, 0),
        _pin(clock, 188, 236, '2', true, 750),
        _pin(clock, 318, 58, '3', false, 1300),
        _Card(
          clock: clock, left: 92, top: 350, delay: 300, grad: 1,
          icon: YgIcons.casa, title: 'Casa', sub: 'Sal 07:42 · 6 min a pie',
        ),
        _Card(
          clock: clock, left: 20, top: 150, delay: 850, grad: 2,
          icon: YgIcons.bus, title: 'Línea 14', sub: 'Sube 07:49 · 9 paradas',
        ),
        _Card(
          clock: clock, left: 112, top: 86, delay: 1400, grad: 3,
          icon: YgIcons.campana, title: 'Trabajo', sub: 'Te avisamos al bajar',
        ),
      ],
    );
  }

  Widget _bus() {
    return ClockBuilder(
      clock: widget.clock,
      builder: (context, t) {
        final ph = loopPhase(t, 1600, 6000);
        if (ph == null) return const SizedBox.shrink();
        final pct = ph * 100;
        const ease = Cubic(.45, 0, .55, 1);
        final dist = pct >= 88 ? 1.0 : ease.transform(pct / 88);
        final opacity = pct < 6
            ? ease.transform(pct / 6)
            : (pct < 88 ? 1.0 : 1 - ease.transform((pct - 88) / 12));
        final tan = _metric.getTangentForOffset(_metric.length * dist);
        final pos = tan?.position ?? const Offset(64, 356);
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: FractionalTranslation(
            translation: const Offset(-.5, -.5),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                height: 24,
                constraints: const BoxConstraints(minWidth: 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: YgColors.cypress,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.white, spreadRadius: 2),
                    BoxShadow(
                      color: Color(0x4D2C3424),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Text(
                  '14',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pin(
    SceneClock clock,
    double x,
    double y,
    String label,
    bool cypress,
    double delay,
  ) {
    return Positioned(
      left: x - 15,
      top: y - 15,
      width: 30,
      height: 30,
      child: ClockBuilder(
        clock: clock,
        builder: (context, t) {
          final p = segP(t, delay, 550, const Cubic(.34, 1.7, .5, 1));
          final s = lerpD(.4, 1, p);
          return Opacity(
            opacity: p.clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(0, -14 * (1 - p), 0)
                ..multiply(Matrix4.diagonal3Values(s, s, 1)),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cypress ? YgColors.cypress : YgColors.moss,
                  boxShadow: const [
                    BoxShadow(color: Colors.white, spreadRadius: 3),
                    BoxShadow(
                      color: Color(0x472C3424),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.clock,
    required this.left,
    required this.top,
    required this.delay,
    required this.grad,
    required this.icon,
    required this.title,
    required this.sub,
  });

  final SceneClock clock;
  final double left;
  final double top;
  final double delay;
  final int grad;
  final String icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final (c1, c2, fg) = switch (grad) {
      1 => (YgColors.cedar, YgColors.cypress, Colors.white),
      2 => (YgColors.olive, YgColors.moss, Colors.white),
      _ => (YgColors.aloe, YgColors.cedar, YgColors.moss),
    };
    return Positioned(
      left: left,
      top: top,
      child: ClockBuilder(
        clock: clock,
        builder: (context, t) {
          final p = segP(t, delay, 600, YgMotion.easeOut);
          final s = lerpD(.94, 1, p);
          return Opacity(
            opacity: p.clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(0, 10 * (1 - p), 0)
                ..multiply(Matrix4.diagonal3Values(s, s, 1)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0D2C3424), spreadRadius: 1),
                      BoxShadow(
                        color: Color(0x1F2C3424),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: const Alignment(-.906, -1.079),
                            end: const Alignment(.906, 1.079),
                            colors: [c1, c2],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: YgIcon(icon, size: 18, color: fg),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.13,
                                color: YgColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sub,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                letterSpacing: -.11,
                                color: YgColors.text3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  const _RouteMapPainter({required this.path, required this.draw});

  final Path path;
  final double draw;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    final major = Paint()
      ..color = const Color(0xFFE6E9E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    for (final l in const [
      [-10.0, 300.0, 400.0, 236.0],
      [-10.0, 150.0, 400.0, 104.0],
      [96.0, -10.0, 150.0, 430.0],
      [248.0, -10.0, 268.0, 430.0],
    ]) {
      canvas.drawLine(Offset(l[0], l[1]), Offset(l[2], l[3]), major);
    }
    final minor = Paint()
      ..color = const Color(0xFFEEF0EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    for (final l in const [
      [-10.0, 380.0, 400.0, 320.0],
      [-10.0, 60.0, 400.0, 24.0],
      [30.0, -10.0, 60.0, 430.0],
      [190.0, -10.0, 210.0, 430.0],
      [340.0, -10.0, 350.0, 430.0],
    ]) {
      canvas.drawLine(Offset(l[0], l[1]), Offset(l[2], l[3]), minor);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (draw > 0) {
      final b = path.getBounds();
      canvas.drawPath(
        partialPath(path, draw),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          // ygObG: (0,1) → (1,0) sobre el bounding box.
          ..shader = ui.Gradient.linear(
            b.bottomLeft,
            b.topRight,
            const [YgColors.cedar, YgColors.cypress, YgColors.moss],
            const [0, .45, 1],
          ),
      );
    }
    // mask-image: radial-gradient(closest-side, #000 55%, transparent 100%)
    final c = rect.center;
    final k = (size.height / 2) / (size.width / 2);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          c,
          size.width / 2,
          const [Colors.black, Colors.black, Color(0x00000000)],
          const [0, .55, 1],
          TileMode.clamp,
          (Matrix4.translationValues(c.dx, c.dy, 0)
                ..multiply(Matrix4.diagonal3Values(1, k, 1))
                ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0)))
              .storage,
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RouteMapPainter old) => old.draw != draw;
}

// ───────────────────────── Página 3 · ventana de llegada ──────────────────

class ObHeroWindow extends StatelessWidget {
  const ObHeroWindow({super.key, required this.clock});

  final SceneClock clock;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ObBlob(clock: clock, left: 20, top: 20, size: 350, kind: 1),
        ObBlob(clock: clock, left: 220, top: 240, size: 200, kind: 3),
        Positioned(
          left: 45,
          top: 44,
          width: 300,
          height: 328,
          child: ClockBuilder(
            clock: clock,
            builder: (context, t) {
              final p = segP(t, 0, 900, const Cubic(.2, 1, .3, 1));
              final s = lerpD(.96, 1, p);
              return Opacity(
                opacity: p.clamp(0.0, 1.0),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.translationValues(0, 28 * (1 - p), 0)
                    ..multiply(Matrix4.diagonal3Values(s, s, 1)),
                  child: _card(t),
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 28,
          top: 20,
          child: ClockBuilder(
            clock: clock,
            builder: (context, t) {
              final p = segP(t, 1400, 700, const Cubic(.34, 1.6, .5, 1));
              final s = lerpD(.6, 1, p);
              final rot = lerpD(18, 5, p) * 3.141592653589793 / 180;
              return Opacity(
                opacity: p.clamp(0.0, 1.0),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationZ(rot)
                    ..multiply(Matrix4.diagonal3Values(s, s, 1)),
                  child: YgGlass(
                    radius: 18,
                    height: 36,
                    padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: YgColors.cypress,
                          ),
                          alignment: Alignment.center,
                          child: const YgIcon(
                            YgIcons.check,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Fiabilidad 92%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.12,
                            color: YgColors.moss,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        ObFloatDot(
          clock: clock, x: 30, y: 250, icon: YgIcons.escudo,
          inDelay: 600, floatDelay: 2400,
        ),
        ObFloatDot(
          clock: clock, x: 360, y: 200, kind: ObDotKind.point,
          inDelay: 500, floatDelay: 1200,
        ),
        ObFloatDot(clock: clock, x: 60, y: 24, kind: ObDotKind.pointLight),
      ],
    );
  }

  Widget _card(double t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(color: Color(0x0D2C3424), spreadRadius: 1),
          BoxShadow(color: Color(0x0A2C3424), blurRadius: 4, offset: Offset(0, 2)),
          BoxShadow(
            color: Color(0x1F2C3424),
            blurRadius: 60,
            offset: Offset(0, 30),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VENTANA DE LLEGADA', style: YgText.overline),
          const SizedBox(height: 8),
          Text('08:14 – 08:20', style: dispStyle(28)),
          const SizedBox(height: 12),
          SizedBox(
            height: 112,
            child: Transform.translate(
              offset: const Offset(-4, 0),
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 268,
                maxWidth: 268,
                child: CustomPaint(
                  size: const Size(268, 112),
                  painter: _CurvePainter(
                    draw: segP(t, 300, 1500, YgMotion.drawCurve),
                    band: segP(t, 1100, 800, const Cubic(.34, 1.4, .5, 1)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _row(const YgPillLive('14'), 'En vivo', 'Posición GPS reciente', true),
          _row(const YgPillEst('≈14'), 'Estimado', 'Por horario, nunca como GPS', false),
        ],
      ),
    );
  }

  Widget _row(Widget pill, String title, String sub, bool first) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: YgColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(height: 24, child: pill),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.13,
                    color: YgColors.text,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    letterSpacing: -.11,
                    color: YgColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  const _CurvePainter({required this.draw, required this.band});

  final double draw;
  final double band;

  @override
  void paint(Canvas canvas, Size size) {
    // Banda de margen (`.lnb`, bandIn: scaleX 0→1 + opacidad).
    if (band > 0) {
      canvas.save();
      canvas.translate(127, 56);
      canvas.scale(band.clamp(0.0, 2.0), 1);
      canvas.translate(-127, -56);
      final rr = RRect.fromRectAndRadius(
        const Rect.fromLTWH(104, 14, 46, 84),
        const Radius.circular(10),
      );
      final a = band.clamp(0.0, 1.0);
      canvas.drawRRect(
        rr,
        Paint()..color = const Color(0x144C583E).withValues(alpha: .08 * a),
      );
      drawDashed(
        canvas,
        Path()..addRRect(rr),
        Paint()
          ..color = YgColors.cypress.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
        3,
        3,
      );
      canvas.restore();
    }
    final fill = Path()
      ..moveTo(8, 98)
      ..cubicTo(62, 98, 92, 26, 127, 26)
      ..cubicTo(162, 26, 192, 98, 246, 98)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 26),
          const Offset(0, 98),
          const [Color(0x38768064), Color(0x00768064)],
        ),
    );
    final line = Path()
      ..moveTo(8, 98)
      ..cubicTo(62, 98, 92, 26, 127, 26)
      ..cubicTo(162, 26, 192, 98, 246, 98);
    if (draw > 0) {
      canvas.drawPath(
        partialPath(line, draw),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = ui.Gradient.linear(
            const Offset(8, 0),
            const Offset(246, 0),
            const [YgColors.aloe, YgColors.cypress, YgColors.cedar],
            const [0, .5, 1],
          ),
      );
    }
    drawDashed(
      canvas,
      Path()
        ..moveTo(212, 8)
        ..lineTo(212, 98),
      Paint()
        ..color = YgColors.moss
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
      3,
      4,
    );
    canvas.drawLine(
      const Offset(4, 98),
      const Offset(264, 98),
      Paint()
        ..color = YgColors.borderStrong
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.draw != draw || old.band != band;
}
