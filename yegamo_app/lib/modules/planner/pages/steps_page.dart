import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/models/data_state.dart';
import '../models/planner_models.dart';
import '../providers/planner_view_model.dart';
import '../widgets/planner_common.dart';
import 'departure_page.dart' show startPlannedJourney;

enum _Dot { plain, bus, off, here }

enum _Line { walk, bus, wait, none }

class _Step {
  const _Step({
    required this.icon,
    required this.dot,
    required this.line,
    required this.title,
    this.time,
    this.subtitle,
    this.showStatus = false,
  });

  final String icon;
  final _Dot dot;
  final _Line line;
  final String title;
  final String? time;
  final String? subtitle;
  final bool showStatus;
}

/// 11 · Paso a paso: línea de tiempo con los tramos que entrega el plan.
///
/// Solo se muestran pasos que el API respalda (tramos a pie y en transporte);
/// no se inventan esperas, paradas ni nombres de línea.
class PlannerStepsPage extends StatelessWidget {
  const PlannerStepsPage({super.key});

  List<_Step> _steps(JourneyOption option, OptionTimes times) {
    final legs = option.legs;
    final out = <_Step>[];
    String? t(DateTime? d) => d == null ? null : hm(d);
    String? walkSub(JourneyLeg leg) {
      final extra = leg.instructions.isEmpty ? '' : ' · ${leg.instructions.first}';
      return 'Camina ${leg.durationMin} min$extra';
    }

    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final prev = i > 0 ? legs[i - 1] : null;
      final next = i < legs.length - 1 ? legs[i + 1] : null;
      if (isWalkLeg(leg)) {
        if (prev == null) {
          out.add(
            _Step(
              icon: YgIcons.casa,
              dot: _Dot.here,
              line: _Line.walk,
              title: 'Sal de tu ubicación',
              time: t(leg.departureAt) ?? t(times.departure),
              subtitle: walkSub(leg),
            ),
          );
        } else if (!isWalkLeg(prev)) {
          final transfer = next != null && !isWalkLeg(next);
          out.add(
            _Step(
              icon: transfer ? YgIcons.transbordo : YgIcons.campana,
              dot: transfer ? _Dot.plain : _Dot.off,
              line: _Line.walk,
              title: transfer ? 'Transbordo' : 'Bájate del transporte',
              time: t(leg.departureAt),
              subtitle: walkSub(leg),
            ),
          );
        }
      } else {
        final instr = leg.instructions.isEmpty ? '' : ' · ${leg.instructions.first}';
        out.add(
          _Step(
            icon: YgIcons.bus,
            dot: _Dot.bus,
            line: _Line.bus,
            title: 'Sube al transporte',
            time: t(leg.departureAt),
            subtitle: '${leg.durationMin} min$instr',
            showStatus: true,
          ),
        );
        if (next == null) {
          out.add(
            _Step(
              icon: YgIcons.campana,
              dot: _Dot.off,
              line: _Line.none,
              title: 'Bájate del transporte',
              time: t(leg.arrivalAt),
            ),
          );
        }
      }
    }
    out.add(
      _Step(
        icon: YgIcons.bandera,
        dot: _Dot.here,
        line: _Line.none,
        title: 'Llegas a tu destino',
        time: times.arrivalText,
      ),
    );
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlannerViewModel>();
    final plan = vm.state.plan;
    final option = vm.selectedOption;
    final times = plan == null || option == null
        ? const OptionTimes()
        : timesFor(plan, option);
    final options = plan?.options ?? const <JourneyOption>[];
    final altIndex = option == null
        ? 0
        : math.min(2, math.max(0, options.indexWhere((o) => o.id == option.id)));
    final planUx = plan == null
        ? UxState.empty
        : UxStateMapping.fromDataState(plan.dataState);
    final steps = option == null || option.legs.isEmpty
        ? const <_Step>[]
        : _steps(option, times);
    final canStart = plan != null && option != null;

    Widget startButton({bool small = false}) => YgButton(
      key: small ? null : const ValueKey('journey_start'),
      label: small ? 'Iniciar' : 'Iniciar viaje',
      icon: small ? null : YgIcons.navegar,
      variant: YgButtonVariant.go,
      size: small ? YgButtonSize.sm : YgButtonSize.md,
      expand: !small,
      onPressed: canStart
          ? () => startPlannedJourney(context, plan, option)
          : null,
    );

