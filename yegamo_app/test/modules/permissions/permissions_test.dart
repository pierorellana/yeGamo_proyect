import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/permissions/models/permission_models.dart';
import 'package:yegamo_app/modules/permissions/providers/permission_view_model.dart';
import 'package:yegamo_app/modules/permissions/services/permission_repository.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';
import '../../support/fakes.dart';

void main() {
  test(
    'allows location while-in-use and records only permission status',
    () async {
      final storage = InMemoryLocalStorage();
      final repository = PermissionRepository(
        locationService: FakeLocationService(
          permission: LocationAccess.granted,
        ),
        storage: storage,
      );
      final vm = PermissionViewModel(repository: repository);

      await vm.request();

      expect(vm.state, PermissionUxState.granted);
      expect(await storage.read('location_permission_result'), 'granted');
      expect(await storage.read('precise_location'), isNull);
    },
  );

  test('keeps denied permission recoverable with manual origin', () async {
    final vm = PermissionViewModel(
      repository: PermissionRepository(
        locationService: FakeLocationService(permission: LocationAccess.denied),
        storage: InMemoryLocalStorage(),
      ),
    );

    await vm.request();

    expect(vm.state, PermissionUxState.denied);
  });
}
