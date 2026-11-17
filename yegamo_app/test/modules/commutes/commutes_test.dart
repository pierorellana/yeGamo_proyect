import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/planner/models/planner_models.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/modules/commutes/models/commute_models.dart';
import 'package:yegamo_app/modules/commutes/services/commutes_repository.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  test('pause and resume are persisted and next alert is UTC-safe', () async {
    final storage = InMemoryLocalStorage();
    final repository = CommutesRepository(
      storage,
      testClient((_) async => jsonResponse(const <Object?>[])),
      SessionManager(storage),
    );
    final routine = CommuteRoutine(
      id: 'routine-1',
      label: 'Trabajo',
      origin: 'Casa',
      destination: 'Oficina',
      hour: 8,
      minute: 30,
      days: const [1, 2, 3, 4, 5],
      status: CommuteStatus.active,
      timeZoneName: 'America/Guayaquil',
      timeZoneOffsetMinutes: -300,
    );

    await repository.save(routine);
    final paused = await repository.setPaused(routine, true);
    expect(paused.items.single.isPaused, isTrue);
    expect(paused.items.single.nextAlertUtc(now: DateTime(2026, 10, 12, 7)), isA<DateTime>());
    final resumed = await repository.setPaused(paused.items.single, false);
    expect(resumed.items.single.status, CommuteStatus.active);
  });

  group('API contract', () {
    const serverId = '2b7f5e4e-8e4a-4db7-8f9c-0f6e1d0b6c11';
    CommuteRoutine routine({JourneyPoint? origin, JourneyPoint? destination, String id = 'local-1'}) =>
        CommuteRoutine(
          id: id,
          label: 'Trabajo',
          origin: 'Casa',
          destination: 'Oficina',
          hour: 7,
          minute: 5,
          days: const [1, 2, 3],
          status: CommuteStatus.active,
          timeZoneName: 'America/Guayaquil',
          timeZoneOffsetMinutes: -300,
          originPoint: origin,
          destinationPoint: destination,
        );
    const home = JourneyPoint(latitude: -2.17, longitude: -79.9);
    const office = JourneyPoint(latitude: -2.14, longitude: -79.89);

    test('toApiJson matches CommuteProfile exactly', () {
      expect(routine(origin: home, destination: office).toApiJson(), {
        'name': 'Trabajo',
        'origin': {'lat': -2.17, 'lon': -79.9},
        'destination': {'lat': -2.14, 'lon': -79.89},
        'weekdays': [1, 2, 3],
        'targetArrival': '07:05',
      });
    });

    test('parses a CommuteProfile response', () {
      final parsed = CommuteRoutine.fromJson({
        'id': serverId,
        'name': 'Trabajo',
        'origin': {'lat': -2.17, 'lon': -79.9},
        'destination': {'lat': -2.14, 'lon': -79.89},
        'weekdays': [1, 5],
        'targetArrival': '08:30:00',
        'enabled': false,
      });
      expect(parsed.label, 'Trabajo');
      expect(parsed.hour, 8);
      expect(parsed.minute, 30);
      expect(parsed.days, [1, 5]);
      expect(parsed.isPaused, isTrue);
      expect(parsed.hasLocations, isTrue);
      expect(parsed.isRemote, isTrue);
    });

    test('syncs with coordinates via POST and adopts the server id', () async {
      final storage = InMemoryLocalStorage();
      final session = SessionManager(storage);
      await session.setAuthenticated(accessToken: 't');
      final requests = <HttpRequest>[];
      final repo = CommutesRepository(
        storage,
        testClient((request) async {
          requests.add(request);
          return jsonResponse({
            'id': serverId,
            'name': 'Trabajo',
            'origin': {'lat': -2.17, 'lon': -79.9},
            'destination': {'lat': -2.14, 'lon': -79.89},
            'weekdays': [1, 2, 3],
            'targetArrival': '07:05:00',
            'enabled': true,
          }, statusCode: 201);
        }),
        session,
      );

      final result = await repo.save(routine(origin: home, destination: office));

      expect(requests.single.uri.path, '/v1/commute-profiles');
      expect((requests.single.body! as Map).keys.toSet(), {
        'name', 'origin', 'destination', 'weekdays', 'targetArrival',
      });
      expect(result.items.single.id, serverId);
      expect(result.items.single.origin, 'Casa');
    });

    test('a routine without coordinates stays local and never calls the API', () async {
      final storage = InMemoryLocalStorage();
      final session = SessionManager(storage);
      await session.setAuthenticated(accessToken: 't');
      final requests = <HttpRequest>[];
      final repo = CommutesRepository(
        storage,
        testClient((request) async {
          requests.add(request);
          return jsonResponse(const <Object?>[]);
        }),
        session,
      );

      final result = await repo.save(routine());
      final paused = await repo.setPaused(result.items.single, true);
      final removed = await repo.remove('local-1');

      expect(requests, isEmpty);
      expect(result.notice, contains('solo en este dispositivo'));
      expect(paused.items.single.isPaused, isTrue);
      expect(removed.items, isEmpty);
    });

    test('parsePoint accepts "lat, lon" only and rejects out-of-range values', () {
      expect(CommuteRoutine.parsePoint('-2.17, -79.9')?.latitude, -2.17);
      expect(CommuteRoutine.parsePoint('Casa'), isNull);
      expect(CommuteRoutine.parsePoint('95, 10'), isNull);
    });
  });
}
