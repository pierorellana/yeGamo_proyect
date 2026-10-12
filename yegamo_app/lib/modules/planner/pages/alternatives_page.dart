import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/navigation/app_routes.dart';
import '../../../shared/widgets/remote_state_view.dart';
import '../models/planner_models.dart';
import '../providers/planner_view_model.dart';
import '../widgets/planner_common.dart';

/// 09 · Alternativas (+ E1 error, E3 sin conexión, E5 parcial, E7 sin
/// resultados): lista de opciones ordenable con una opción elegida.
class AlternativesPage extends StatefulWidget {
  const AlternativesPage({super.key});

  @override
  State<AlternativesPage> createState() => _AlternativesPageState();
}

class _AlternativesPageState extends State<AlternativesPage> {
  late TravelPreference _sort;
  bool _initialized = false;

  static const _cycle = [
    TravelPreference.balanced,
    TravelPreference.reliable,
    TravelPreference.lessWalking,
    TravelPreference.fewerTransfers,
    TravelPreference.fastest,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final vm = context.read<PlannerViewModel>();
    _sort = vm.preference;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ordered = _ordered(vm.state.plan?.options ?? const []);
      if (ordered.isNotEmpty) vm.selectOption(ordered.first.id);
    });
  }

  List<JourneyOption> _ordered(List<JourneyOption> options) {
    final indexed = [for (var i = 0; i < options.length; i++) (i, options[i])];
    int byIndex(int a, int b) => a.compareTo(b);
    indexed.sort((x, y) {
      final a = x.$2;
      final b = y.$2;
      final c = switch (_sort) {
        TravelPreference.balanced => 0,
        TravelPreference.fastest => a.durationMin.compareTo(b.durationMin),
        TravelPreference.reliable => b.reliabilityScore.compareTo(
          a.reliabilityScore,
        ),
        TravelPreference.lessWalking =>
          a.walkMin != b.walkMin
              ? a.walkMin.compareTo(b.walkMin)
              : b.reliabilityScore.compareTo(a.reliabilityScore),
        TravelPreference.fewerTransfers =>
          a.transfers != b.transfers
              ? a.transfers.compareTo(b.transfers)
              : b.reliabilityScore.compareTo(a.reliabilityScore),
      };
      return c != 0 ? c : byIndex(x.$1, y.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  Future<void> _retry() async {
    final vm = context.read<PlannerViewModel>();
    Navigator.of(context).pushNamed(AppRoutes.loading);
    await vm.calculate();
    if (!mounted || vm.state.phase == PlannerPhase.cancelled) return;
    Navigator.of(context).pop();
  }

  void _cycleSort(PlannerViewModel vm, JourneyPlan plan) {
    setState(() {
      _sort = _cycle[(_cycle.indexOf(_sort) + 1) % _cycle.length];
    });
    final ordered = _ordered(plan.options);
    if (ordered.isNotEmpty) vm.selectOption(ordered.first.id);
  }

  void _pick(PlannerViewModel vm, JourneyOption option) {
    if (vm.selectedOption?.id == option.id) {
      Navigator.of(context).pushNamed(AppRoutes.departure);
    } else {
      vm.selectOption(option.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlannerViewModel>();
    final plan = vm.state.plan;
    final options = plan?.options ?? const <JourneyOption>[];
    final hasOptions = options.isNotEmpty;
    final ordered = _ordered(options);
    final selected = vm.selectedOption;
    final selectedIndex = selected == null
        ? 0
        : math.max(0, options.indexWhere((o) => o.id == selected.id));
    final planUx = plan == null
        ? vm.state.uxState
        : UxStateMapping.fromDataState(plan.dataState);
    final summary = plannerSummary(
      mode: vm.timeMode,
      target: vm.targetTime,
      margin: vm.extraSafetyMarginMin,
      preference: vm.preference,
    );
    final selTimes = selected == null || plan == null
        ? const OptionTimes()
        : timesFor(plan, selected);

    return PlannerFlowScaffold(
      step: 2,
      title: 'Elige una opción',
      subtitle: summary,
      onBack: () => Navigator.of(context).maybePop(),
      onTitleTap: () => Navigator.of(context).maybePop(),
      titleSemantics: 'Editar viaje',
      mapMode: YgMapMode.alts,
      mapAlt: math.min(selectedIndex, 2),
      mapDs: mapStateFor(hasOptions ? planUx : vm.state.uxState),
      config: YgSheetConfig.alternatives,
      enter: YgEnterKind.up,
      headerBuilder: !hasOptions
          ? null
          : (context, snap) => SheetHeadRow(
              trailing: YgChip(
                key: const ValueKey('alternatives_sort'),
                icon: YgIcons.preferencias,
                label: preferenceLabel(_sort),
                onTap: () => _cycleSort(vm, plan!),
              ),
              child: Text('${options.length} opciones', style: YgText.title),
            ),
      peek: hasOptions && selected != null
          ? _Peek(
              option: selected,
              times: selTimes,
              onContinue: () =>
                  Navigator.of(context).pushNamed(AppRoutes.departure),
            )
          : SheetPeekRow(
              children: [
                const YgTile(
                  icon: YgIcons.alerta,
                  tone: YgTileTone.clay,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.state.uxState == UxState.empty ||
                                vm.state.uxState == UxState.ok
                            ? 'Sin opciones para esa hora'
                            : 'No pudimos calcular tu viaje',
                        style: YgText.sub,
                      ),
                      Text(
                        'Abre el panel para ver opciones',
                        style: YgText.meta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      body: (context, snap) {
        if (!hasOptions) {
          return SheetScroll(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [_problem(context, vm)],
          );
        }
        final plan0 = plan!;
        return SheetScroll(
          stagger: false,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          sticky: StickyBar(
            child: YgButton(
              key: const ValueKey('alternatives_continue'),
              label: selTimes.departure == null
                  ? 'Continuar'
                  : 'Continuar · sal a las ${hm(selTimes.departure!)}',
                            expand: true,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.departure),
            ),
          ),
          children: [
            ..._banners(planUx, options),
            YgStagger(
              spacing: 12,
              children: [
                for (var k = 0; k < ordered.length; k++)
                  _AltCard(
                    option: ordered[k],
                    times: timesFor(plan0, ordered[k]),
                    recommended: k == 0,
                    selected: ordered[k].id == selected?.id,
                    onTap: () => _pick(vm, ordered[k]),
                    onSteps: () {
                      vm.selectOption(ordered[k].id);
                      Navigator.of(context).pushNamed(AppRoutes.stepByStep);
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _banners(UxState ux, List<JourneyOption> options) {
    final observed = options
        .map((o) => o.dataQuality.observedAt)
        .whereType<DateTime>()
        .toList();
    final at = observed.isEmpty ? null : hm(observed.first);
    final banner = switch (ux) {
      UxState.degraded => const YgBanner(
        title: 'Información parcial',
        message:
            'Parte de los datos no llega en vivo. Mostramos estimados y los marcamos como tales.',
        icon: YgIcons.alerta,
      ),
      UxState.offline => YgBanner(
        title: 'Sin conexión',
        message: at == null
            ? 'Opciones de tu última consulta.'
            : 'Opciones de tu última consulta ($at).',
        icon: YgIcons.sinConexion,
        tone: YgBannerTone.off,
      ),
      UxState.stale => YgBanner(
        title: 'Datos desactualizados',
        message: at == null
            ? 'Pueden no reflejar el estado actual del servicio.'
            : 'Datos de las $at. Pueden no reflejar el estado actual.',
        icon: YgIcons.reloj,
        actionLabel: 'Actualizar',
        onAction: _retry,
      ),
      _ => null,
    };
    if (banner == null) return const [];
    return [
      Padding(padding: const EdgeInsets.only(bottom: 12), child: banner),
    ];
  }

  Widget _problem(BuildContext context, PlannerViewModel vm) {
    final ux = vm.state.uxState;
    final failed = vm.state.phase == PlannerPhase.failure;
    if (failed && (ux == UxState.permission || ux == UxState.noCoverage)) {
      return SizedBox(
        height: 320,
        child: RemoteStateView(state: ux, onRetry: _retry),
      );
    }
    if (!failed) {
      // Plan listo pero sin opciones (E7).
      final target = vm.targetTime;
      final arrive = vm.timeMode == TimeMode.arriveBy && target != null;
      final label = target == null ? '' : hm(target);
      return _StateBlock(
        illustration: _Illustration.empty(label: arrive ? label : ''),
        overline: 'Sin opciones',
        title: arrive
            ? 'Nada te deja a tiempo a las $label'
            : 'No encontramos opciones para este viaje',
        message:
            'Con tu caminata máxima de ${vm.maxWalkMin} min no encontramos transporte que cumpla tu horario.',
        actions: [
          if (arrive)
            YgButton(
              key: const ValueKey('alternatives_try_later'),
              label: 'Probar llegar a las ${hm(target.add(const Duration(minutes: 15)))}',
              expand: true,
              onPressed: () {
                vm.setTargetTime(target.add(const Duration(minutes: 15)));
                _retry();
              },
            ),
          YgButton(
            key: const ValueKey('alternatives_more_walk'),
            label: 'Permitir más caminata · ${vm.maxWalkMin + 5} min',
            variant: YgButtonVariant.secondary,
            expand: true,
            onPressed: () {
              vm.setMaxWalkMin(vm.maxWalkMin + 5);
              _retry();
            },
          ),
        ],
      );
    }
    final code = vm.state.error?.code;
    final (overline, title, message) = switch (ux) {
      UxState.offline => (
        'Sin conexión',
        'No pudimos calcular tu viaje',
        'Sin conexión no podemos consultar rutas. No vamos a inventar horarios: revisa tu conexión e inténtalo de nuevo.',
      ),
      UxState.stale || UxState.degraded => (
        'Información insuficiente',
        'No pudimos calcular tu viaje',
        'Las fuentes no entregaron datos suficientes. No vamos a inventar horarios: inténtalo de nuevo en unos segundos.',
      ),
      _ => (
        'Error del servicio de rutas',
        'No pudimos calcular tu viaje',
        'El proveedor no respondió a tiempo. No vamos a inventar horarios: inténtalo de nuevo en unos segundos.',
      ),
    };
    return _StateBlock(
      illustration: const _Illustration.error(),
      overline: overline,
      overlineColor: YgColors.clay,
      title: title,
      message: message,
      footnote: code == null ? null : 'Código $code',
      actions: [
        Row(
          children: [
            Expanded(
              child: YgButton(
                key: const ValueKey('alternatives_retry'),
                label: 'Reintentar',
                icon: YgIcons.reintentar,
                expand: true,
                onPressed: _retry,
              ),
            ),
            const SizedBox(width: 8),
            YgButton(
              label: 'Cambiar viaje',
              variant: YgButtonVariant.secondary,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }
}

class _Peek extends StatelessWidget {
  const _Peek({
    required this.option,
    required this.times,
    required this.onContinue,
  });

  final JourneyOption option;
  final OptionTimes times;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final transit = option.legs.where((l) => !isWalkLeg(l)).toList();
    final headline = times.departure == null
        ? '${option.durationMin} min en total'
        : 'Sal ${hm(times.departure!)}'
              '${times.arrivalText == null ? '' : ' · llegas ${times.arrivalText}'}';
    return SheetPeekRow(
      children: [
        if (transit.isNotEmpty)
          TransitLegBadge(transit.first.durationMin)
        else
          const YgTile(icon: YgIcons.bus, size: 28, iconSize: 15, radius: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: YgText.secondary.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: YgColors.text,
                ),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PlannerStatusLabel(
                    option.dataQuality,
                    suffix: option.hasReliability
                        ? ' · fiabilidad ${option.reliabilityScore}'
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        YgButton(
          label: 'Continuar',
          size: YgButtonSize.sm,
          onPressed: onContinue,
        ),
      ],
    );
  }
}

/// `.alt`: tarjeta de opción con composición, hora, fiabilidad y estado.
class _AltCard extends StatelessWidget {
  const _AltCard({
    required this.option,
    required this.times,
    required this.recommended,
    required this.selected,
    required this.onTap,
    required this.onSteps,
  });

  final JourneyOption option;
  final OptionTimes times;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSteps;

  List<Widget> _legs() {
    final out = <Widget>[];
    for (final leg in option.legs) {
      if (out.isNotEmpty) {
        out.add(
          const YgIcon(
            YgIcons.chevronDerecha,
            size: 12,
            color: YgColors.text3,
          ),
        );
      }
      out.add(
        isWalkLeg(leg)
            ? WalkLegChip(leg.durationMin)
            : TransitLegBadge(leg.durationMin),
      );
    }
    return out;
  }

  List<YgCompSegment> _segments() => [
    for (final leg in option.legs)
      YgCompSegment(
        isWalkLeg(leg) ? YgCompKind.walk : YgCompKind.bus,
        math.max(1, leg.durationMin).toDouble(),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final legs = _legs();
    final segments = _segments();
    final transfers = option.transfers == 0
        ? 'Sin transbordos'
        : '${option.transfers} ${option.transfers == 1 ? 'transbordo' : 'transbordos'}';
    final dot = Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: YgColors.muted,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    final timeStyle = YgText.display.copyWith(
      fontSize: 24,
      letterSpacing: -.96,
    );
    final reduce = YgMotionScope.reduced(context);
    final card = YgCard(
      selected: selected,
      onTap: onTap,
      semanticLabel:
          '${recommended ? 'Recomendada. ' : ''}${option.durationMin} minutos, '
          '${option.walkMin} min a pie, $transfers',
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: legs,
                ),
              ),
              if (recommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: YgColors.aloe,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'RECOMENDADA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                      color: YgColors.moss,
                      height: 1.2,
                    ),
                  ),
                ),
              if (selected) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Ver paso a paso',
                  child: YgPressable(
                    onTap: onSteps,
                    semanticLabel: 'Ver paso a paso',
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: YgColors.fill,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: YgIcon(
                          YgIcons.lista,
                          size: 15,
                          color: YgColors.moss,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (times.departure != null) ...[
                  Text(hm(times.departure!), style: timeStyle),
                  if (times.arrivalText != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '→',
                      style: YgText.secondary.copyWith(
                        fontSize: 14,
                        color: YgColors.text3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      times.arrivalText!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: YgColors.text2,
                      ),
                    ),
                  ],
                ] else
                  Text('${option.durationMin} min', style: timeStyle),
                const Spacer(),
                if (option.hasReliability) RelBars(option.reliabilityScore),
              ],
            ),
          ),
          if (segments.isNotEmpty) YgCompBar(segments: segments),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (times.departure != null)
                  Text('${option.durationMin} min', style: YgText.meta),
                if (times.departure != null) dot,
                Text('${option.walkMin} min a pie', style: YgText.meta),
                dot,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(transfers, style: YgText.meta),
                    const SizedBox(width: 8),
                    dot,
                    const SizedBox(width: 8),
                    PlannerStatusLabel(option.dataQuality),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? -2.0 : 0.0),
      duration: reduce ? YgMotion.reduced : const Duration(milliseconds: 300),
      curve: YgMotion.tapCurve,
      builder: (context, dy, child) =>
          Transform.translate(offset: Offset(0, dy), child: child),
      child: card,
    );
  }
}

// ---------------------------------------------------------------------------
// Estados (error / sin resultados) con ilustración animada del prototipo.
// ---------------------------------------------------------------------------

class _StateBlock extends StatelessWidget {
  const _StateBlock({
    required this.illustration,
    required this.overline,
    required this.title,
    required this.message,
    required this.actions,
    this.overlineColor,
    this.footnote,
  });

  final Widget illustration;
  final String overline;
  final Color? overlineColor;
  final String title;
  final String message;
  final List<Widget> actions;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: YgStagger(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: illustration,
          ),
          YgOverline(overline, color: overlineColor),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(title, style: YgText.title2),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message,
              style: YgText.body.copyWith(fontSize: 14, color: YgColors.text2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  actions[i],
                ],
              ],
            ),
          ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                footnote!,
                style: YgText.meta.copyWith(color: YgColors.text3),
              ),
            ),
        ],
      ),
    );
  }
}

/// `.ill`: caja de 120 con ilustración flotante en 3D (`ifloat`).
class _Illustration extends StatelessWidget {
  const _Illustration.error() : label = null, error = true;

  const _Illustration.empty({required String this.label}) : error = false;

  final bool error;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final art = error
        ? const SizedBox(
            width: 280,
            height: 110,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(size: Size(280, 110), painter: _ErrorArtPainter()),
                Positioned(left: 114, top: 21, child: _WobbleBus()),
              ],
            ),
          )
        : SizedBox(
            width: 300,
            height: 110,
            child: CustomPaint(painter: _EmptyArtPainter(label ?? '')),
          );
    return Container(
      height: 120,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: YgColors.page,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: YgLoop(
          duration: const Duration(milliseconds: 2500),
          reverse: true,
          builder: (context, t, child) {
            final e = Curves.easeInOut.transform(t);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, -1 / 400)
                ..translateByDouble(0.0, -3 * e, 0.0, 1.0)
                ..rotateX(8 * e * math.pi / 180)
                ..rotateY(-8 * e * math.pi / 180),
              child: child,
            );
          },
          child: art,
        ),
      ),
    );
  }
}

class _WobbleBus extends StatelessWidget {
  const _WobbleBus();

  @override
  Widget build(BuildContext context) {
    // `wob`: 0 → -4° (30 %) → 3° (60 %) → 0.
    return YgLoop(
      duration: const Duration(milliseconds: 2400),
      builder: (context, t, child) {
        final deg = t < .3
            ? -4 * (t / .3)
            : (t < .6 ? -4 + 7 * ((t - .3) / .3) : 3 * (1 - (t - .6) / .4));
        return Transform.rotate(angle: deg * math.pi / 180, child: child);
      },
      child: SizedBox(
        width: 52,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 8,
              child: YgDashedBox(
                color: YgColors.clay,
                radius: 14,
                minWidth: 52,
                minHeight: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: const Text(
                  '≈ —',
                  style: TextStyle(
                    color: YgColors.clay,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: -8,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: YgColors.clay,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _dots(Canvas canvas, Path path, Paint paint, double gap) {
  for (final m in path.computeMetrics()) {
    for (var d = 0.0; d <= m.length; d += gap) {
      canvas.drawCircle(m.getTangentForOffset(d)!.position, 2.5, paint);
    }
  }
}

class _ErrorArtPainter extends CustomPainter {
  const _ErrorArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = YgColors.cypress;
    canvas.drawPath(
      Path()
        ..moveTo(24, 82)
        ..cubicTo(70, 82, 80, 46, 118, 46),
      line,
    );
    _dots(
      canvas,
      Path()
        ..moveTo(162, 46)
        ..cubicTo(200, 46, 210, 82, 256, 82),
      Paint()..color = YgColors.muted,
      11,
    );
    canvas.drawPath(
      Path()
        ..moveTo(126, 34)
        ..lineTo(134, 46)
        ..lineTo(127, 54)
        ..lineTo(138, 66),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = YgColors.clay,
    );
    canvas.drawCircle(const Offset(24, 82), 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(24, 82),
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = YgColors.moss,
    );
    canvas.drawCircle(
      const Offset(256, 82),
      7,
      Paint()..color = YgColors.aloe,
    );
    canvas.drawCircle(
      const Offset(256, 82),
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _EmptyArtPainter extends CustomPainter {
  const _EmptyArtPainter(this.label);

  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      const Offset(20, 80),
      const Offset(280, 80),
      Paint()
        ..color = YgColors.handle
        ..strokeWidth = 1.5,
    );
    for (final x in [34.0, 92.0, 150.0]) {
      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 44, 46, 24),
        const Radius.circular(12),
      );
      canvas.drawRRect(rr, Paint()..color = Colors.white);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = YgColors.muted;
      for (final m in (Path()..addRRect(rr)).computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 8) {
          canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), stroke);
        }
      }
      canvas.drawCircle(
        Offset(x + 23, 56),
        3,
        Paint()..color = YgColors.muted,
      );
    }
    final dash = Paint()
      ..strokeWidth = 2
      ..color = YgColors.moss;
    for (var y = 26.0; y < 80; y += 8) {
      canvas.drawLine(Offset(236, y), Offset(236, math.min(y + 4, 80)), dash);
    }
    canvas.drawPath(
      Path()
        ..moveTo(236, 26)
        ..relativeLineTo(22, 0)
        ..relativeLineTo(-5, 6)
        ..relativeLineTo(5, 6)
        ..relativeLineTo(-22, 0)
        ..close(),
      Paint()..color = YgColors.moss,
    );
    if (label.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 11, color: YgColors.text3),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(236 - tp.width / 2, 98 - tp.height * .8));
    }
  }

  @override
  bool shouldRepaint(covariant _EmptyArtPainter old) => old.label != label;
}
