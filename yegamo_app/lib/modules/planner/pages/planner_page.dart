import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/navigation/app_routes.dart';
import '../../search/models/search_models.dart';
import '../models/planner_models.dart';
import '../providers/planner_view_model.dart';
import '../widgets/planner_common.dart';

/// 07 · Planificar: origen/destino, cuándo, preferencia y margen.
class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;

  /// 0 = hoy, 1 = mañana.
  int _day = 0;
  int _minutes = 0;
  String? _inputError;
  JourneyPoint? _argumentDestination;
  String? _argumentDestinationLabel;
  bool _routeArgumentsRead = false;

  static const _margins = [0, 5, 10, 15];

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController()..addListener(_refresh);
    _destinationController = TextEditingController()
      ..addListener(_onDestinationChanged);
    final vm = context.read<PlannerViewModel>();
    final now = DateTime.now();
    final saved = vm.targetTime;
    if (saved != null && saved.isAfter(now)) {
      _day = sameDay(saved, now) ? 0 : 1;
      _minutes = saved.hour * 60 + saved.minute;
    } else {
      final t = now.add(const Duration(minutes: 30));
      final m = t.hour * 60 + t.minute;
      _minutes = ((m + 4) ~/ 5 * 5) % 1440;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgumentsRead) return;
    _routeArgumentsRead = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is! PlaceResult) return;
    _argumentDestination = JourneyPoint(
      latitude: arguments.latitude,
      longitude: arguments.longitude,
    );
    _argumentDestinationLabel = arguments.name;
    _destinationController.text = arguments.name;
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onDestinationChanged() {
    if (_argumentDestinationLabel != _destinationController.text) {
      _argumentDestination = null;
    }
    _refresh();
  }

  DateTime get _target {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day + _day);
    return base.add(Duration(minutes: _minutes));
  }

  JourneyPoint? _parse(String value) {
    final values = value
        .split(',')
        .map((part) => double.tryParse(part.trim()))
        .toList();
    if (values.length != 2 || values.any((part) => part == null)) return null;
    return JourneyPoint(latitude: values[0]!, longitude: values[1]!);
  }

  Future<void> _calculate() async {
    final origin = _parse(_originController.text);
    final destination =
        _parse(_destinationController.text) ?? _argumentDestination;
    if (origin == null || destination == null) {
      setState(
        () => _inputError = 'Indica origen y destino como latitud, longitud.',
      );
      return;
    }
    setState(() => _inputError = null);
    final vm = context.read<PlannerViewModel>();
    vm.setPoints(origin: origin, destination: destination);
    vm.setTargetTime(vm.timeMode == TimeMode.leaveNow ? null : _target);
    Navigator.of(context).pushNamed(AppRoutes.loading);
    await vm.calculate();
    if (!mounted) return;
    if (vm.state.phase == PlannerPhase.cancelled) return;
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(AppRoutes.alternatives);
  }

  void _swap() {
    final o = _originController.text;
    _originController.text = _destinationController.text;
    _destinationController.text = o;
  }

  void _shift(int delta) {
    setState(() => _minutes = (_minutes + delta) % 1440);
    context.read<PlannerViewModel>().setTargetTime(_target);
  }

  void _setDay(int d) {
    setState(() => _day = d);
    context.read<PlannerViewModel>().setTargetTime(_target);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlannerViewModel>();
    final dest = _destinationController.text.trim();
    final summary = plannerSummary(
      mode: vm.timeMode,
      target: _target,
      margin: vm.extraSafetyMarginMin,
      preference: vm.preference,
    );
    return PlannerFlowScaffold(
      step: 1,
      title: 'Planificar',
      subtitle: dest.isEmpty ? 'Origen y destino' : 'Hacia $dest',
      onBack: () => Navigator.of(context).maybePop(),
      mapMode: YgMapMode.planner,
      config: YgSheetConfig.planner,
      controls: false,
      headerBuilder: (context, snap) => const SheetHeadRow(
        child: Text('Planificar viaje', style: YgText.title2),
      ),
      peek: SheetPeekRow(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                YgOverline(dest.isEmpty ? 'Planificar viaje' : 'Hacia $dest'),
                const SizedBox(height: 4),
                Text(summary, style: YgText.title),
              ],
            ),
          ),
          YgButton(
            label: 'Calcular',
            size: YgButtonSize.sm,
            onPressed: _calculate,
          ),
        ],
      ),
      body: (context, snap) => _form(context, vm),
    );
  }

  Widget _form(BuildContext context, PlannerViewModel vm) {
    final arrive = vm.timeMode != TimeMode.leaveNow;
    final target = _target;
    final timeIndex = switch (vm.timeMode) {
      TimeMode.arriveBy => 0,
      TimeMode.departAt => 1,
      TimeMode.leaveNow => 2,
    };
    final marginIndex = _nearestMargin(vm.extraSafetyMarginMin);
    final now = DateTime.now();
    return SheetScroll(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _OriginDestination(
          origin: _originController,
          destination: _destinationController,
          onSwap: _swap,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: YgSegmented(
            key: const ValueKey('planner_time_mode'),
            labels: const ['Llegar a las', 'Salir a las', 'Salir ahora'],
            index: timeIndex,
            onChanged: (i) => vm.setTimeMode(
              const [
                TimeMode.arriveBy,
                TimeMode.departAt,
                TimeMode.leaveNow,
              ][i],
            ),
          ),
        ),
        if (arrive)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    YgIconButton(
                      icon: YgIcons.menos,
                      style: YgIconButtonStyle.secondary,
                      semanticLabel: '5 minutos antes',
                      onPressed: () => _shift(-5 + 1440),
                    ),
                    Column(
                      children: [
                        Text(
                          '${two(_minutes ~/ 60)}:${two(_minutes % 60)}',
                          style: YgText.display.copyWith(
                            fontSize: 44,
                            letterSpacing: -1.76,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _day == 0
                              ? 'Hoy, ${weekdayEs(now)}'
                              : 'Mañana, ${weekdayEs(target)}',
                          style: YgText.meta.copyWith(color: YgColors.text3),
                        ),
                      ],
                    ),
                    YgIconButton(
                      icon: YgIcons.mas,
                      style: YgIconButtonStyle.secondary,
                      semanticLabel: '5 minutos después',
                      onPressed: () => _shift(5),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  YgChip(
                    label: 'Hoy',
                    selected: _day == 0,
                    onTap: () => _setDay(0),
                  ),
                  const SizedBox(width: 8),
                  YgChip(
                    label: 'Mañana',
                    selected: _day == 1,
                    onTap: () => _setDay(1),
                  ),
                ],
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Column(
              children: [
                Text(
                  'Ahora',
                  style: YgText.display.copyWith(
                    fontSize: 44,
                    letterSpacing: -1.76,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Buscamos el próximo transporte desde las ${hm(now)}',
                  textAlign: TextAlign.center,
                  style: YgText.secondary.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: YgOverline('Prefiero'),
          ),
        ),
        Row(
          key: const ValueKey('planner_preferences'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, p) in const [
              (YgIcons.escudo, 'Más confiable', TravelPreference.reliable),
              (
                YgIcons.caminarCompacto,
                'Menos caminata',
                TravelPreference.lessWalking,
              ),
              (
                YgIcons.transbordo,
                'Menos transbordos',
                TravelPreference.fewerTransfers,
              ),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _PrefTile(
                  icon: p.$1,
                  label: p.$2,
                  selected: vm.preference == p.$3,
                  onTap: () => vm.setPreference(
                    vm.preference == p.$3 ? TravelPreference.balanced : p.$3,
                  ),
                ),
              ),
            ],
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: YgOverline('Margen extra'),
          ),
        ),
        YgSegmented(
          key: const ValueKey('planner_margin'),
          labels: const ['0', '+5 min', '+10 min', '+15 min'],
          index: marginIndex,
          onChanged: (i) => vm.setExtraSafetyMarginMin(_margins[i]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Se suma al margen de seguridad según la fiabilidad de cada opción.',
            style: YgText.meta.copyWith(color: YgColors.text3),
          ),
        ),
        if (_inputError != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: YgBanner(
              title: 'Revisa los datos',
              message: _inputError,
              icon: YgIcons.alerta,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: YgButton(
            key: const ValueKey('planner_calculate'),
            label: 'Calcular salida',
            expand: true,
            onPressed: _calculate,
          ),
        ),
      ],
    );
  }

  static int _nearestMargin(int value) {
    var best = 0;
    for (var i = 0; i < _margins.length; i++) {
      if ((_margins[i] - value).abs() < (_margins[best] - value).abs()) {
        best = i;
      }
    }
    return best;
  }
}

