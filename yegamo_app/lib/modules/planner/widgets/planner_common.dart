import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/map/yg_map_controls.dart';
import '../../../shared/map/yg_map_host.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/widgets/data_quality_badge.dart';
import '../models/planner_models.dart';

// ---------------------------------------------------------------------------
// Formato de horas y textos (todo se deriva de datos reales del plan).
// ---------------------------------------------------------------------------

String two(int n) => n.toString().padLeft(2, '0');

/// `HH:mm` en hora local.
String hm(DateTime d) {
  final l = d.toLocal();
  return '${two(l.hour)}:${two(l.minute)}';
}

String hmRange(DateTime a, DateTime b) {
  final x = hm(a);
  final y = hm(b);
  return x == y ? x : '$x–$y';
}

const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

String weekdayEs(DateTime d) => _weekdays[d.weekday - 1];

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String preferenceLabel(TravelPreference p) => switch (p) {
  TravelPreference.balanced => 'Recomendadas',
  TravelPreference.fastest => 'Más rápida',
  TravelPreference.reliable => 'Más confiable',
  TravelPreference.lessWalking => 'Menos caminata',
  TravelPreference.fewerTransfers => 'Menos transbordos',
};

/// Resumen del viaje (`pl.summary`): modo + hora + margen.
String plannerSummary({
  required TimeMode mode,
  required DateTime? target,
  required int margin,
  required TravelPreference preference,
}) {
  final pref = preference == TravelPreference.balanced
      ? ''
      : ' · ${preferenceLabel(preference).toLowerCase()}';
  if (mode == TimeMode.leaveNow || target == null) {
    return 'Salir ahora$pref';
  }
  final tomorrow = !sameDay(target, DateTime.now());
  final verb = mode == TimeMode.arriveBy ? 'Llegar' : 'Salir';
  return '$verb ${hm(target)}${tomorrow ? ' mañana' : ''} · +$margin min';
}

// ---------------------------------------------------------------------------
// Horas por opción: el API solo entrega la ventana a nivel de plan (para la
// opción recomendada) y, opcionalmente, horas por tramo. Nunca se inventan.
// ---------------------------------------------------------------------------

class OptionTimes {
  const OptionTimes({this.departure, this.arrivalFrom, this.arrivalTo});

  final DateTime? departure;
  final DateTime? arrivalFrom;
  final DateTime? arrivalTo;

  bool get hasArrival => arrivalFrom != null && arrivalTo != null;

  String? get arrivalText =>
      hasArrival ? hmRange(arrivalFrom!, arrivalTo!) : null;
}

OptionTimes timesFor(JourneyPlan plan, JourneyOption option) {
  final isRecommended =
      plan.options.isNotEmpty && plan.options.first.id == option.id;
  final legDep = option.legs.isEmpty ? null : option.legs.first.departureAt;
  final legArr = option.legs.isEmpty ? null : option.legs.last.arrivalAt;
  DateTime? from;
  DateTime? to;
  if (isRecommended && plan.arrivalFrom != null && plan.arrivalTo != null) {
    from = plan.arrivalFrom;
    to = plan.arrivalTo;
  } else if (legArr != null) {
    from = legArr;
    to = legArr;
  }
  return OptionTimes(
    departure: isRecommended ? (plan.recommendedLeaveAt ?? legDep) : legDep,
    arrivalFrom: from,
    arrivalTo: to,
  );
}

// ---------------------------------------------------------------------------
// Estado de datos -> etiquetas del sistema de diseño.
// ---------------------------------------------------------------------------

enum PlannerStatusKind { live, est, sched }

class PlannerStatus {
  const PlannerStatus(this.kind, this.text);

  final PlannerStatusKind kind;
  final String text;
}

