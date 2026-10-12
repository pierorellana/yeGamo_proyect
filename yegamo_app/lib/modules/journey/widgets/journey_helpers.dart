import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/models/data_state.dart';
import '../../planner/models/planner_models.dart';
import '../models/journey_models.dart';

/// Tipo de tramo deducido del modo que entrega el plan (sin inventar nada).
enum JourneyLegKind { walk, wait, ride }

JourneyLegKind legKindOf(JourneyLeg leg) {
  final mode = leg.mode.toLowerCase();
  if (mode.contains('walk') || mode.contains('camin') || mode.contains('pie')) {
    return JourneyLegKind.walk;
  }
  if (mode.contains('wait') || mode.contains('esper')) {
    return JourneyLegKind.wait;
  }
  return JourneyLegKind.ride;
}

/// Opción del plan que corresponde al viaje activo, si el plan sigue cargado.
JourneyOption? optionFor(JourneyPlan? plan, ActiveJourney journey) {
  if (plan == null || plan.planId != journey.planId) return null;
  for (final option in plan.options) {
    if (option.id == journey.optionId) return option;
  }
  return null;
}

/// Tramo en curso derivado del progreso real (paso actual / pasos totales).
int? currentLegIndex(ActiveJourney journey, JourneyOption? option) {
  final legs = option?.legs ?? const <JourneyLeg>[];
  if (legs.isEmpty || journey.totalSteps <= 0) return null;
  if (journey.currentStep >= journey.totalSteps) return legs.length - 1;
  final index = (journey.currentStep / journey.totalSteps * legs.length).floor();
  return index.clamp(0, legs.length - 1).toInt();
}

/// Fase del viaje para el mapa; `null` si el plan no trae tramos.
YgTripPhase? tripPhaseFor(ActiveJourney journey, JourneyOption? option) {
  final index = currentLegIndex(journey, option);
  if (index == null || option == null) return null;
  if (journey.status == JourneyStatus.arrived ||
      journey.currentStep >= journey.totalSteps) {
    return YgTripPhase.done;
  }
  final legs = option.legs;
  return switch (legKindOf(legs[index])) {
    JourneyLegKind.wait => YgTripPhase.wait,
    JourneyLegKind.ride => YgTripPhase.ride,
    JourneyLegKind.walk =>
      legs.take(index).any((l) => legKindOf(l) == JourneyLegKind.ride)
          ? YgTripPhase.walk2
          : YgTripPhase.walk,
  };
}

YgMapDataState mapDataStateFor(UxState state) => switch (state) {
  UxState.ok || UxState.loading => YgMapDataState.ok,
  UxState.stale => YgMapDataState.stale,
  UxState.degraded => YgMapDataState.degraded,
  UxState.offline => YgMapDataState.offline,
  UxState.error => YgMapDataState.error,
  UxState.empty || UxState.noCoverage => YgMapDataState.empty,
  UxState.permission => YgMapDataState.permission,
};

/// Vista del mapa en modo viaje. Sin tramos en el plan no se fuerza ninguna
/// fase: el mapa conserva su encuadre base.
YgMapView activeMapView({
  required ActiveJourney journey,
  required JourneyOption? option,
  required UxState uxState,
  required double visibleBottom,
}) {
  final phase = tripPhaseFor(journey, option);
  final progress = journey.totalSteps <= 0
      ? 0.0
      : (journey.currentStep / journey.totalSteps).clamp(0.0, 1.0).toDouble();
  return YgMapView(
    mode: YgMapMode.active,
    phase: phase ?? const YgMapView().phase,
    sp: phase == YgTripPhase.ride ? 6 * progress : 0,
    ds: mapDataStateFor(uxState),
    visibleBottom: visibleBottom,
  );
}

String formatClock(DateTime value) {
  final local = value.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Ventana de llegada del plan (`08:14–08:20`) cuando existe.
String? arrivalWindowText(JourneyPlan? plan, ActiveJourney journey) {
  if (plan == null || plan.planId != journey.planId) return null;
  final from = plan.arrivalFrom;
  final to = plan.arrivalTo;
  if (from == null || to == null) return null;
  return '${formatClock(from)}–${formatClock(to)}';
}

/// Etiqueta de calidad de datos. «EN VIVO» solo con fuente autorizada y
/// timestamp (misma regla que `DataQualityBadge`).
String dataQualityLabel(ActiveJourney journey) {
  final live =
      journey.dataState == DataState.current &&
      journey.liveVehicle &&
      journey.sourceAuthorized &&
      journey.observedAt != null;
  if (live) return 'EN VIVO';
  return switch (journey.dataState) {
    DataState.current => 'ACTUAL',
    DataState.stale => 'DESACTUALIZADO',
    DataState.degraded => 'DEGRADADO',
    DataState.offlineCache => 'OFFLINE_CACHE',
    DataState.unavailable => 'NO DISPONIBLE',
  };
}

/// Chip de calidad de datos con el estilo `.chip.glass` del prototipo.
class JourneyQualityChip extends StatelessWidget {
  const JourneyQualityChip({super.key, required this.journey});

  final ActiveJourney journey;

  @override
  Widget build(BuildContext context) {
    final label = dataQualityLabel(journey);
    final live = label == 'EN VIVO';
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: live ? YgColors.cypress : Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(18),
            boxShadow: YgShadows.glass,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: live ? Colors.white : YgColors.cypress,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: live ? Colors.white : YgColors.moss,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mensaje de calidad (equivale a la franja de estado anterior).
String? journeyQualityMessage(UxState state) => switch (state) {
  UxState.offline => 'Sin conexión: mostramos el último progreso guardado localmente.',
  UxState.stale => 'Datos posiblemente desactualizados. Revisa antes de continuar.',
  UxState.degraded => 'Calidad degradada: no mostramos LIVE ni ETA inventada.',
  UxState.permission => 'Permiso requerido para actualizar con ubicación precisa.',
  _ => null,
};
