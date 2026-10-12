import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/home/services/home_repository.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  test(
    'maps missing provider responses to recoverable degraded state',
    () async {
      final snapshot = await HomeRepository(
        apiClient: testClient((_) async => unavailableResponse()),
        connectivity: FakeConnectivityService(),
        storage: InMemoryLocalStorage(),
      ).load();

      expect(snapshot.state, UxState.degraded);
      expect(snapshot.error?.dataState, DataState.unavailable);
    },
  );

  test('does not make offline cache look current', () async {
    final storage = InMemoryLocalStorage();
    await storage.write('home_last_success', 'true');
    final snapshot = await HomeRepository(
      apiClient: testClient(
        (_) async => jsonResponse(const <String, Object?>{}),
      ),
      connectivity: FakeConnectivityService(online: false),
      storage: storage,
    ).load();

    expect(snapshot.state, UxState.offline);
  });
}
