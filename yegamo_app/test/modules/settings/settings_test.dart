import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/modules/settings/services/settings_repository.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  test('export and delete are explicit and scoped to yeGamo guest data', () async {
    final storage = InMemoryLocalStorage();
    await storage.write(YeGamoStorageKeys.savedPlaces, '[{"id":"home"}]');
    await storage.write('unrelated_app_data', 'keep');
    final repository = SettingsRepository(
      storage,
      testClient((_) async => jsonResponse(const <String, Object?>{})),
      SessionManager(storage),
      const AppConfig(),
    );

    final exported = await repository.exportLocalData();
    expect(exported.lastExport, contains('saved_places_v1'));
    await repository.deleteData();

    expect(await storage.read(YeGamoStorageKeys.savedPlaces), isNull);
    expect(await storage.read('unrelated_app_data'), 'keep');
  });

  test('location consent is persisted without a coordinate', () async {
    final storage = InMemoryLocalStorage();
    final repository = SettingsRepository(
      storage,
      testClient((_) async => jsonResponse(const <String, Object?>{})),
      SessionManager(storage),
      const AppConfig(),
    );

    final state = await repository.setLocationConsent(true);

    expect(state.locationConsent, isTrue);
    expect(await storage.read(YeGamoStorageKeys.locationConsent), 'true');
    expect(await storage.read('precise_location'), isNull);
  });
}
