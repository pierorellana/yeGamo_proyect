import 'package:flutter_test/flutter_test.dart';
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
}