/// `.od`: tarjeta origen/destino con campos editables e intercambio.
class _OriginDestination extends StatelessWidget {
  const _OriginDestination({
    required this.origin,
    required this.destination,
    required this.onSwap,
  });

  final TextEditingController origin;
  final TextEditingController destination;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(YgRadius.card),
        border: Border.all(color: YgColors.border),
        boxShadow: YgShadows.card,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OdRow(
                  fieldKey: const ValueKey('planner_origin'),
                  controller: origin,
                  label: 'Desde',
                  dot: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: YgColors.cypress,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: YgColors.cypress.withValues(alpha: .18),
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 42),
                  color: YgColors.divider,
                ),
                _OdRow(
                  fieldKey: const ValueKey('planner_destination'),
                  controller: destination,
                  label: 'Hasta',
                  dot: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: YgColors.moss,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Tooltip(
                message: 'Intercambiar origen y destino',
                child: YgPressable(
                  onTap: onSwap,
                  semanticLabel: 'Intercambiar origen y destino',
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: YgColors.fill,
                      shape: BoxShape.circle,
                    ),
                    child: const YgIcon(
                      YgIcons.intercambiar,
                      size: 18,
                      color: YgColors.moss,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OdRow extends StatelessWidget {
  const _OdRow({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.dot,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final Widget dot;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
        child: Row(
          children: [
            SizedBox(width: 10, child: Center(child: dot)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: YgText.meta.copyWith(
                      fontSize: 11,
                      height: 1.2,
                      color: YgColors.text3,
                    ),
                  ),
                  TextField(
                    key: fieldKey,
                    controller: controller,
                    cursorColor: YgColors.cypress,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-\s]')),
                    ],
                    style: YgText.sub.copyWith(
                      height: 1.3,
                      letterSpacing: -.15,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 2),
                      hintText: 'latitud, longitud',
                      hintStyle: TextStyle(
                        color: YgColors.cedar,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.pref`: mosaico de preferencia con tile y etiqueta.
class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: YgPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: YgMotion.easeOut,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? YgColors.moss : YgColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x142C3424),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YgTile(
                icon: icon,
                tone: selected ? YgTileTone.moss : YgTileTone.normal,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: YgText.secondary.copyWith(
                  fontWeight: FontWeight.w600,
                  color: YgColors.text,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
