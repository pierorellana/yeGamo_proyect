import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/planner/models/planner_models.dart';
import 'package:yegamo_app/modules/planner/services/journey_repository.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  const request = JourneyPlanRequest(
    origin: JourneyPoint(latitude: -2.17, longitude: -79.9),
    destination: JourneyPoint(latitude: -2.14, longitude: -79.89),
    timeMode: TimeMode.leaveNow,
  );

  late InMemoryLocalStorage storage;
  late DateTime now;
  var online = true;
  var failure = 0;

  JourneyRepository build() => JourneyRepository(
    apiClient: testClient((_) async {
      if (!online) throw const TransportException('sin red');
      if (failure != 0) {
        return jsonResponse({
          'code': 'PROVIDER_UNAVAILABLE',
          'message': 'Sin proveedor',
          'details': {'dataState': 'UNAVAILABLE', 'retryable': true},
        }, statusCode: failure);
      }
      return jsonResponse(validPlanBody());
    }),
    storage: storage,
    now: () => now,
  );

  setUp(() {
    storage = InMemoryLocalStorage();
    now = DateTime.utc(2026, 11, 17, 12);
    online = true;
    failure = 0;
  });

  test('a plan fetched online is returned as-is and cached', () async {
    final result = await build().plan(request);
    expect(result.fromCache, isFalse);
    expect(result.plan, isNotNull);
    expect(await storage.read(YeGamoStorageKeys.planCache), isNotNull);
  });

  test('with no network the cached plan comes back labelled OFFLINE_CACHE with its real capture time', () async {
    final repo = build();
    final online1 = await repo.plan(request);
    online = false;
    now = now.add(const Duration(hours: 2));

    final offline = await repo.plan(request);

    expect(offline.fromCache, isTrue);
    expect(offline.plan?.planId, online1.plan?.planId);
    expect(offline.plan?.dataState, DataState.offlineCache);
    for (final option in offline.plan!.options) {
      expect(option.dataQuality.dataState, DataState.offlineCache);
      expect(option.dataQuality.liveVehicle, isFalse);
      expect(option.dataQuality.observedAt, DateTime.utc(2026, 11, 17, 12));
    }
  });

  test('a cached plan older than the TTL is not reused', () async {
    final repo = build();
    await repo.plan(request);
    online = false;
    now = now.add(JourneyRepository.cacheTtl + const Duration(minutes: 1));

    final result = await repo.plan(request);

    expect(result.plan, isNull);
    expect(result.error?.code, 'NETWORK_ERROR');
  });

  test('a provider outage (503) never falls back to an old plan', () async {
    final repo = build();
    await repo.plan(request);
    failure = 503;

    final result = await repo.plan(request);

    expect(result.plan, isNull);
    expect(result.error?.statusCode, 503);
    expect(result.error?.dataState, DataState.unavailable);
  });

  test('a different request does not get another route from the cache', () async {
    final repo = build();
    await repo.plan(request);
    online = false;
    final other = await repo.plan(
      const JourneyPlanRequest(
        origin: JourneyPoint(latitude: -2.2, longitude: -79.8),
        destination: JourneyPoint(latitude: -2.14, longitude: -79.89),
        timeMode: TimeMode.leaveNow,
      ),
    );
    expect(other.plan, isNull);
  });

  test('the cache keeps at most five plans', () async {
    final repo = build();
    for (var i = 0; i < 7; i++) {
      await repo.plan(
        JourneyPlanRequest(
          origin: JourneyPoint(latitude: -2.1 - i / 100, longitude: -79.9),
          destination: const JourneyPoint(latitude: -2.14, longitude: -79.89),
          timeMode: TimeMode.leaveNow,
        ),
      );
    }
    final raw = await storage.read(YeGamoStorageKeys.planCache);
    expect('"savedAt"'.allMatches(raw!).length, JourneyRepository.cacheMax);
  });
}
