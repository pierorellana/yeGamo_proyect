import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/modules/saved/models/saved_models.dart';
import 'package:yegamo_app/modules/saved/services/saved_places_repository.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  test('guest saved places persist locally and can be removed', () async {
    final storage = InMemoryLocalStorage();
    final repository = SavedPlacesRepository(
      storage,
      testClient((_) async => jsonResponse(const <Object?>[])),
      SessionManager(storage),
    );

    await repository.add(const SavedPlace(id: 'home', label: 'Casa'));
    expect((await repository.list()).single.label, 'Casa');
    await repository.remove('home');
    expect(await repository.list(), isEmpty);
  });

  group('authenticated sync', () {
    const serverId = '2b7f5e4e-8e4a-4db7-8f9c-0f6e1d0b6c11';

    Future<(SavedPlacesRepository, List<HttpRequest>, InMemoryLocalStorage)> build(
      TransportResponse Function(HttpRequest) respond,
    ) async {
      final storage = InMemoryLocalStorage();
      final session = SessionManager(storage);
      await session.setAuthenticated(accessToken: 'token');
      final requests = <HttpRequest>[];
      final repository = SavedPlacesRepository(
        storage,
        testClient((request) async {
          requests.add(request);
          return respond(request);
        }),
        session,
      );
      return (repository, requests, storage);
    }

    test('posts only label and location and adopts the server id', () async {
      final (repo, requests, _) = await build(
        (_) => jsonResponse({
          'id': serverId,
          'label': 'Casa',
          'location': {'lat': -2.17, 'lon': -79.9},
        }, statusCode: 201),
      );

      final result = await repo.add(
        const SavedPlace(
          id: 'local-casa',
          label: 'Casa',
          subtitle: 'Urdesa',
          latitude: -2.17,
          longitude: -79.9,
        ),
      );

      expect(requests.single.uri.path, '/v1/favorites/places');
      expect(requests.single.body, {
        'label': 'Casa',
        'location': {'lat': -2.17, 'lon': -79.9},
      });
      expect(result.error, isNull);
      expect(result.items.single.id, serverId);
      expect(result.items.single.subtitle, 'Urdesa');
    });

    test('a place without coordinates stays local and is never sent', () async {
      final (repo, requests, _) = await build((_) => jsonResponse(const <Object?>[]));

      final result = await repo.add(const SavedPlace(id: 'local-casa', label: 'Casa'));

      expect(requests, isEmpty);
      expect(result.notice, contains('solo en este dispositivo'));
      expect(result.items.single.hasLocation, isFalse);
    });

    test('keeps the place locally and reports the error when sync fails', () async {
      final (repo, _, _) = await build(
        (_) => jsonResponse({'code': 'VALIDATION_ERROR', 'message': 'x'}, statusCode: 422),
      );
      final result = await repo.add(
        const SavedPlace(id: 'local-a', label: 'A', latitude: -2.1, longitude: -79.9),
      );

      expect(result.error, isNotNull);
      expect(result.items.single.id, 'local-a');
    });

    test('deleting a local id does not call the API; a server id does', () async {
      final (repo, requests, storage) = await build((_) => jsonResponse(null, statusCode: 204));
      await repo.add(const SavedPlace(id: 'local-a', label: 'A'));
      await repo.remove('local-a');
      expect(requests, isEmpty);

      await storage.write(
        YeGamoStorageKeys.savedPlaces,
        '[{"id":"$serverId","label":"B","location":{"lat":-2.1,"lon":-79.9}}]',
      );
      await repo.remove(serverId);
      expect(requests.single.method, HttpMethod.delete);
      expect(requests.single.uri.path, '/v1/favorites/places/$serverId');
      expect(await repo.list(), isEmpty);
    });

    test('list merges server places with unsynced local ones and drops removed ones', () async {
      final (repo, _, storage) = await build(
        (_) => jsonResponse([
          {'id': serverId, 'label': 'Server', 'location': {'lat': -2.1, 'lon': -79.9}},
        ]),
      );
      await storage.write(
        YeGamoStorageKeys.savedPlaces,
        '[{"id":"local-x","label":"Local"},{"id":"11111111-1111-4111-8111-111111111111","label":"Gone"}]',
      );

      final items = await repo.list();

      expect(items.map((i) => i.label), ['Server', 'Local']);
    });
  });
}
