import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/search/services/search_repository.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  test('stores recent queries only after an API response', () async {
    final storage = InMemoryLocalStorage();
    final repository = SearchRepository(
      apiClient: testClient(
        (_) async => jsonResponse(<String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'id': 'place-1',
              'name': 'Lugar autorizado',
              'location': <String, Object?>{'lat': -2.1, 'lon': -79.9},
              'dataState': 'CURRENT',
            },
          ],
        }),
      ),
      connectivity: FakeConnectivityService(),
      storage: storage,
    );

    final snapshot = await repository.search('Lugar autorizado');

    expect(snapshot.state.name, 'ok');
    expect(snapshot.results.single.dataState, DataState.current);
    expect(await repository.recentQueries(), contains('Lugar autorizado'));
  });

  test('maps geocoding unavailability without fixture results', () async {
    final snapshot = await SearchRepository(
      apiClient: testClient((_) async => unavailableResponse()),
      connectivity: FakeConnectivityService(),
      storage: InMemoryLocalStorage(),
    ).search('unresolved');

    expect(snapshot.state.name, 'degraded');
    expect(snapshot.results, isEmpty);
  });
}
