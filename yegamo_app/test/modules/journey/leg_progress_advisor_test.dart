import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/journey/services/leg_progress_advisor.dart';
import 'package:yegamo_app/modules/planner/models/planner_models.dart';
import 'package:yegamo_app/shared/location/location_service.dart';

void main() {
  const advisor = LegProgressAdvisor();
  // ~1.1 km entre origen y destino a lo largo de la longitud.
  const from = JourneyPoint(latitude: -2.1700, longitude: -79.9000);
  const to = JourneyPoint(latitude: -2.1700, longitude: -79.8900);
  JourneyLeg leg(String mode, {JourneyPoint? f = from, JourneyPoint? t = to}) =>
      JourneyLeg(mode: mode, durationMin: 10, from: f, to: t);
  GeoCoordinate at(double lat, double lon) =>
      GeoCoordinate(latitude: lat, longitude: lon);

  test('haversine matches a known distance within 1 %', () {
    // 0.01° de longitud en el ecuador ≈ 1111.9 m.
    final d = LegProgressAdvisor.distanceM(from, to);
    expect(d, closeTo(1111.9, 12));
  });

  test('near the end of the leg suggests advancing', () {
    final result = advisor.assess(at(-2.1700, -79.8905), leg('WALK'));
    expect(result.advice, LegAdvice.nearEnd);
    expect(result.distanceToEndM, lessThan(60));
  });

  test('mid-leg on the line is on track and reports the remaining distance', () {
    final result = advisor.assess(at(-2.1700, -79.8950), leg('WALK'));
    expect(result.advice, LegAdvice.onTrack);
    expect(result.distanceToEndM, closeTo(556, 15));
    expect(result.offRouteM, lessThan(5));
  });

  test('a walking leg flags a deviation far from the segment', () {
    final result = advisor.assess(at(-2.1800, -79.8950), leg('WALK'));
    expect(result.advice, LegAdvice.offRoute);
    expect(result.offRouteM, greaterThan(1000));
  });

  test('transit legs never claim a deviation (no route geometry)', () {
    final result = advisor.assess(at(-2.1800, -79.8950), leg('TRANSIT'));
    expect(result.advice, LegAdvice.onTrack);
    expect(result.offRouteM, isNull);
  });

  test('a leg without coordinates gives no evidence', () {
    expect(advisor.assess(at(-2.17, -79.9), leg('WALK', f: null, t: null)).advice, LegAdvice.unknown);
  });

  test('a degenerate segment does not divide by zero', () {
    final point = LegProgressAdvisor.distanceToSegmentM(
      const JourneyPoint(latitude: -2.17, longitude: -79.89),
      from,
      from,
    );
    expect(point.isFinite, isTrue);
  });
}