/// «En vivo» solo con fuente autorizada, vehículo en vivo y marca de tiempo
/// (misma regla que [DataQualityBadge]).
PlannerStatus statusFor(JourneyDataQuality q) {
  final live =
      q.dataState == DataState.current &&
      q.liveVehicle &&
      q.sourceAuthorized &&
      q.observedAt != null;
  if (live) return const PlannerStatus(PlannerStatusKind.live, 'En vivo');
  return switch (q.dataState) {
    DataState.current => const PlannerStatus(
      PlannerStatusKind.sched,
      'Programado',
    ),
    DataState.stale => const PlannerStatus(
      PlannerStatusKind.est,
      'Desactualizado',
    ),
    DataState.degraded => const PlannerStatus(
      PlannerStatusKind.est,
      'Estimado',
    ),
    DataState.offlineCache => PlannerStatus(
      PlannerStatusKind.sched,
      q.observedAt == null ? 'Guardado' : 'Guardado ${hm(q.observedAt!)}',
    ),
    DataState.unavailable => const PlannerStatus(
      PlannerStatusKind.est,
      'No disponible',
    ),
  };
}

/// Texto semántico idéntico al de [DataQualityBadge] (EN VIVO, DEGRADADO…).
String qualitySemantics(JourneyDataQuality q) => DataQualityBadge(
  dataState: q.dataState,
  liveVehicle: q.liveVehicle,
  sourceAuthorized: q.sourceAuthorized,
  observedAt: q.observedAt,
).label;

class PlannerStatusLabel extends StatelessWidget {
  const PlannerStatusLabel(this.quality, {super.key, this.suffix});

  final JourneyDataQuality quality;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final s = statusFor(quality);
    final text = suffix == null ? s.text : '${s.text}$suffix';
    final label = switch (s.kind) {
      PlannerStatusKind.live => YgLiveLabel(text: text),
      PlannerStatusKind.est => YgEstLabel(text: text),
      PlannerStatusKind.sched => YgSchedLabel(text: text),
    };
    return Semantics(
      label: qualitySemantics(quality),
      excludeSemantics: true,
      child: label,
    );
  }
}

// ---------------------------------------------------------------------------
// Fiabilidad.
// ---------------------------------------------------------------------------

String reliabilityWord(int score) =>
    score >= 80 ? 'alta' : (score >= 60 ? 'media' : 'baja');

