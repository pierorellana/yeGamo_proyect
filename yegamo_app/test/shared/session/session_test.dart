import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/shared/session/account_sync_service.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/session/token_store.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../../modules/test_support.dart';

class _Refresher implements TokenRefresher {
  _Refresher(this.result);
  final AuthTokens? result;
  int calls = 0;
  @override
  Future<AuthTokens?> refresh(String refreshToken) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return result;
  }
}

void main() {
  group('TokenStore', () {
    final now = DateTime.utc(2026, 11, 17, 12);

    test('returns a valid token untouched and a refreshed one when expired', () async {
      final storage = InMemoryLocalStorage();
      final refresher = _Refresher(
        AuthTokens(accessToken: 'new', refreshToken: 'r2', expiresAt: now.add(const Duration(hours: 1))),
      );
      final store = TokenStore(storage, refresher: refresher, now: () => now);

      await store.save(AuthTokens(accessToken: 'old', refreshToken: 'r1', expiresAt: now.add(const Duration(minutes: 10))));
      expect(await store.validAccessToken(), 'old');
      expect(refresher.calls, 0);

      await store.save(AuthTokens(accessToken: 'old', refreshToken: 'r1', expiresAt: now.add(const Duration(seconds: 10))));
      // Dos peticiones simultáneas comparten una sola renovación.
      final tokens = await Future.wait([store.validAccessToken(), store.validAccessToken()]);
      expect(tokens, ['new', 'new']);
      expect(refresher.calls, 1);
      expect(await storage.readSecure(TokenStore.refreshKey), 'r2');
    });

    test('returns null when the token expired and cannot be refreshed', () async {
      final storage = InMemoryLocalStorage();
      final store = TokenStore(storage, now: () => now);
      await store.save(AuthTokens(accessToken: 'old', expiresAt: now.subtract(const Duration(minutes: 1))));
      expect(await store.validAccessToken(), isNull);
    });
  });

  group('SessionManager', () {
    test('an expired, unrecoverable session drops back to guest and keeps local data', () async {
      final storage = InMemoryLocalStorage();
      await storage.write(YeGamoStorageKeys.savedPlaces, '[{"id":"local-a","label":"A"}]');
      final session = SessionManager(storage);
      await session.setAuthenticated(
        accessToken: 'old',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(session.isAuthenticated, isTrue);

      expect(await session.accessToken(), isNull);

      expect(session.isGuest, isTrue);
      expect(await storage.readSecure(TokenStore.accessKey), isNull);
      expect(await storage.read(YeGamoStorageKeys.savedPlaces), isNotNull);
    });

    test('a stored authenticated mode without a token restarts as guest', () async {
      final storage = InMemoryLocalStorage();
      await storage.write(YeGamoStorageKeys.sessionMode, 'authenticated');
      final session = SessionManager(storage);
      await session.initialize();
      expect(session.isGuest, isTrue);
    });
  });

  group('AccountSyncService.migrateGuestData', () {
    const serverPlace = '2b7f5e4e-8e4a-4db7-8f9c-0f6e1d0b6c11';
    const serverRoutine = '3c8f6f5f-9f5b-4ec8-9a0d-1a7f2e1c7d22';

    Future<InMemoryLocalStorage> seeded() async {
      final storage = InMemoryLocalStorage();
      await storage.write(
        YeGamoStorageKeys.savedPlaces,
        jsonEncode([
          {'id': 'local-casa', 'label': 'Casa', 'location': {'lat': -2.17, 'lon': -79.9}},
          {'id': 'local-nota', 'label': 'Sin ubicación'},
        ]),
      );
      await storage.write(
        YeGamoStorageKeys.commuteRoutines,
        jsonEncode([
          {
            'id': 'local-1',
            'label': 'Trabajo',
            'origin': 'Casa',
            'destination': 'Oficina',
            'hour': 8,
            'minute': 30,
            'days': [1, 2],
            'status': 'active',
            'timeZoneName': 'ECT',
            'timeZoneOffsetMinutes': -300,
            'originPoint': {'lat': -2.17, 'lon': -79.9},
            'destinationPoint': {'lat': -2.14, 'lon': -79.89},
          },
        ]),
      );
      return storage;
    }

    test('sends only complete items, then adopts server ids and keeps the rest local', () async {
      final storage = await seeded();
      final requests = <HttpRequest>[];
      final service = AccountSyncService(
        storage,
        testClient((request) async {
          requests.add(request);
          return jsonResponse({
            'migrationId': serverPlace,
            'importedCount': 1,
            'skippedCount': 1,
            'rejectedCount': 0,
            'idempotentReplay': false,
            'results': [
              {'index': 0, 'type': 'FAVORITE_PLACE', 'status': 'IMPORTED', 'reason': null, 'id': serverPlace},
              {'index': 1, 'type': 'COMMUTE_PROFILE', 'status': 'DUPLICATE', 'reason': 'ALREADY_EXISTS', 'id': serverRoutine},
            ],
          });
        }),
      );

      final summary = await service.migrateGuestData();

      final body = requests.single.body! as Map;
      expect(requests.single.uri.path, '/v1/me/guest-migration');
      expect(body['clientDataVersion'], '1');
      final items = body['items'] as List;
      expect(items, hasLength(2));
      expect((items[0] as Map)['type'], 'FAVORITE_PLACE');
      expect((items[0] as Map).keys.toSet(), {'type', 'label', 'location'});
      expect((items[1] as Map).keys.toSet(), {'type', 'name', 'origin', 'destination', 'weekdays', 'targetArrival'});
      expect(requests.single.headers['Idempotency-Key'], startsWith('guest-migration-'));

      expect(summary.ok, isTrue);
      expect(summary.imported, 1);
      expect(summary.duplicates, 1);
      expect(summary.keptLocal, 1); // «Sin ubicación» no se pierde ni se sube.
      final places = jsonDecode((await storage.read(YeGamoStorageKeys.savedPlaces))!) as List;
      expect((places[0] as Map)['id'], serverPlace);
      expect((places[1] as Map)['id'], 'local-nota');
      final routines = jsonDecode((await storage.read(YeGamoStorageKeys.commuteRoutines))!) as List;
      expect((routines.single as Map)['id'], serverRoutine);
    });

    test('a failed migration leaves every local item untouched', () async {
      final storage = await seeded();
      final before = await storage.read(YeGamoStorageKeys.savedPlaces);
      final service = AccountSyncService(
        storage,
        testClient((_) async => jsonResponse({'code': 'INTERNAL', 'message': 'boom'}, statusCode: 500)),
      );

      final summary = await service.migrateGuestData();

      expect(summary.ok, isFalse);
      expect(summary.keptLocal, 3);
      expect(await storage.read(YeGamoStorageKeys.savedPlaces), before);
    });

    test('rejected items stay local', () async {
      final storage = await seeded();
      final service = AccountSyncService(
        storage,
        testClient((_) async => jsonResponse({
          'migrationId': serverPlace,
          'importedCount': 1,
          'skippedCount': 0,
          'rejectedCount': 1,
          'idempotentReplay': false,
          'results': [
            {'index': 0, 'type': 'FAVORITE_PLACE', 'status': 'IMPORTED', 'reason': null, 'id': serverPlace},
            {'index': 1, 'type': 'COMMUTE_PROFILE', 'status': 'REJECTED', 'reason': 'INVALID_FIELD', 'id': null},
          ],
        })),
      );
      final summary = await service.migrateGuestData();
      expect(summary.rejected, 1);
      final routines = jsonDecode((await storage.read(YeGamoStorageKeys.commuteRoutines))!) as List;
      expect((routines.single as Map)['id'], 'local-1');
    });

    test('syncPreferences sends the local location consent', () async {
      final storage = InMemoryLocalStorage();
      await storage.write(YeGamoStorageKeys.locationConsent, 'true');
      final requests = <HttpRequest>[];
      final service = AccountSyncService(
        storage,
        testClient((request) async {
          requests.add(request);
          return jsonResponse({'locationConsent': true});
        }),
      );
      expect(await service.syncPreferences(), isTrue);
      expect(requests.single.method, HttpMethod.patch);
      expect(requests.single.uri.path, '/v1/me/preferences');
      expect(requests.single.body, {'locationConsent': true});
    });
  });
}
