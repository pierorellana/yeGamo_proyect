import 'dart:math' as math;

import '../../../shared/location/location_service.dart';
import '../../planner/models/planner_models.dart';

enum LegAdvice {
  /// La posición está a menos de [LegProgressAdvisor.arrivalRadiusM] del final del tramo.
  nearEnd,

  /// Sigue en el tramo.
  onTrack,

  /// Tramo a pie y la posición se alejó del segmento origen→destino.
  offRoute,

  /// El tramo no trae coordenadas: no hay evidencia para decidir nada.
  unknown,
}

class LegAssessment {
  const LegAssessment(this.advice, {this.distanceToEndM, this.offRouteM});

  final LegAdvice advice;
  final double? distanceToEndM;

  /// Distancia al segmento del tramo (solo se calcula en tramos a pie).
  final double? offRouteM;
}

/// Evalúa, con la ubicación real del usuario, si terminó el tramo actual o se
/// desvió. Solo usa las coordenadas que entrega el plan: no hay geometría de
/// recorrido para los tramos en transporte, así que el desvío **solo** se evalúa
/// en tramos a pie (recta origen→destino) y en transporte la app ofrece la
/// confirmación manual en vez de asumir que el evento ocurrió.
class LegProgressAdvisor {
  const LegProgressAdvisor({
    this.arrivalRadiusM = 60,
    this.offRouteRadiusM = 200,
  });

  final double arrivalRadiusM;
  final double offRouteRadiusM;

  LegAssessment assess(GeoCoordinate position, JourneyLeg leg) {
    final from = leg.from;
    final to = leg.to;
    if (to == null) return const LegAssessment(LegAdvice.unknown);
    final here = JourneyPoint(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final toEnd = distanceM(here, to);
    if (toEnd <= arrivalRadiusM) {
      return LegAssessment(LegAdvice.nearEnd, distanceToEndM: toEnd);
    }
    final isWalk = leg.mode.toUpperCase() == 'WALK';
    if (isWalk && from != null) {
      final off = distanceToSegmentM(here, from, to);
      if (off > offRouteRadiusM) {
        return LegAssessment(LegAdvice.offRoute, distanceToEndM: toEnd, offRouteM: off);
      }
      return LegAssessment(LegAdvice.onTrack, distanceToEndM: toEnd, offRouteM: off);
    }
    return LegAssessment(LegAdvice.onTrack, distanceToEndM: toEnd);
  }

  /// Distancia haversine en metros.
  static double distanceM(JourneyPoint a, JourneyPoint b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  /// Distancia de [p] al segmento [a]→[b] (proyección equirrectangular local).
  static double distanceToSegmentM(JourneyPoint p, JourneyPoint a, JourneyPoint b) {
    final lat0 = _rad((a.latitude + b.latitude) / 2);
    double x(JourneyPoint q) => _rad(q.longitude) * math.cos(lat0) * 6371000.0;
    double y(JourneyPoint q) => _rad(q.latitude) * 6371000.0;
    final ax = x(a), ay = y(a), bx = x(b), by = y(b), px = x(p), py = y(p);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0
        ? 0.0
        : (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt(math.pow(px - cx, 2) + math.pow(py - cy, 2));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