/// `.rel`: cuatro barras crecientes + puntuación.
class RelBars extends StatelessWidget {
  const RelBars(this.score, {super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    final bars = score >= 80 ? 4 : (score >= 65 ? 3 : (score >= 50 ? 2 : 1));
    final on = score >= 80
        ? YgColors.cypress
        : (score >= 60 ? YgColors.cedar : YgColors.clay);
    const heights = [4.0, 7.0, 9.5, 12.0];
    return Semantics(
      label: 'Confiabilidad $score de 100',
      value: '$score de 100',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Container(
                    width: 3,
                    height: heights[i],
                    decoration: BoxDecoration(
                      color: i < bars ? on : YgColors.borderStrong,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: YgColors.text,
              fontFeatures: [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tramos.
// ---------------------------------------------------------------------------

bool isWalkLeg(JourneyLeg leg) => leg.mode.toUpperCase() == 'WALK';

/// Insignia de tramo en transporte. El API no entrega el nombre de la línea,
/// así que se muestra el icono y los minutos (no se inventa un número).
class TransitLegBadge extends StatelessWidget {
  const TransitLegBadge(this.minutes, {super.key});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: YgColors.moss,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const YgIcon(YgIcons.bus, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$minutes min',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
              fontFeatures: [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class WalkLegChip extends StatelessWidget {
  const WalkLegChip(this.minutes, {super.key});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const YgIcon(YgIcons.caminar, size: 14, color: YgColors.text2),
        const SizedBox(width: 2),
        Text(
          '$minutes',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: YgColors.text2,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Barra superior de flujo (`.topbar` + `.tpill.fl` con `.fdots`).
// ---------------------------------------------------------------------------

class PlannerFlowBar extends StatelessWidget {
  const PlannerFlowBar({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onTitleTap,
    this.titleSemantics,
  });

  /// Paso del flujo (1–3).
  final int step;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onTitleTap;
  final String? titleSemantics;

  @override
  Widget build(BuildContext context) {
    Widget pill = YgGlass(
      radius: 22,
      height: 44,
      padding: const EdgeInsets.fromLTRB(14, 0, 16, 0),
      blur: 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlowDots(step: step),
          const SizedBox(width: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: YgText.sub.copyWith(fontSize: 14, height: 1.2),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YgText.meta.copyWith(height: 1.2),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTitleTap != null) {
      pill = YgPressable(
        onTap: onTitleTap,
        semanticLabel: titleSemantics ?? title,
        child: pill,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, YgSize.topbarY, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null)
            Tooltip(
              message: 'Volver',
              child: YgIconButton(
                icon: YgIcons.atras,
                semanticLabel: 'Volver',
                onPressed: onBack,
                style: YgIconButtonStyle.secondary,
              ),
            )
          else
            const SizedBox(width: 44),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 236),
              child: pill,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// `.fdots`: tres puntos; el actual se alarga (16 px) y se oscurece.
class FlowDots extends StatelessWidget {
  const FlowDots({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final reduce = YgMotionScope.reduced(context);
    final d = reduce ? YgMotion.reduced : const Duration(milliseconds: 450);
    Widget dot(int i) {
      final cur = step == i;
      final on = step > i;
      return AnimatedContainer(
        duration: d,
        curve: const Cubic(.34, 1.4, .5, 1),
        width: cur ? 16 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: cur
              ? YgColors.moss
              : (on ? YgColors.cypress : YgColors.handle),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(1),
        const SizedBox(width: 3),
        dot(2),
        const SizedBox(width: 3),
        dot(3),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Andamiaje común: barra superior + mapa + panel inferior + controles.
// ---------------------------------------------------------------------------

YgMapDataState mapStateFor(UxState s) => switch (s) {
  UxState.ok || UxState.loading => YgMapDataState.ok,
  UxState.stale => YgMapDataState.stale,
  UxState.degraded => YgMapDataState.degraded,
  UxState.offline => YgMapDataState.offline,
  UxState.error => YgMapDataState.error,
  UxState.empty => YgMapDataState.empty,
  UxState.permission => YgMapDataState.permission,
  UxState.noCoverage => YgMapDataState.empty,
};

class PlannerFlowScaffold extends StatefulWidget {
  const PlannerFlowScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.mapMode,
    required this.config,
    required this.body,
    this.subtitle,
    this.onBack,
    this.onTitleTap,
    this.titleSemantics,
    this.mapAlt = 0,
    this.mapDs = YgMapDataState.ok,
    this.headerBuilder,
    this.headerAtMin = false,
    this.peek,
    this.controls = true,
    this.enter = YgEnterKind.push,
    this.initialSnap = YgSnap.mid,
    this.snapController,
  });

  final int step;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onTitleTap;
  final String? titleSemantics;
  final YgMapMode mapMode;
  final int mapAlt;
  final YgMapDataState mapDs;
  final YgSheetConfig config;
  final Widget Function(BuildContext context, YgSnap snap) body;

  /// Cabecera `.shh` (visible fuera del estado mínimo).
  final Widget Function(BuildContext context, YgSnap snap)? headerBuilder;

  /// Si la cabecera también se muestra en el estado mínimo (Paso a paso).
  final bool headerAtMin;

  /// Contenido `.peek` del estado mínimo.
  final Widget? peek;
  final bool controls;
  final YgEnterKind enter;
  final YgSnap initialSnap;
  final YgSheetController? snapController;

  @override
  State<PlannerFlowScaffold> createState() => _PlannerFlowScaffoldState();
}

class _PlannerFlowScaffoldState extends State<PlannerFlowScaffold> {
  late final YgSheetController _snap;
  late final bool _ownsSnap;
  late final ValueNotifier<({double h, double b})> _sheet;
  bool _fit = false;

  @override
  void initState() {
    super.initState();
    _ownsSnap = widget.snapController == null;
    _snap = widget.snapController ?? YgSheetController(widget.initialSnap);
    _sheet = ValueNotifier((
      h: widget.config.heightFor(_snap.snap),
      b: widget.config.bottom,
    ));
  }

  @override
  void dispose() {
    if (_ownsSnap) _snap.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _onHeight(double h, double b) {
    void apply() {
      if (!mounted) return;
      final cur = _sheet.value;
      if ((cur.h - h).abs() < .5 && cur.b == b) return;
      _sheet.value = (h: h, b: b);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    return YgMapScaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: YgEnter(
              kind: widget.enter,
              child: PlannerFlowBar(
                step: widget.step,
                title: widget.title,
                subtitle: widget.subtitle,
                onBack: widget.onBack,
                onTitleTap: widget.onTitleTap,
                titleSemantics: widget.titleSemantics,
              ),
            ),
          ),
          YgSheet(
            config: widget.config,
            controller: _snap,
            onHeightChanged: _onHeight,
            header: widget.headerBuilder == null
                ? null
                : ListenableBuilder(
                    listenable: _snap,
                    builder: (context, _) =>
                        _snap.snap == YgSnap.min && !widget.headerAtMin
                        ? const SizedBox.shrink()
                        : widget.headerBuilder!(context, _snap.snap),
                  ),
            peek: widget.peek,
            body: widget.body,
          ),
          ValueListenableBuilder(
            valueListenable: _sheet,
            builder: (context, s, _) {
              final screenH = MediaQuery.sizeOf(context).height;
              final vb = screenH - s.b - s.h - 16;
              return YgMapBinding(
                view: YgMapView(
                  mode: widget.mapMode,
                  alt: widget.mapAlt,
                  ds: widget.mapDs,
                  fit: _fit,
                  visibleBottom: vb,
                ),
                child: widget.controls
                    ? YgMapControls(
                        sheetHeight: s.h,
                        sheetBottom: s.b,
                        fitSelected: _fit,
                        onFit: () => setState(() => _fit = !_fit),
                        hidden: s.h >= widget.config.max - 4,
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Cabecera de panel `.shh`: título a la izquierda y acción opcional.
class SheetHeadRow extends StatelessWidget {
  const SheetHeadRow({super.key, required this.child, this.trailing});

  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Fila `.peek` del estado mínimo (padding 0 16 16, mínimo 60).
class SheetPeekRow extends StatelessWidget {
  const SheetPeekRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Zona desplazable del panel (`.sb`) con pie fijo opcional (`.sticky`).
class SheetScroll extends StatelessWidget {
  const SheetScroll({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 32),
    this.sticky,
    this.stagger = true,
    this.spacing = 0,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final Widget? sticky;
  final bool stagger;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final content = stagger
        ? YgStagger(spacing: spacing, children: children)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: padding,
            physics: const ClampingScrollPhysics(),
            child: content,
          ),
        ),
        if (sticky != null)
          Positioned(left: 0, right: 0, bottom: 0, child: sticky!),
      ],
    );
  }
}

/// Pie `.sticky`: degradado blanco bajo el botón principal.
class StickyBar extends StatelessWidget {
  const StickyBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Color(0xF7FFFFFF)],
          stops: [0, .32],
        ),
      ),
      child: child,
    );
  }
}

/// Panel fijo (sin arrastre) con la misma superficie que [YgSheet]; se usa en
/// Cargando.
class PlannerStaticSheet extends StatelessWidget {
  const PlannerStaticSheet({
    super.key,
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(YgRadius.sheet);
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: YgEnter(
        kind: YgEnterKind.fade,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            boxShadow: YgShadows.sheet,
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: r,
                border: Border.all(
                  color: YgColors.moss.withValues(alpha: .08),
                  width: .5,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF7FFFFFF),
                    Color(0xF7FFFFFF),
                    Color(0xF7F6F8F2),
                  ],
                  stops: [0, .55, 1],
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    const SizedBox(
                      height: 24,
                      child: Center(
                        child: SizedBox(
                          width: 36,
                          height: 5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: YgColors.handle,
                              borderRadius: BorderRadius.all(
                                Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
