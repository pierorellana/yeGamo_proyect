import '../../../shared/location/location_service.dart';
import '../../../shared/storage/local_storage.dart';
import '../models/permission_models.dart';

class PermissionRepository {
  PermissionRepository({
    required LocationService locationService,
    required LocalStorage storage,
  }) : this._(locationService, storage);

  PermissionRepository._(this._locationService, this._storage);

  static const permissionKey = 'location_permission_result';
  final LocationService _locationService;
  final LocalStorage _storage;

  Future<PermissionResult> requestWhileInUse() async {
    try {
      final access = await _locationService.requestWhileInUse();
      await _storage.write(permissionKey, access.name);
      return PermissionResult(
        state: access == LocationAccess.granted
            ? PermissionUxState.granted
            : PermissionUxState.denied,
        access: access,
      );
    } on Exception {
      return const PermissionResult(state: PermissionUxState.error);
    }
  }

  Future<LocationAccess?> savedAccess() async {
    final value = await _storage.read(permissionKey);
    if (value == null) return null;
    for (final access in LocationAccess.values) {
      if (access.name == value) return access;
    }
    return null;
  }
}
