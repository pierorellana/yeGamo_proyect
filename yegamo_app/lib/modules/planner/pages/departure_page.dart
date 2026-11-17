import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../notifications/services/alerts_repository.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/navigation/app_routes.dart';
import '../models/planner_models.dart';
import '../providers/planner_view_model.dart';
import '../widgets/planner_common.dart';

/// Inicia el viaje activo con la opción elegida (mismos argumentos que el
/// botón `journey_start` de Paso a paso).
void startPlannedJourney(BuildContext context, JourneyPlan plan, JourneyOption o) {
  Navigator.of(context).pushNamed(
    AppRoutes.activeJourney,
    arguments: <String, String>{'planId': plan.planId, 'optionId': o.id},
  );
}

/// 10 · Cuándo salir (+ 23 · ¿Por qué esta hora?).
class DeparturePage extends StatefulWidget {
  const DeparturePage({super.key});

  @override
  State<DeparturePage> createState() => _DeparturePageState();
}

class _DeparturePageState extends State<DeparturePage> {
  bool _why = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlannerViewModel>();
    final plan = vm.state.plan;
    final option = vm.selectedOption;
    final times = plan == null || option == null
        ? const OptionTimes()
        : timesFor(plan, option);
    final dep = times.departure;
    final now = DateTime.now();
    final target = vm.timeMode == TimeMode.arriveBy ? vm.targetTime : null;
    final options = plan?.options ?? const <JourneyOption>[];
    final altIndex = option == null
        ? 0
        : math.min(2, math.max(0, options.indexWhere((o) => o.id == option.id)));
    final leaveMin = dep == null
        ? null
        : math.max(0, (dep.difference(now).inSeconds / 60).ceil());
    final today = dep != null && sameDay(dep, now);
    final canStart = plan != null && option != null;
    final planUx = plan == null
        ? UxState.empty
        : UxStateMapping.fromDataState(plan.dataState);

