import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class ConnectivityService {
  Future<bool> get isOnline;

  Stream<bool> get onStatusChanged;
}

class DeviceConnectivityService implements ConnectivityService {
  DeviceConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isOnline async =>
      _isOnline(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
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
