import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/models/data_state.dart';
import '../models/journey_models.dart';
import 'journey_helpers.dart';

/// Tarjeta superior de instrucción (`.instr`): icono 48, texto y subtítulo.
class JourneyInstructionCard extends StatelessWidget {
  const JourneyInstructionCard({
    super.key,
    required this.icon,
    required this.walkStyle,
    required this.title,
    this.pre,
    this.sub,
  });

  final String icon;
  final bool walkStyle;
  final String title;
  final String? pre;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return YgEnter(
      kind: YgEnterKind.down,
      child: YgGlass(
        radius: 22,
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: walkStyle ? YgColors.moss : YgColors.cypress,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: YgIcon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pre != null)
                      Text(pre!, style: YgText.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: YgText.sub.copyWith(
                          fontSize: 16,
                          letterSpacing: -.32,
                        ),
                      ),
                    ),
                    if (sub != null)
                      Text(sub!, style: YgText.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de acción translúcido (`.chip.glass`).
class JourneyGlassChip extends StatelessWidget {
  const JourneyGlassChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return YgPressable(
      onTap: onTap,
      semanticLabel: label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: onTap == null ? .5 : 1,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(18),
              boxShadow: YgShadows.glass,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                YgIcon(icon, size: 16, color: YgColors.moss),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: YgColors.moss,
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

/// Barra de progreso (`.prog`): relleno, marcas por paso y marcador con
/// transición lineal de 1 s.
class JourneyProgressBar extends StatelessWidget {
  const JourneyProgressBar({
    super.key,
    required this.progress,
    required this.steps,
  });

  final double progress;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final reduce = YgMotionScope.reduced(context);
    final target = progress.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: 'Progreso del viaje',
      value: '${(target * 100).round()} %',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 14,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: target, end: target),
            duration: reduce ? YgMotion.reduced : const Duration(seconds: 1),
            curve: Curves.linear,
            builder: (context, value, _) => LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 5,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: YgColors.track,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 5,
                      height: 4,
                      width: w * value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: YgColors.cypress,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (steps > 1)
                      for (var k = 1; k < steps; k++)
                        Positioned(
                          left: w * k / steps - 1,
                          top: 5,
                          width: 2,
                          height: 4,
                          child: const ColoredBox(color: Colors.white),
                        ),
                    Positioned(
                      left: w * value - 7,
                      top: 0,
                      width: 14,
                      height: 14,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: YgColors.moss, spreadRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabecera del panel (zona de arrastre): llegada estimada, pasos restantes y
/// progreso. La hora solo aparece si el viaje trae una ETA utilizable.
class JourneySheetHeader extends StatelessWidget {
  const JourneySheetHeader({
    super.key,
    required this.journey,
    required this.windowText,
  });

  final ActiveJourney journey;
  final String? windowText;

  @override
  Widget build(BuildContext context) {
    final eta = journey.eta;
    final hasEta = eta != null && journey.dataState != DataState.unavailable;
    final left = journey.totalSteps - journey.currentStep;
    final total = journey.totalSteps;
    final progress = total <= 0 ? 0.0 : journey.currentStep / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Llegada estimada',
                      style: TextStyle(
                        fontSize: 12,
                        color: YgColors.text3,
                        letterSpacing: -.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasEta)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatClock(eta),
                            style: YgText.display.copyWith(
                              fontSize: 32,
                              letterSpacing: -1.28,
                              color: YgColors.moss,
                            ),
                          ),
                          if (windowText != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'ventana $windowText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: YgText.meta.copyWith(
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      Text(
                        'Sin estimación disponible',
                        style: YgText.sub.copyWith(color: YgColors.text2),
                      ),
                  ],
                ),
              ),
              if (total > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Faltan',
                      style: TextStyle(fontSize: 12, color: YgColors.text3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${left < 0 ? 0 : left} ${left == 1 ? 'paso' : 'pasos'}',
                      style: YgText.sub.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: JourneyProgressBar(progress: progress, steps: total),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Inicio', style: TextStyle(fontSize: 12, color: YgColors.text3)),
              Text('Destino', style: TextStyle(fontSize: 12, color: YgColors.text3)),
            ],
          ),
        ],
      ),
    );
  }
}

enum JourneyStopState { pass, next, alight, none }

/// Fila de próxima parada/tramo (`.nst`).
class JourneyStopRow extends StatelessWidget {
  const JourneyStopRow({
    super.key,
    required this.title,
    required this.state,
    this.trailing,
  });

  final String title;
  final JourneyStopState state;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ring = switch (state) {
      JourneyStopState.pass => YgColors.muted,
      JourneyStopState.alight => YgColors.moss,
      _ => YgColors.cypress,
    };
    final fill = switch (state) {
      JourneyStopState.next => YgColors.cypress,
      JourneyStopState.alight => YgColors.moss,
      _ => Colors.transparent,
    };
    return Opacity(
      opacity: state == JourneyStopState.pass ? .45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 2),
            SizedBox(
              width: 13,
              height: 13,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (state == JourneyStopState.next)
                    Positioned(
                      left: -4,
                      top: -4,
                      right: -4,
                      bottom: -4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: YgColors.cypress.withValues(alpha: .15),
                        ),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      border: Border.all(color: ring, width: 2),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: YgText.sub.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: YgText.meta.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
