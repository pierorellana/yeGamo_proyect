// Test doubles. They live under test/ so no simulated provider ships in the app.
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';

class FakeLocationService implements LocationService {
  FakeLocationService({this.permission = LocationAccess.denied, this.position});

  LocationAccess permission;
  GeoCoordinate? position;

  @override
  Future<LocationAccess> checkPermission() async => permission;

  @override
  Future<LocationAccess> requestWhileInUse() async => permission;

  @override
  Future<GeoCoordinate?> currentPosition() async =>
      permission == LocationAccess.granted ? position : null;
}

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<bool> get onStatusChanged => const Stream<bool>.empty();

  void setOnline(bool value) => online = value;
}
