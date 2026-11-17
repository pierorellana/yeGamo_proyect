import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);

  Future<String?> readSecure(String key);

  Future<void> writeSecure(String key, String value);

  Future<void> removeSecure(String key);
}

/// Keys owned by the local yeGamo guest experience.
///
/// Keeping this list explicit makes privacy operations reversible and scoped:
/// export/delete never clears unrelated application data.
abstract final class YeGamoStorageKeys {
  static const onboardingCompleted = 'onboarding_completed';
  static const locationPermission = 'location_permission_result';
  static const locationConsent = 'location_precise_consent';
  static const sessionGuestId = 'session_guest_id';
  static const sessionMode = 'session_mode';
  static const savedPlaces = 'saved_places_v1';
  static const commuteRoutines = 'commute_routines_v1';
  static const notifications = 'notifications_v1';
  static const activeJourney = 'active_journey_v1';
  static const homeCache = 'home_last_success';
  static const recentQueries = 'recent_queries';
  static const privacyExportedAt = 'privacy_exported_at';
  static const leaveAlerts = 'leave_alerts_v1';

  static const all = <String>[
    onboardingCompleted,
    locationPermission,
    locationConsent,
    sessionGuestId,
    sessionMode,
    savedPlaces,
    commuteRoutines,
    notifications,
    activeJourney,
    homeCache,
    recentQueries,
    privacyExportedAt,
    leaveAlerts,
  ];
}

class SharedLocalStorage implements LocalStorage {
  SharedLocalStorage({
    required this.preferences,
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final SharedPreferences preferences;
  final FlutterSecureStorage _secureStorage;

  @override
  Future<String?> read(String key) async => preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await preferences.remove(key);
  }

  @override
  Future<String?> readSecure(String key) => _secureStorage.read(key: key);

  @override
  Future<void> writeSecure(String key, String value) =>
      _secureStorage.write(key: key, value: value);

  @override
  Future<void> removeSecure(String key) => _secureStorage.delete(key: key);
}

class InMemoryLocalStorage implements LocalStorage {
  final Map<String, String> _values = <String, String>{};
  final Map<String, String> _secureValues = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> readSecure(String key) async => _secureValues[key];

  @override
  Future<void> writeSecure(String key, String value) async {
    _secureValues[key] = value;
  }

  @override
  Future<void> removeSecure(String key) async {
    _secureValues.remove(key);
  }
}