    return PlannerFlowScaffold(
      step: 3,
      title: 'Cuándo salir',
      subtitle: option == null
          ? null
          : '${option.durationMin} min · ${plannerSummary(mode: vm.timeMode, target: vm.targetTime, margin: vm.extraSafetyMarginMin, preference: vm.preference)}',
      onBack: () => Navigator.of(context).maybePop(),
      mapMode: YgMapMode.depart,
      mapAlt: altIndex,
      mapDs: mapStateFor(planUx),
      config: YgSheetConfig.departure,
      peek: SheetPeekRow(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const YgOverline('Sal a las'),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      dep == null ? 'Sin hora' : hm(dep),
                      style: YgText.display.copyWith(
                        fontSize: 28,
                        letterSpacing: -1.12,
                      ),
                    ),
                    if (leaveMin != null && today) ...[
                      const SizedBox(width: 8),
                      Text(
                        'en $leaveMin min',
                        style: YgText.secondary.copyWith(
                          fontWeight: FontWeight.w600,
                          color: YgColors.cypress,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          YgButton(
            label: 'Iniciar',
            variant: YgButtonVariant.go,
            size: YgButtonSize.sm,
            onPressed: canStart
                ? () => startPlannedJourney(context, plan, option)
                : null,
          ),
        ],
      ),
      body: (context, snap) => SheetScroll(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
        sticky: StickyBar(
          child: Row(
            children: [
              Expanded(
                child: YgButton(
                  key: const ValueKey('departure_start'),
                  label: 'Iniciar viaje',
                  icon: YgIcons.navegar,
                  variant: YgButtonVariant.go,
                  expand: true,
                  onPressed: canStart
                      ? () => startPlannedJourney(context, plan, option)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Ver paso a paso',
                child: YgButton(
                  key: const ValueKey('departure_steps'),
                  label: 'Pasos',
                  icon: YgIcons.lista,
                  variant: YgButtonVariant.secondary,
                  onPressed: plan == null
                      ? null
                      : () => Navigator.of(context).pushNamed(
                          AppRoutes.stepByStep,
                        ),
                ),
              ),
            ],
          ),
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const YgOverline('Sal a las'),
                    const SizedBox(height: 8),
                    if (dep != null)
                      FlipDigits(key: ValueKey(hm(dep)), text: hm(dep))
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Sin recomendación disponible',
                          style: YgText.title2,
                        ),
                      ),
                  ],
                ),
              ),
              if (leaveMin != null)
                YgCountdownRing(
                  value: today ? '$leaveMin' : '—',
                  progress: today ? math.min(1.0, leaveMin / 30) : 1,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _summaryText(times, target),
          ),
          if (option != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PlannerStatusLabel(option.dataQuality),
              ),
            ),
          if (dep == null)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: YgBanner(
                title: 'Sin hora de salida',
                message:
                    'No se inventa una hora de salida cuando la fuente no entrega una recomendación.',
                icon: YgIcons.reloj,
                tone: YgBannerTone.off,
              ),
            )
          else if (times.hasArrival)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _ArrivalWindow(
                departure: dep,
                from: times.arrivalFrom!,
                to: times.arrivalTo!,
                target: target,
              ),
            ),
          if (plan != null && dep != null)
            _LeaveAlertButton(planId: plan.planId, leaveAt: dep),
          if (option != null) ..._composition(option, vm.extraSafetyMarginMin),
          if (option != null) _reliability(option, vm.extraSafetyMarginMin),
        ],
      ),
    );
  }

  Widget _summaryText(OptionTimes times, DateTime? target) {
    const strong = TextStyle(fontWeight: FontWeight.w700, color: YgColors.text);
    final parts = <InlineSpan>[];
    if (target != null) {
      parts.addAll([
        const TextSpan(text: 'Para llegar a tu destino antes de las '),
        TextSpan(text: hm(target), style: strong),
        const TextSpan(text: '. '),
      ]);
    }
    if (times.arrivalText != null) {
      parts.addAll([
        TextSpan(text: target == null ? 'Llegarías ' : 'Llegarías entre '),
        TextSpan(
          text: times.arrivalText,
          style: strong.copyWith(
            color: YgColors.cypress,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
        const TextSpan(text: '.'),
      ]);
    }
    if (parts.isEmpty) {
      return Text(
        'La hora de llegada no está disponible para esta opción.',
        style: YgText.secondary.copyWith(fontSize: 14),
      );
    }
    return Text.rich(
      TextSpan(children: parts),
      style: YgText.secondary.copyWith(fontSize: 14, height: 1.4),
    );
  }

  List<Widget> _composition(JourneyOption option, int extra) {
    final rows = <_CompRowData>[];
    if (option.legs.isEmpty) {
      if (option.walkMin > 0) {
        rows.add(
          _CompRowData(
            icon: YgIcons.caminar,
            tone: YgTileTone.normal,
            title: 'Caminata',
            minutes: '${option.walkMin} min',
          ),
        );
      }
      final rest = option.durationMin - option.walkMin;
      if (rest > 0) {
        rows.add(
          _CompRowData(
            icon: YgIcons.reloj,
            tone: YgTileTone.aloe,
            title: 'Transporte y esperas',
            minutes: '$rest min',
          ),
        );
      }
    } else {
      for (var i = 0; i < option.legs.length; i++) {
        final leg = option.legs[i];
        final sub = leg.instructions.isEmpty ? null : leg.instructions.first;
        if (isWalkLeg(leg)) {
          rows.add(
            _CompRowData(
              icon: YgIcons.caminar,
              tone: YgTileTone.normal,
              title: i == 0
                  ? 'Caminata a la parada'
                  : (i == option.legs.length - 1
                        ? 'Caminata al destino'
                        : 'Caminata'),
              subtitle: sub,
              minutes: '${leg.durationMin} min',
            ),
          );
        } else {
          rows.add(
            _CompRowData(
              icon: YgIcons.bus,
              tone: YgTileTone.cypress,
              title: 'Viaje en transporte',
              subtitle: sub,
              minutes: '${leg.durationMin} min',
            ),
          );
        }
      }
    }
    rows.add(
      _CompRowData(
        icon: YgIcons.mas,
        tone: YgTileTone.normal,
        title: 'Tu margen extra',
        subtitle: 'Lo eliges al planificar',
        minutes: '$extra min',
      ),
    );
    return [
      Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Así se compone tu tiempo', style: YgText.sub),
            Text(
              '${option.durationMin + extra} min',
              style: YgText.secondary.copyWith(
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
      YgGroup(children: [for (final r in rows) _CompRow(r)]),
    ];
  }

  Widget _reliability(JourneyOption option, int extra) {
    final score = option.reliabilityScore;
    final word = reliabilityWord(score);
    final samples = option.reliabilitySamples ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: YgCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (option.hasReliability)
                  YgGauge(score: score)
                else
                  const YgTile(icon: YgIcons.escudo, size: 56, iconSize: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.hasReliability
                            ? 'Fiabilidad $word'
                            : 'Fiabilidad sin datos',
                        style: YgText.sub,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.hasReliability && samples > 0
                            ? 'Basada en $samples viajes observados en esta franja. No es una garantía.'
                            : 'Todavía no hay viajes observados suficientes en esta franja. No es una garantía.',
                        style: YgText.meta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: YgColors.divider),
            Semantics(
              button: true,
              expanded: _why,
              label: '¿Por qué esta hora?',
              excludeSemantics: true,
              child: YgPressable(
                onTap: () => setState(() => _why = !_why),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '¿Por qué esta hora?',
                        style: YgText.sub.copyWith(
                          fontSize: 14,
                          color: YgColors.cypress,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _why ? .5 : 0,
                        duration: YgMotionScope.reduced(context)
                            ? YgMotion.reduced
                            : const Duration(milliseconds: 350),
                        child: const YgIcon(
                          YgIcons.chevronAbajo,
                          size: 16,
                          color: YgColors.cypress,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_why)
              YgEnter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Usamos una duración conservadora del viaje y le sumamos '
                    'un margen de seguridad según la fiabilidad'
                    '${option.hasReliability ? ' $word' : ''}'
                    '${extra > 0 ? ', más tus $extra min extra' : ''}. '
                    'Si la hora cambia más de 5 min, te explicamos el motivo.',
                    style: YgText.secondary.copyWith(fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompRowData {
  const _CompRowData({
    required this.icon,
    required this.tone,
    required this.title,
    required this.minutes,
    this.subtitle,
  });

  final String icon;
  final YgTileTone tone;
  final String title;
  final String? subtitle;
  final String minutes;
}

/// `.crow`: fila de la composición del tiempo.
class _CompRow extends StatelessWidget {
  const _CompRow(this.data);

  final _CompRowData data;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            YgTile(icon: data.icon, tone: data.tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data.title, style: YgText.sub.copyWith(height: 1.3)),
                  if (data.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(data.subtitle!, style: YgText.meta),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              data.minutes,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: YgColors.text,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hora enorme con dígitos que voltean (`.flip` / `.fd`).
// ---------------------------------------------------------------------------

class FlipDigits extends StatelessWidget {
  const FlipDigits({super.key, required this.text, this.fontSize = 64});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = YgText.heroTime.copyWith(
      fontSize: fontSize,
      letterSpacing: -fontSize * .04,
    );
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < text.length; i++)
            _FlipChar(
              char: text[i],
              style: style,
              delay: Duration(milliseconds: 180 + i * 70),
            ),
        ],
      ),
    );
  }
}

class _FlipChar extends StatefulWidget {
  const _FlipChar({
    required this.char,
    required this.style,
    required this.delay,
  });

  final String char;
  final TextStyle style;
  final Duration delay;

  @override
  State<_FlipChar> createState() => _FlipCharState();
}

class _FlipCharState extends State<_FlipChar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (YgMotionScope.reduced(context)) {
      _c.duration = YgMotion.reduced;
      _c.forward();
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = YgMotionScope.reduced(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // fd: from { opacity:0; rotateX(-90deg) translateY(-8px) } con
        // cubic-bezier(.2,1.3,.4,1) (sobrepasa y asienta).
        final v = const Cubic(.2, 1.3, .4, 1).transform(_c.value);
        final t = 1 - v;
        final opacity = _c.value == 0 ? 0.0 : math.min(1.0, v * 4);
        if (reduce) return Opacity(opacity: _c.value, child: child);
        return Opacity(
          opacity: opacity,
          child: Transform(
            alignment: const Alignment(0, .2),
            transform: Matrix4.identity()
              ..setEntry(3, 2, -1 / 420)
              ..translateByDouble(0.0, -8 * t, 0.0, 1.0)
              ..rotateX(-math.pi / 2 * t),
            child: child,
          ),
        );
      },
      child: Text(widget.char, style: widget.style),
    );
  }
}

// ---------------------------------------------------------------------------
// Ventana de llegada (`.win`).
// ---------------------------------------------------------------------------

class _ArrivalWindow extends StatelessWidget {
  const _ArrivalWindow({
    required this.departure,
    required this.from,
    required this.to,
    required this.target,
  });

  final DateTime departure;
  final DateTime from;
  final DateTime to;
  final DateTime? target;

  @override
  Widget build(BuildContext context) {
    final rs = departure.subtract(const Duration(minutes: 3));
    final latest = target != null && target!.isAfter(to) ? target! : to;
    final re = latest.add(const Duration(minutes: 6));
    final span = re.difference(rs).inSeconds.toDouble();
    double pos(DateTime m) =>
        (m.difference(rs).inSeconds / span).clamp(0.0, 1.0);
    final pDep = pos(departure);
    final pFrom = pos(from);
    final pTo = pos(to);
    final pTarget = target == null ? null : pos(target!);
    final reduce = YgMotionScope.reduced(context);
    const labelStyle = TextStyle(
      fontSize: 11,
      color: YgColors.text3,
      fontFeatures: [ui.FontFeature.tabularFigures()],
    );
    return Semantics(
      container: true,
      label:
          'Ventana de llegada ${hmRange(from, to)}. Salida ${hm(departure)}.'
          '${target == null ? '' : ' Objetivo ${hm(target!)}.'}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 32,
                  color: YgColors.fill3,
                  child: Stack(
                    children: [
                      if (pTarget != null && pTarget > pTo)
                        Positioned(
                          left: pTo * w,
                          width: (pTarget - pTo) * w,
                          top: 8,
                          bottom: 8,
                          child: const ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                            child: CustomPaint(painter: _HatchPainter()),
                          ),
                        ),
                      Positioned(
                        left: pFrom * w,
                        width: math.max(6.0, (pTo - pFrom) * w),
                        top: 0,
                        bottom: 0,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: reduce ? 1 : 0, end: 1),
                          duration: reduce
                              ? YgMotion.reduced
                              : const Duration(milliseconds: 1150),
                          curve: const Interval(
                            .304,
                            1,
                            curve: Cubic(.34, 1.3, .5, 1),
                          ),
                          builder: (context, v, child) => Transform(
                            alignment: Alignment.centerLeft,
                            transform: Matrix4.diagonal3Values(
                              math.max(0.0, v),
                              1,
                              1,
                            ),
                            child: Opacity(
                              opacity: v.clamp(0.0, 1.0),
                              child: child,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: YgColors.cypress.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: YgColors.cypress,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (pTarget != null)
                        Positioned(
                          left: pTarget * w - 1,
                          width: 2,
                          top: 0,
                          bottom: 0,
                          child: const ColoredBox(color: YgColors.moss),
                        ),
                      Positioned(
                        left: pDep * w - 1,
                        width: 2,
                        top: 0,
                        bottom: 0,
                        child: const ColoredBox(color: YgColors.cedar),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 20,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _label(w, pDep, hm(departure), labelStyle),
                    _label(
                      w,
                      (pFrom + pTo) / 2,
                      hmRange(from, to),
                      labelStyle,
                    ),
                    if (pTarget != null)
                      _label(w, pTarget, hm(target!), labelStyle),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _legend(
                    Container(
                      width: 12,
                      height: 8,
                      decoration: BoxDecoration(
                        color: YgColors.cypress.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: YgColors.cypress),
                      ),
                    ),
                    'Ventana de llegada',
                  ),
                  if (pTarget != null && pTarget > pTo)
                    _legend(
                      const SizedBox(
                        width: 12,
                        height: 8,
                        child: CustomPaint(painter: _HatchPainter(small: true)),
                      ),
                      'Margen',
                    ),
                  if (pTarget != null)
                    _legend(
                      const SizedBox(
                        width: 2,
                        height: 10,
                        child: ColoredBox(color: YgColors.moss),
                      ),
                      'Objetivo',
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _label(double w, double p, String text, TextStyle style) => Positioned(
    left: p * w,
    top: 4,
    child: FractionalTranslation(
      translation: const Offset(-.5, 0),
      child: Text(text, style: style, softWrap: false),
    ),
  );

  Widget _legend(Widget swatch, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      swatch,
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 11, color: YgColors.text3)),
    ],
  );
}

/// Rayado a 135° del margen (`repeating-linear-gradient(135deg …)`).
class _HatchPainter extends CustomPainter {
  const _HatchPainter({this.small = false});

  final bool small;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 1.5
      ..color = small ? YgColors.cedar : YgColors.muted;
    final step = small ? 4.0 : 5.0;
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width + size.height; x += step * 1.35) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter old) => old.small != small;
}


/// «Avisarme» / «Cancelar aviso». Solo aparece con una hora de salida real del
/// plan; programa `POST /v1/alerts/leave` y cancela con `DELETE /v1/alerts/{id}`.
class _LeaveAlertButton extends StatefulWidget {
  const _LeaveAlertButton({required this.planId, required this.leaveAt});

  final String planId;
  final DateTime leaveAt;

  @override
  State<_LeaveAlertButton> createState() => _LeaveAlertButtonState();
}

class _LeaveAlertButtonState extends State<_LeaveAlertButton> {
  DateTime? _scheduled;
  bool _busy = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    context.read<AlertsRepository>().scheduledFor(widget.planId).then((value) {
      if (mounted) setState(() => _scheduled = value);
    });
  }

  Future<void> _toggle() async {
    final repo = context.read<AlertsRepository>();
    setState(() => _busy = true);
    final scheduled = _scheduled != null;
    final result = scheduled
        ? await repo.cancel(widget.planId)
        : await repo.schedule(planId: widget.planId, leaveAt: widget.leaveAt);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok) _scheduled = scheduled ? null : result.scheduledFor;
    });
    YgToast.show(
      context,
      result.error?.message ??
          (scheduled ? 'Aviso cancelado' : 'Te avisaremos a la hora de salir'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: YgButton(
        key: const ValueKey('departure_alert'),
        label: _scheduled == null ? 'Avisarme' : 'Cancelar aviso',
        icon: YgIcons.campana,
        variant: YgButtonVariant.secondary,
        expand: true,
        onPressed: _busy ? null : _toggle,
      ),
    );
  }
}
