import 'package:geolocator/geolocator.dart';

import '../storage/local_storage.dart';

enum LocationAccess {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  restricted,
}

class GeoCoordinate {
  const GeoCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

abstract interface class LocationService {
  Future<LocationAccess> checkPermission();

  Future<LocationAccess> requestWhileInUse();

  Future<GeoCoordinate?> currentPosition();
}

/// Owns the consent decision separately from the OS permission.
/// OS permission means the platform allows access; this consent means yeGamo
/// may include a precise coordinate in an active-journey request.
class LocationConsentStore {
  LocationConsentStore(this._storage);

  final LocalStorage _storage;

  Future<bool> read() async {
    return await _storage.read(YeGamoStorageKeys.locationConsent) == 'true';
  }

  Future<void> set(bool value) async {
    if (value) {
      await _storage.write(YeGamoStorageKeys.locationConsent, 'true');
    } else {
      await _storage.remove(YeGamoStorageKeys.locationConsent);
    }
  }
}

class PrivacyAwareLocationReader {
  PrivacyAwareLocationReader(this._locationService, this._consentStore);

  final LocationService _locationService;
  final LocationConsentStore _consentStore;

  Future<GeoCoordinate?> readIfConsented() async {
    if (!await _consentStore.read()) return null;
    return _locationService.currentPosition();
  }
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationAccess> checkPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    return _mapPermission(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccess> requestWhileInUse() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    return _mapPermission(await Geolocator.requestPermission());
  }

  @override
  Future<GeoCoordinate?> currentPosition() async {
    final permission = await checkPermission();
    if (permission != LocationAccess.granted) return null;
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    return GeoCoordinate(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  static LocationAccess _mapPermission(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.denied => LocationAccess.denied,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.unableToDetermine => LocationAccess.restricted,
      };
}

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