    return PlannerFlowScaffold(
      step: 3,
      title: 'Paso a paso',
      subtitle: option == null
          ? null
          : '${option.durationMin} min · ${plannerSummary(mode: vm.timeMode, target: vm.targetTime, margin: vm.extraSafetyMarginMin, preference: vm.preference)}',
      onBack: () => Navigator.of(context).maybePop(),
      mapMode: YgMapMode.steps,
      mapAlt: altIndex,
      mapDs: mapStateFor(planUx),
      config: YgSheetConfig.steps,
      headerAtMin: true,
      headerBuilder: (context, snap) => SheetHeadRow(
        trailing: snap == YgSnap.min ? startButton(small: true) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const YgOverline('Paso a paso'),
            const SizedBox(height: 4),
            Text(
              option == null
                  ? 'Sin recorrido'
                  : (times.departure != null && times.arrivalTo != null
                        ? '${hm(times.departure!)} → ${hm(times.arrivalTo!)}'
                        : '${option.durationMin} min'),
              style: YgText.title2.copyWith(
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
            if (option != null) ...[
              const SizedBox(height: 2),
              Text(
                '${option.durationMin} min · ${option.walkMin} min a pie',
                style: YgText.meta,
              ),
            ],
          ],
        ),
      ),
      body: (context, snap) => SheetScroll(
        stagger: false,
        padding: EdgeInsets.fromLTRB(16, 0, 16, canStart ? 104 : 32),
        sticky: canStart ? StickyBar(child: startButton()) : null,
        children: [
          if (option == null)
            const YgBanner(
              title: 'Sin recorrido',
              message: 'Calcula un viaje para ver sus pasos.',
              icon: YgIcons.lista,
              tone: YgBannerTone.off,
            )
          else if (steps.isEmpty)
            const YgBanner(
              title: 'Sin instrucciones',
              message: 'No hay instrucciones disponibles para este plan.',
              icon: YgIcons.lista,
              tone: YgBannerTone.off,
            )
          else
            YgStagger(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _StepTile(
                    step: steps[i],
                    index: i,
                    count: steps.length,
                    quality: option.dataQuality,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// `.st`: carril de 28 px con punto y línea, y el cuerpo del paso.
class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.index,
    required this.count,
    required this.quality,
  });

  final _Step step;
  final int index;
  final int count;
  final JourneyDataQuality quality;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (step.dot) {
      _Dot.plain => (YgColors.fill, YgColors.cypress),
      _Dot.bus => (YgColors.cypress, Colors.white),
      _Dot.off => (YgColors.moss, Colors.white),
      _Dot.here => (Colors.white, YgColors.moss),
    };
    return Semantics(
      container: true,
      label:
          'Paso ${index + 1} de $count: ${step.title}'
          '${step.time == null ? '' : ', ${step.time}'}',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: step.dot == _Dot.here
                          ? Border.all(color: YgColors.moss, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: YgIcon(step.icon, size: 15, color: fg),
                    ),
                  ),
                  if (step.line != _Line.none)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 24),
                          child: CustomPaint(
                            size: const Size(3, double.infinity),
                            painter: _LinePainter(step.line),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: YgText.sub.copyWith(letterSpacing: -.15),
                          ),
                        ),
                        if (step.time != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            step.time!,
                            softWrap: false,
                            style: YgText.secondary.copyWith(
                              fontFeatures: const [
                                ui.FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (step.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(step.subtitle!, style: YgText.secondary),
                      ),
                    if (step.showStatus)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: PlannerStatusLabel(quality),
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

class _LinePainter extends CustomPainter {
  const _LinePainter(this.kind);

  final _Line kind;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    switch (kind) {
      case _Line.bus:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            const Radius.circular(2),
          ),
          Paint()..color = YgColors.cypress,
        );
      case _Line.walk:
        final p = Paint()..color = YgColors.olive;
        for (var y = 1.5; y < size.height; y += 7) {
          canvas.drawCircle(Offset(cx, y), 1.5, p);
        }
      case _Line.wait:
        final p = Paint()..color = YgColors.cedar;
        for (var y = 0.0; y < size.height; y += 7) {
          canvas.drawRect(
            Rect.fromLTWH(0, y, size.width, math.min(3, size.height - y)),
            p,
          );
        }
      case _Line.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.kind != kind;
}
