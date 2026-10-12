import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/services/api_client.dart';

import 'prototype_states.dart';

void main() {
  test('catalogue keeps exactly 17 screens and 9 reusable UX states', () {
    expect(prototypeScreenFixtures, hasLength(17));
    expect(
      prototypeScreenFixtures.map((fixture) => fixture.number),
      orderedEquals(List<int>.generate(17, (index) => index + 1)),
    );
    expect(
      prototypeScreenFixtures.map((fixture) => fixture.route).toSet(),
      equals(AppRoutes.baselineNames.toSet()),
    );
    expect(prototypeUxStates, hasLength(9));
    expect(prototypeUxStates.toSet(), hasLength(9));
  });

  test('arrived and nocov remain flow states, not catalogue screens', () {
    final titles = prototypeScreenFixtures
        .map((fixture) => fixture.title)
        .toSet();
    expect(titles, isNot(contains('Arrived')));
    expect(titles, isNot(contains('nocov')));
  });

  test('fake clock and transport produce stable test-only data', () async {
    final clock = PrototypeFixtureClock(DateTime.utc(2026, 10, 12, 12));
    final transport = PrototypeFixtureTransport(
      clock: clock,
      onRequest: (request, fixtureClock) => TransportResponse(
        statusCode: 200,
        headers: const {'x-trace-id': 'fixture-trace'},
        body: prototypeJourneyPlanFixture(fixtureClock),
      ),
    );
    final request = HttpRequest(
      method: HttpMethod.post,
      uri: Uri.parse('https://fixture.test/v1/journeys/plan'),
      headers: const {},
    );

    final first = await transport.send(request);
    clock.advance(const Duration(minutes: 1));
    final second = await transport.send(request);

    expect(transport.requests, hasLength(2));
    expect((first.body! as Map)['recommendedLeaveAt'], isNotNull);
    expect(
      (first.body! as Map)['recommendedLeaveAt'],
      isNot((second.body! as Map)['recommendedLeaveAt']),
    );
  });
}
