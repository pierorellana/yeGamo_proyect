import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/map/yg_map_host.dart';
import '../../../shared/map/yg_map_view.dart';
import '../providers/planner_view_model.dart';
import '../widgets/planner_common.dart';

/// 08 · Cargando (E8): panel con anillo, pasos y mapa en modo `loading`.
///
/// El avance a Alternativas lo decide [PlannerViewModel] (la pantalla que
/// lanzó el cálculo cierra esta ruta cuando el API responde); el escalonado
/// de pasos es decorativo.
class PlannerLoadingPage extends StatefulWidget {
  const PlannerLoadingPage({super.key});

  @override
  State<PlannerLoadingPage> createState() => _PlannerLoadingPageState();
}

class _PlannerLoadingPageState extends State<PlannerLoadingPage>
    with SingleTickerProviderStateMixin {
  static const _steps = [
    ('Buscando paradas cercanas', 550),
    ('Consultando buses en vivo', 1250),
    ('Estimando esperas y tráfico', 1950),
    ('Calculando tu ventana de llegada', 2650),
  ];
  static const _totalMs = 3000;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlannerViewModel>();
    final h = MediaQuery.sizeOf(context).height;
    const sheetH = 336.0;
    final summary = plannerSummary(
      mode: vm.timeMode,
      target: vm.targetTime,
      margin: vm.extraSafetyMarginMin,
      preference: vm.preference,
    );
    return YgMapBinding(
      view: YgMapView(
        mode: YgMapMode.loading,
        visibleBottom: h - 8 - sheetH - 16,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: YgEnter(
                kind: YgEnterKind.fade,
                child: PlannerFlowBar(
                  step: 2,
                  title: 'Calculando opciones',
                  subtitle: summary,
                ),
              ),
            ),
            PlannerStaticSheet(
              height: sheetH,
              child: Semantics(
                container: true,
                liveRegion: true,
                label: 'Calculando tu salida',
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: YgStagger(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const _LoadRing(key: ValueKey('planner_progress')),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Calculando tu salida',
                                        style: YgText.title2,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Comparando rutas posibles',
                                        style: YgText.body.copyWith(
                                          fontSize: 14,
                                          color: YgColors.text2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: AnimatedBuilder(
                                animation: _c,
                                builder: (context, _) {
                                  final ms = _c.value * _totalMs;
                                  return Column(
                                    children: [
                                      for (var i = 0; i < _steps.length; i++)
                                        _LoadStep(
                                          label: _steps[i].$1,
                                          sinceMs: ms - _steps[i].$2,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: YgButton(
                        key: const ValueKey('planner_cancel'),
                        label: 'Cancelar',
                        variant: YgButtonVariant.secondary,
                                                expand: true,
                        onPressed: () {
                          context.read<PlannerViewModel>().cancel();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paso de la lista (`.ls`): spinner hasta su instante y luego check que
/// «salta» (`okIn`: 0,35 s, `cubic-bezier(.34,1.6,.5,1)`).
class _LoadStep extends StatelessWidget {
  const _LoadStep({required this.label, required this.sinceMs});

  final String label;
  final double sinceMs;

  @override
  Widget build(BuildContext context) {
    final reduce = YgMotionScope.reduced(context);
    final done = sinceMs >= 0;
    final k = reduce ? 1.0 : (sinceMs / 350).clamp(0.0, 1.0);
    final scale = const Cubic(.34, 1.6, .5, 1).transform(k);
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Stack(
              children: [
                if (!done || scale < 1) const YgSpinner(size: 20, width: 2),
                if (done)
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: YgColors.cypress,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: YgIcon(
                          YgIcons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: YgColors.moss,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.ld-ring`: disco de 48 con arco giratorio y el icono de bus al centro.
class _LoadRing extends StatelessWidget {
  const _LoadRing({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: YgColors.fill2,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          YgLoop(
            duration: const Duration(milliseconds: 1100),
            builder: (context, t, _) => Transform.rotate(
              angle: t * 2 * math.pi,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: CustomPaint(painter: _RingPainter()),
              ),
            ),
          ),
          const YgIcon(YgIcons.bus, size: 20, color: YgColors.cypress),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 20);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFE6E9E0),
    );
    // stroke-dasharray 26 74 sobre pathLength 100 = 26 % del círculo.
    canvas.drawArc(
      rect,
      0,
      2 * math.pi * .26,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = YgColors.cypress,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => false;
}
