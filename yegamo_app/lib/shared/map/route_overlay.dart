import '../../modules/planner/models/planner_models.dart';
import '../location/location_service.dart';
import '../models/data_state.dart';
import 'yg_real_map.dart';

class RouteOverlay {
  const RouteOverlay({this.points = const [], this.lines = const []});

  final List<YgMapPoint> points;
  final List<YgMapLine> lines;

  bool get isEmpty => points.isEmpty && lines.isEmpty;

  /// Identificador estable para no republicar lo mismo en cada frame.
  String get key =>
      '${points.map((p) => '${p.id}:${p.latitude},${p.longitude}').join('|')}#${lines.map((l) => l.id).join('|')}';

  /// Construye lo dibujable **solo** con coordenadas reales del plan:
  /// - origen y destino (primer `from` y último `to`);
  /// - los tramos a pie como segmento punteado entre sus extremos reales;
  /// - ningún trazado para transporte: el plan no trae geometría de recorrido
  ///   (ADR-010), así que no se dibuja una ruta que no se conoce.
  factory RouteOverlay.forOption(JourneyOption? option) {
    if (option == null || option.legs.isEmpty) return const RouteOverlay();
    final first = option.legs.first.from;
    final last = option.legs.last.to;
    return RouteOverlay(
      points: [
        if (first != null)
          YgMapPoint(
            id: 'route-origin',
            latitude: first.latitude,
            longitude: first.longitude,
            kind: YgMapPointKind.origin,
            dataState: option.dataQuality.dataState.apiValue,
          ),
        if (last != null)
          YgMapPoint(
            id: 'route-destination',
            latitude: last.latitude,
            longitude: last.longitude,
            kind: YgMapPointKind.destination,
            dataState: option.dataQuality.dataState.apiValue,
          ),
      ],
      lines: [
        for (final (index, leg) in option.legs.indexed)
          if (leg.mode.toUpperCase() == 'WALK' && leg.from != null && leg.to != null)
            YgMapLine(
              id: 'leg-$index',
              coordinates: [
                GeoCoordinate(latitude: leg.from!.latitude, longitude: leg.from!.longitude),
                GeoCoordinate(latitude: leg.to!.latitude, longitude: leg.to!.longitude),
              ],
            ),
      ],
    );
  }
}
