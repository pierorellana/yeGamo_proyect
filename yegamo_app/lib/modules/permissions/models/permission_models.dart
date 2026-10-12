import '../../../shared/location/location_service.dart';

enum PermissionUxState { initial, requesting, granted, denied, error }

class PermissionResult {
  const PermissionResult({required this.state, this.access});

  final PermissionUxState state;
  final LocationAccess? access;
}
