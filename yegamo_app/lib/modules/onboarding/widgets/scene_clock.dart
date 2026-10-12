import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../shared/design_system/yg_motion.dart';

/// Valor del reloj de escena que indica «animación terminada / estática»
/// (movimiento reducido o página inactiva).
const double kSceneDone = 1e9;

/// Reloj de una escena en milisegundos desde que arrancó. Todos los
/// keyframes del prototipo (`animation-delay` + duración) se evalúan contra
/// este reloj, igual que el navegador evalúa las animaciones CSS de una
/// página al recibir la clase `.on`.
class SceneClock extends ValueNotifier<double> {
  SceneClock() : super(kSceneDone);

  bool get isStatic => value >= kSceneDone / 2;
}

/// Progreso 0–1 (con curva) de una animación `delay`/`dur` en ms con
/// `fill-mode: both`: antes del retardo queda en `from`, después en `to`.
double segP(
  double t,
  double delay,
  double dur, [
  Curve curve = Curves.linear,
]) {
  if (t >= kSceneDone / 2) return 1;
  final x = ((t - delay) / dur).clamp(0.0, 1.0);
  return curve.transform(x);
}

/// Fase 0–1 de una animación infinita que arranca tras `delay`; `null` si
/// aún no empezó o si la escena es estática (movimiento reducido).
double? loopPhase(double t, double delay, double period) {
  if (t >= kSceneDone / 2 || t < delay) return null;
  return ((t - delay) % period) / period;
}

/// Interpolación lineal.
double lerpD(double a, double b, double t) => a + (b - a) * t;

/// Posee el `Ticker` de una escena y reinicia el reloj cada vez que
/// [active] pasa a verdadero. Con movimiento reducido el reloj queda en
/// [kSceneDone] y no hay bucles.
class SceneClockHost extends StatefulWidget {
  const SceneClockHost({
    super.key,
    required this.builder,
    this.active = true,
  });

  final bool active;
  final Widget Function(BuildContext context, SceneClock clock) builder;

  @override
  State<SceneClockHost> createState() => _SceneClockHostState();
}

class _SceneClockHostState extends State<SceneClockHost>
    with SingleTickerProviderStateMixin {
  final SceneClock _clock = SceneClock();
  late final Ticker _ticker = createTicker(_onTick);
  bool _reduced = false;
  bool _initialised = false;

  void _onTick(Duration elapsed) {
    _clock.value = elapsed.inMicroseconds / 1000.0;
  }

  void _sync() {
    if (_ticker.isActive) _ticker.stop();
    if (widget.active && !_reduced) {
      _clock.value = 0;
      _ticker.start();
    } else {
      _clock.value = kSceneDone;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = YgMotionScope.reduced(context);
    if (!_initialised || reduced != _reduced) {
      _initialised = true;
      _reduced = reduced;
      _sync();
    }
  }

  @override
  void didUpdateWidget(SceneClockHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _clock);
}

/// Reconstruye [builder] en cada tic del reloj.
class ClockBuilder extends StatelessWidget {
  const ClockBuilder({super.key, required this.clock, required this.builder});

  final SceneClock clock;
  final Widget Function(BuildContext context, double t) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: clock,
      builder: (context, t, _) => builder(context, t),
    );
  }
}
