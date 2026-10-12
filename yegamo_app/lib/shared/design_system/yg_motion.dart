import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'yg_tokens.dart';

/// Preferencia de movimiento reducido: apaga cámara 3D, vuelos y pulsos y deja
/// fundidos de 120 ms (ver LEEME-animaciones del prototipo).
class YgMotionScope extends InheritedWidget {
  const YgMotionScope({
    super.key,
    required this.reduceMotion,
    required super.child,
  });

  final bool reduceMotion;

  static bool reduced(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<YgMotionScope>();
    return (scope?.reduceMotion ?? false) ||
        MediaQuery.maybeOf(context)?.disableAnimations == true;
  }

  @override
  bool updateShouldNotify(YgMotionScope oldWidget) =>
      reduceMotion != oldWidget.reduceMotion;
}

enum YgEnterKind { rise, push, back, up, down, fade, hero, pop }

/// Entrada animada equivalente a los keyframes `rise`, `inPush`, `inBack`,
/// `inUp`, `inDown`, `inFade`, `hero` y `nbIn` del prototipo.
class YgEnter extends StatefulWidget {
  const YgEnter({
    super.key,
    required this.child,
    this.kind = YgEnterKind.rise,
    this.delay = Duration.zero,
    this.duration,
    this.curve = YgMotion.easeOut,
  });

  final Widget child;
  final YgEnterKind kind;
  final Duration delay;
  final Duration? duration;
  final Curve curve;

  @override
  State<YgEnter> createState() => _YgEnterState();
}

class _YgEnterState extends State<YgEnter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  Duration get _dur =>
      widget.duration ??
      switch (widget.kind) {
        YgEnterKind.rise => const Duration(milliseconds: 500),
        YgEnterKind.push || YgEnterKind.back => const Duration(milliseconds: 500),
        YgEnterKind.up => const Duration(milliseconds: 550),
        YgEnterKind.down => const Duration(milliseconds: 700),
        YgEnterKind.fade => const Duration(milliseconds: 400),
        YgEnterKind.hero => const Duration(milliseconds: 800),
        YgEnterKind.pop => const Duration(milliseconds: 600),
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = YgMotionScope.reduced(context);
    final delay = reduce ? Duration.zero : widget.delay;
    final dur = reduce ? YgMotion.reduced : _dur;
    // El retardo se integra en la curva (Interval) para no dejar timers.
    _c.duration = dur + delay;
    _delayFraction = delay.inMicroseconds / (dur + delay).inMicroseconds;
    _c.forward();
  }

  double _delayFraction = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Matrix4 _matrix(double t, double persp) {
    // t: 1 = estado inicial (keyframe `from`), 0 = reposo.
    final m = Matrix4.identity()..setEntry(3, 2, -1 / persp);
    switch (widget.kind) {
      case YgEnterKind.rise:
        m
          ..multiply(Matrix4.translationValues(0.0, 14 * t, 0))
          ..rotateX(-16 * math.pi / 180 * t);
      case YgEnterKind.push:
        m
          ..multiply(Matrix4.translationValues(40.0 * t, 0.0, 0))
          ..rotateY(-10 * math.pi / 180 * t);
      case YgEnterKind.back:
        m
          ..multiply(Matrix4.translationValues(-40.0 * t, 0.0, 0))
          ..rotateY(10 * math.pi / 180 * t);
      case YgEnterKind.up:
        m
          ..multiply(Matrix4.translationValues(0.0, 56 * t, 0))
          ..rotateX(8 * math.pi / 180 * t);
      case YgEnterKind.down:
        m.multiply(Matrix4.translationValues(0.0, -40 * t, 0));
      case YgEnterKind.hero:
        m
          ..multiply(Matrix4.translationValues(0.0, 16 * t, 0))
          ..rotateX(24 * math.pi / 180 * t);
      case YgEnterKind.pop:
        final s = 1 - .04 * t;
        m
          ..multiply(Matrix4.translationValues(0.0, 28 * t, 0))
          ..multiply(Matrix4.diagonal3Values(s, s, 1));
      case YgEnterKind.fade:
        break;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = YgMotionScope.reduced(context);
    final persp = switch (widget.kind) {
      YgEnterKind.rise || YgEnterKind.hero => 800.0,
      _ => 1200.0,
    };
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final raw = ((_c.value - _delayFraction) / (1 - _delayFraction))
            .clamp(0.0, 1.0);
        final v = widget.curve.transform(raw);
        final t = 1 - v;
        final opacity = widget.kind == YgEnterKind.pop && v > 0
            ? v.clamp(0.0, 1.0)
            : v.clamp(0.0, 1.0);
        if (reduce || widget.kind == YgEnterKind.fade) {
          return Opacity(opacity: opacity, child: child);
        }
        return Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.center,
            transform: _matrix(t, persp),
            child: child,
          ),
        );
      },
    );
  }
}

/// Aplica `YgEnter.rise` escalonado (50 ms entre hijos, tope 300 ms) como la
/// clase `.stg` del prototipo.
class YgStagger extends StatelessWidget {
  const YgStagger({
    super.key,
    required this.children,
    this.spacing = 0,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0 && spacing > 0) SizedBox(height: spacing),
          YgEnter(
            delay: Duration(milliseconds: math.min(i, 6) * 50),
            child: children[i],
          ),
        ],
      ],
    );
  }
}

/// Retardo de listas para usar con `YgEnter` en `ListView.builder`.
Duration ygStaggerDelay(int index) =>
    Duration(milliseconds: math.min(index, 6) * 50);

/// Pulsación con escala .96 y curva de toque (`cubic-bezier(.34,1.56,.64,1)`).
class YgPressable extends StatefulWidget {
  const YgPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.behavior = HitTestBehavior.opaque,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final HitTestBehavior behavior;
  final bool enabled;

  @override
  State<YgPressable> createState() => _YgPressableState();
}

class _YgPressableState extends State<YgPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    final reduce = YgMotionScope.reduced(context);
    return Semantics(
      button: true,
      enabled: active,
      label: widget.semanticLabel,
      container: widget.semanticLabel != null,
      onTap: active ? widget.onTap : null,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: active ? (_) => _set(true) : null,
        onTapUp: active ? (_) => _set(false) : null,
        onTapCancel: active ? () => _set(false) : null,
        onTap: active ? widget.onTap : null,
        onLongPress: active ? widget.onLongPress : null,
        child: AnimatedScale(
          scale: _down && !reduce ? .96 : 1,
          duration: reduce ? YgMotion.reduced : YgMotion.tap,
          curve: YgMotion.tapCurve,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Animación continua (pulso, giro, flotación) que se detiene con
/// movimiento reducido para no bloquear `pumpAndSettle` ni distraer.
class YgLoop extends StatefulWidget {
  const YgLoop({
    super.key,
    required this.duration,
    required this.builder,
    this.reverse = false,
    this.delay = Duration.zero,
    this.child,
  });

  final Duration duration;
  final bool reverse;
  final Duration delay;
  final Widget? child;
  final Widget Function(BuildContext context, double t, Widget? child) builder;

  @override
  State<YgLoop> createState() => _YgLoopState();
}

class _YgLoopState extends State<YgLoop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (YgMotionScope.reduced(context)) return;
    _c.repeat(reverse: widget.reverse);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => widget.builder(context, _c.value, child),
    );
  }
}
