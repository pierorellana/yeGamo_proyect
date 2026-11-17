import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/location/location_service.dart';
import '../../../shared/map/yg_map_controls.dart';
import '../../../shared/map/yg_map_host.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/navigation/app_routes.dart';
import '../../../shared/widgets/data_quality_badge.dart';
import '../../../shared/widgets/remote_state_view.dart';
import '../../planner/models/planner_models.dart';
import '../../planner/providers/planner_view_model.dart';
import '../models/journey_models.dart';
import '../services/leg_progress_advisor.dart';
import '../../../shared/map/route_overlay.dart';
import '../providers/journey_view_model.dart';
import '../widgets/active_journey_widgets.dart';
import '../widgets/arrival_widgets.dart';
import '../widgets/get_off_widgets.dart';
import '../widgets/journey_helpers.dart';

class StepByStepPage extends StatelessWidget {
  const StepByStepPage({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlannerViewModel>().state.plan;
    final option = plan?.options.isNotEmpty == true
        ? plan!.options.first
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paso a paso'),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: plan == null || option == null
            ? const RemoteStateView(state: UxState.empty)
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tu recorrido',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      DataQualityBadge(dataState: option.dataQuality.dataState),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sigue cada tramo. La información en tiempo real solo aparece con una fuente autorizada y timestamp reciente.',
                  ),
                  const SizedBox(height: 20),
                  for (var index = 0; index < option.legs.length; index++)
                    _JourneyLegTile(index: index, leg: option.legs[index]),
                  if (option.legs.isEmpty)
                    const YgCard(
                      child: Text(
                        'No hay instrucciones disponibles para este plan.',
                      ),
                    ),
                  const SizedBox(height: 20),
                  YgPrimaryButton(
                    key: const ValueKey('journey_start'),
                    label: 'Iniciar viaje',
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.activeJourney,
                      arguments: <String, String>{
                        'planId': plan.planId,
                        'optionId': option.id,
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _JourneyLegTile extends StatelessWidget {
  const _JourneyLegTile({required this.index, required this.leg});

  final int index;
  final JourneyLeg leg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: 'Paso ${index + 1}: ${leg.mode}, ${leg.durationMin} minutos',
        container: true,
        child: YgCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(child: Text('${index + 1}')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leg.mode,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${leg.durationMin} min'),
                    for (final instruction in leg.instructions)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(instruction),
                      ),
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

class ActiveJourneyPage extends StatefulWidget {
  const ActiveJourneyPage({super.key});

  @override
  State<ActiveJourneyPage> createState() => _ActiveJourneyPageState();
}

class _ActiveJourneyPageState extends State<ActiveJourneyPage> {
  bool _startedFromRoute = false;
  double _sheetHeight = YgSheetConfig.active.min;
  double _sheetBottom = YgSheetConfig.active.bottom;
  bool _fit = false;
  DateTime? _arrivedAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedFromRoute) return;
    _startedFromRoute = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map &&
        arguments['planId'] is String &&
        arguments['optionId'] is String) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final planner = context.read<PlannerViewModel>();
        final planId = arguments['planId'] as String;
        final optionId = arguments['optionId'] as String;
        final plan = planner.state.plan;
        context.read<JourneyViewModel>().start(
          planId,
          optionId,
          option: plan?.planId == planId
              ? plan!.options.where((o) => o.id == optionId).firstOrNull
              : null,
        );
      });
    }
  }

  Future<void> _confirmTerminal({required bool finish}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(finish ? '¿Finalizar viaje?' : '¿Cancelar viaje?'),
        content: Text(
          finish
              ? 'Marcaremos el viaje como terminado.'
              : 'Se cancelará el viaje activo. Puedes iniciar otro después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(finish ? 'Finalizar' : 'Cancelar viaje'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final vm = context.read<JourneyViewModel>();
    if (finish) {
      await vm.finish();
    } else {
      await vm.cancel();
    }
    if (!mounted) return;
    if (vm.state.journey?.isTerminal == true) {
      final navigator = Navigator.of(context);
      if (finish) {
        navigator.popUntil((route) => route.isFirst);
      } else {
        navigator.maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<JourneyViewModel>();
    final plan = context.watch<PlannerViewModel>().state.plan;
    final journey = vm.state.journey;
    if (journey == null) return _buildEmpty(vm);
    final option = optionFor(plan, journey);
    if (journey.status == JourneyStatus.arrived) {
      _arrivedAt ??= DateTime.now();
      return _buildArrived(vm, journey, plan, option);
    }
    return _buildActive(vm, journey, plan, option);
  }

  Widget _buildEmpty(JourneyViewModel vm) {
    return YgMapScaffold(
      body: YgBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  YgSize.topbarY + 56,
                  16,
                  24,
                ),
                child: ListView(
                  children: [
                    RemoteStateView(state: vm.state.uxState, onRetry: null),
                    if (vm.state.error != null) ...[
                      const SizedBox(height: 12),
                      YgButton(
                        label: 'Volver al plan',
                        variant: YgButtonVariant.secondary,
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            YgTopBar(
              onBack: () => Navigator.of(context).maybePop(),
              title: 'Viaje activo',
            ),
          ],
        ),
      ),
    );
  }

  YgMapScope? _routeScope;
  String _routeKey = '';

  @override
  void dispose() {
    final scope = _routeScope;
    if (scope != null) Future<void>.microtask(scope.clearRoute);
    super.dispose();
  }

  /// Dibuja en el mapa el recorrido real del viaje (extremos y tramos a pie).
  void _publishRoute(JourneyOption? option) {
    final scope = _routeScope ??= context.read<YgMapScope>();
    final overlay = RouteOverlay.forOption(option);
    if (overlay.key == _routeKey) return;
    _routeKey = overlay.key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) scope.showRoute(overlay.points, overlay.lines);
    });
  }

  Widget _buildActive(
    JourneyViewModel vm,
    ActiveJourney journey,
    JourneyPlan? plan,
    JourneyOption? option,
  ) {
    _publishRoute(option);
    final visibleBottom = 844 - _sheetBottom - _sheetHeight - 16;
    final legIndex = currentLegIndex(journey, option);
    final phase = tripPhaseFor(journey, option);
    final leg = legIndex == null ? null : option!.legs[legIndex];
    final legKind = leg == null ? null : legKindOf(leg);
    final instruction =
        leg != null && leg.instructions.isNotEmpty
            ? leg.instructions.first
            : journey.instruction;
    final icon = switch (legKind) {
      JourneyLegKind.walk =>
        phase == YgTripPhase.done ? YgIcons.bandera : YgIcons.caminar,
      JourneyLegKind.wait => YgIcons.reloj,
      JourneyLegKind.ride => YgIcons.bus,
      null => YgIcons.navegar,
    };
    final showInstruction = instruction != null;
    final title = instruction ?? '';
    const String? sub = null;
    final pre = journey.totalLegs > 0
        ? 'Paso ${(journey.currentLegIndex + 1).clamp(1, journey.totalLegs)} de ${journey.totalLegs}'
        : null;
    final message = journeyQualityMessage(vm.state.uxState);
    final view = activeMapView(
      journey: journey,
      option: option,
      uxState: vm.state.uxState,
      visibleBottom: visibleBottom,
    );
    return YgMapBinding(
      view: YgMapView(
        mode: view.mode,
        phase: view.phase,
        sp: view.sp,
        ds: view.ds,
        fit: _fit,
        visibleBottom: visibleBottom,
      ),
      child: YgMapScaffold(
        body: YgEnter(
          kind: YgEnterKind.fade,
          child: Stack(
            children: [
              if (showInstruction)
                Positioned(
                  top: YgSize.topbarY,
                  left: 16,
                  right: 16,
                  child: JourneyInstructionCard(
                    icon: icon,
                    walkStyle:
                        legKind == JourneyLegKind.walk ||
                        phase == YgTripPhase.done,
                    pre: pre,
                    title: title,
                    sub: sub,
                  ),
                ),
              Positioned(
                top: showInstruction ? 140 : YgSize.topbarY,
                left: 16,
                right: 16,
                child: YgEnter(
                  kind: YgEnterKind.fade,
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (journey.status == JourneyStatus.getOffAlert)
                            JourneyGlassChip(
                              key: const ValueKey('journey_open_get_off'),
                              label: 'Ver alerta de bajada',
                              icon: YgIcons.campana,
                              onTap: () =>
                                  Navigator.of(context)
                                      .pushNamed(AppRoutes.getOffAlert),
                            )
                          else
                            JourneyGlassChip(
                              key: const ValueKey('journey_next_step'),
                              label: 'Siguiente paso',
                              icon: YgIcons.acelerar,
                              onTap: vm.loading
                                  ? null
                                  : () => _updateStep(context, journey),
                            ),
                          JourneyGlassChip(
                            key: const ValueKey('journey_update_location'),
                            label: 'Mi ubicación',
                            icon: YgIcons.navegar,
                            onTap: vm.loading
                                ? null
                                : () => _updateWithLocation(journey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: JourneyQualityChip(journey: journey),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 8),
                        YgBanner(title: message),
                      ],
                    ],
                  ),
                ),
              ),
              YgMapControls(
                sheetHeight: _sheetHeight,
                sheetBottom: _sheetBottom,
                fitSelected: _fit,
                onFit: () => setState(() => _fit = !_fit),
              ),
              YgSheet(
                config: YgSheetConfig.active,
                initial: YgSnap.min,
                peek: const SizedBox.shrink(),
                handleLabel: 'Cambiar altura del panel del viaje',
                onHeightChanged: (h, b) {
                  if (!mounted) return;
                  if ((h - _sheetHeight).abs() < .5 && b == _sheetBottom) {
                    return;
                  }
                  setState(() {
                    _sheetHeight = h;
                    _sheetBottom = b;
                  });
                },
                header: JourneySheetHeader(
                  journey: journey,
                  windowText: arrivalWindowText(plan, journey),
                ),
                body: (context, snap) => _ActiveSheetBody(
                  journey: journey,
                  option: option,
                  legIndex: legIndex,
                  showAll: snap == YgSnap.max,
                  busy: vm.loading,
                  onCancel: () => _confirmTerminal(finish: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArrived(
    JourneyViewModel vm,
    ActiveJourney journey,
    JourneyPlan? plan,
    JourneyOption? option,
  ) {
    final arrivedAt = _arrivedAt ?? DateTime.now();
    final sameplan = plan?.planId == journey.planId;
    final from = sameplan ? plan?.arrivalFrom : null;
    final to = sameplan ? plan?.arrivalTo : null;
    final inWindow =
        from != null &&
        to != null &&
        !arrivedAt.isBefore(from) &&
        !arrivedAt.isAfter(to);
    final windowText = arrivalWindowText(plan, journey);
    return YgMapBinding(
      view: YgMapView(
        mode: YgMapMode.arrived,
        phase: YgTripPhase.done,
        ds: mapDataStateFor(vm.state.uxState),
        visibleBottom: 844 - 492 - 16,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: YgEnter(
          kind: YgEnterKind.fade,
          child: Stack(
            children: [
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                height: 568,
                child: ArrivalSheetSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                        height: 24,
                        child: Center(child: _SheetGrab()),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                          child: YgStagger(
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: ArrivalCoin(),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  'LLEGASTE A TU DESTINO',
                                  style: YgText.overline.copyWith(
                                    color: YgColors.cypress,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  formatClock(arrivedAt),
                                  style: YgText.display.copyWith(
                                    fontSize: 44,
                                    letterSpacing: -1.76,
                                  ),
                                ),
                              ),
                              if (inWindow)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Dentro de tu ventana prevista${windowText == null ? '' : ' ($windowText)'}.',
                                    style: YgText.sub.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color: YgColors.text2,
                                    ),
                                  ),
                                ),
                              if (option != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ArrivalStat(
                                          label: 'Duración prevista',
                                          value: '${option.durationMin} min',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ArrivalStat(
                                          label: 'A pie prevista',
                                          value: '${option.walkMin} min',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00FFFFFF), Color(0xE6FFFFFF)],
                            stops: [0, .4],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            YgButton(
                              key: const ValueKey('journey_finish'),
                              label: 'Listo',
                              size: YgButtonSize.lg,
                              expand: true,
                              onPressed: vm.loading
                                  ? null
                                  : () => _confirmTerminal(finish: true),
                            ),
                            const SizedBox(height: 8),
                            YgButton(
                              key: const ValueKey('journey_back_home'),
                              label: 'Volver al inicio',
                              variant: YgButtonVariant.ghost,
                              size: YgButtonSize.md,
                              expand: true,
                              onPressed: () =>
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateStep(BuildContext context, ActiveJourney journey) async {
    await _advance(context.read<JourneyViewModel>(), journey);
  }

  /// Avanza un tramo. Pasar del último tramo es solo un estado de pantalla
  /// (llegada); el API registra la llegada con `finish`, no con `progress`.
  Future<void> _advance(JourneyViewModel vm, ActiveJourney journey) async {
    final next = journey.currentLegIndex + 1;
    if (next >= journey.totalLegs) {
      vm.markArrived();
      return;
    }
    await vm.updateProgress(JourneyProgress(currentLegIndex: next));
  }

  /// Avanza solo con evidencia: lee la ubicación (con consentimiento), la compara
  /// con el final del tramo y, si no hay prueba suficiente, explica por qué y deja
  /// el avance manual («Siguiente paso»).
  Future<void> _updateWithLocation(ActiveJourney journey) async {
    final consentStore = context.read<LocationConsentStore>();
    final locationService = context.read<LocationService>();
    final vm = context.read<JourneyViewModel>();
    final consent = await consentStore.read();
    if (!mounted) return;
    if (!consent) {
      vm.showPermissionRequired();
      return;
    }
    final position = await locationService.currentPosition();
    if (!mounted) return;
    final leg = journey.currentLeg;
    if (position == null || leg == null) {
      YgToast.show(
        context,
        'No pudimos obtener tu ubicación. Usa «Siguiente paso» cuando llegues.',
      );
      return;
    }
    final assessment = const LegProgressAdvisor().assess(position, leg);
    switch (assessment.advice) {
      case LegAdvice.nearEnd:
        await _advance(vm, journey);
      case LegAdvice.offRoute:
        YgToast.show(
          context,
          'Parece que te alejaste del recorrido a pie (${assessment.offRouteM!.round()} m). Revisa el paso a paso.',
        );
      case LegAdvice.onTrack:
        YgToast.show(
          context,
          'Aún estás a ${assessment.distanceToEndM!.round()} m del final de este tramo. Si ya llegaste, usa «Siguiente paso».',
        );
      case LegAdvice.unknown:
        YgToast.show(
          context,
          'Este tramo no trae coordenadas: confirma tú el avance con «Siguiente paso».',
        );
    }
  }
}

class _SheetGrab extends StatelessWidget {
  const _SheetGrab();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: YgColors.handle,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Cuerpo del panel del viaje: próximas paradas/tramos y cancelar.
class _ActiveSheetBody extends StatelessWidget {
  const _ActiveSheetBody({
    required this.journey,
    required this.option,
    required this.legIndex,
    required this.showAll,
    required this.busy,
    required this.onCancel,
  });

  final ActiveJourney journey;
  final JourneyOption? option;
  final int? legIndex;
  final bool showAll;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final rows = <JourneyStopRow>[];
    final legs = option?.legs ?? const <JourneyLeg>[];
    if (legIndex != null && legs.isNotEmpty) {
      for (var i = 0; i < legs.length; i++) {
        final leg = legs[i];
        final state = i < legIndex!
            ? JourneyStopState.pass
            : i == legIndex!
            ? JourneyStopState.next
            : i == legs.length - 1
            ? JourneyStopState.alight
            : JourneyStopState.none;
        if (!showAll && state == JourneyStopState.pass) continue;
        rows.add(
          JourneyStopRow(
            title: leg.instructions.isNotEmpty
                ? leg.instructions.first
                : leg.mode,
            state: state,
            trailing: '${leg.durationMin} min',
          ),
        );
      }
    }
    final visible = showAll ? rows : rows.take(3).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visible.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('PRÓXIMAS PARADAS', style: YgText.overline),
            ),
            ...visible,
          ],
          const SizedBox(height: 16),
          YgButton(
            key: const ValueKey('journey_cancel'),
            label: 'Cancelar viaje',
            variant: YgButtonVariant.secondary,
            expand: true,
            onPressed: busy ? null : onCancel,
          ),
        ],
      ),
    );
  }
}

class GetOffAlertPage extends StatelessWidget {
  const GetOffAlertPage({super.key});

  @override
  Widget build(BuildContext context) {
    final journey = context.watch<JourneyViewModel>().state.journey;
    final plan = context.watch<PlannerViewModel>().state.plan;
    final option = journey == null ? null : optionFor(plan, journey);
    const stop = 'Prepara tu bajada';
    // Último tramo a pie del plan y llegada estimada, solo si existen.
    JourneyLeg? lastWalk;
    final legs = option?.legs ?? const <JourneyLeg>[];
    if (legs.length > 1 && legKindOf(legs.last) == JourneyLegKind.walk) {
      lastWalk = legs.last;
    }
    final eta =
        journey?.eta != null && journey?.dataState != DataState.unavailable
        ? formatClock(journey!.eta!)
        : null;
    final footParts = <String>[
      if (lastWalk != null) 'Luego camina ${lastWalk.durationMin} min',
      if (eta != null) (lastWalk == null ? 'Llegas ' : 'llegas '),
    ];
    final footText = footParts.join(' · ');
    return YgMapBinding(
      view: YgMapView(
        mode: YgMapMode.getoff,
        phase: YgTripPhase.ride,
        visibleBottom: 844 - 120 - 16,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: YgEnter(
          kind: YgEnterKind.fade,
          child: Stack(
            children: [
              const Positioned.fill(child: GetOffOverlay()),
              Positioned(
                top: YgSize.topbarY,
                left: 16,
                right: 16,
                child: GetOffCard(
                  stop: stop,
                  onAck: () => Navigator.of(context).pop(),
                ),
              ),
              if (footText.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: GetOffFoot(text: footText, emphasis: eta),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
