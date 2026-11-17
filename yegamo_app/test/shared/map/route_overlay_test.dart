import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/planner/models/planner_models.dart';
import 'package:yegamo_app/shared/map/route_overlay.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/map/yg_map_view.dart';
import 'package:yegamo_app/shared/map/yg_real_map.dart';
import 'package:yegamo_app/shared/location/location_service.dart';

JourneyOption option(List<JourneyLeg> legs) => JourneyOption(
  id: 'o',
  durationMin: 10,
  walkMin: 5,
  transfers: 0,
  reliabilityScore: 0,
  dataQuality: const JourneyDataQuality(
    dataState: DataState.degraded,
    liveVehicle: false,
    sourceAuthorized: false,
  ),
  legs: legs,
);

void main() {
  const a = JourneyPoint(latitude: -2.17, longitude: -79.90);
  const b = JourneyPoint(latitude: -2.16, longitude: -79.89);
  const c = JourneyPoint(latitude: -2.14, longitude: -79.88);

  test('draws origin, destination and only the walking segments', () {
    final overlay = RouteOverlay.forOption(
      option([
        const JourneyLeg(mode: 'WALK', durationMin: 5, from: a, to: b),
        const JourneyLeg(mode: 'TRANSIT', durationMin: 20, from: b, to: c),
      ]),
    );

    expect(
      overlay.points.map((p) => (p.kind, p.latitude, p.longitude)),
      [(YgMapPointKind.origin, -2.17, -79.90), (YgMapPointKind.destination, -2.14, -79.88)],
    );
    // Sin geometría de recorrido no se traza el tramo en transporte.
    expect(overlay.lines.map((l) => l.id), ['leg-0']);
    expect(overlay.lines.single.coordinates.first.latitude, -2.17);
  });

  test('legs without coordinates produce no invented geometry', () {
    final overlay = RouteOverlay.forOption(
      option([const JourneyLeg(mode: 'WALK', durationMin: 5)]),
    );
    expect(overlay.isEmpty, isTrue);
    expect(RouteOverlay.forOption(null).isEmpty, isTrue);
  });

  test('key is stable for identical routes and changes with the route', () {
    final one = RouteOverlay.forOption(option([const JourneyLeg(mode: 'WALK', durationMin: 5, from: a, to: b)]));
    final same = RouteOverlay.forOption(option([const JourneyLeg(mode: 'WALK', durationMin: 5, from: a, to: b)]));
    final other = RouteOverlay.forOption(option([const JourneyLeg(mode: 'WALK', durationMin: 5, from: a, to: c)]));
    expect(one.key, same.key);
    expect(one.key, isNot(other.key));
  });

  test('YgMapScope publishes and clears the route and routes taps to the owner', () {
    final scope = YgMapScope();
    final owner = Object();
    GeoCoordinate? tapped;
    scope.setTapHandler(owner, (p) => tapped = p);
    scope.tapHandler!(const GeoCoordinate(latitude: -2.1, longitude: -79.9));
    expect(tapped?.latitude, -2.1);

    scope.releaseTapHandler(Object());
    expect(scope.tapHandler, isNotNull);
    scope.releaseTapHandler(owner);
    expect(scope.tapHandler, isNull);

    scope.showRoute(const [], const []);
    scope.clearRoute();
    expect(scope.routeLines, isEmpty);
  });
}
