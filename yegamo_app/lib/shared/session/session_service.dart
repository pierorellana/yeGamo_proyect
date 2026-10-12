import 'dart:math';

import 'package:flutter/foundation.dart';

import '../storage/local_storage.dart';

enum SessionMode { guest, authenticated }

class SessionManager extends ChangeNotifier {
  SessionManager(this._storage) {
    _mode = SessionMode.guest;
  }

  final LocalStorage _storage;
  SessionMode _mode = SessionMode.guest;
  String? _guestId;

  SessionMode get mode => _mode;
  bool get isGuest => _mode == SessionMode.guest;
  bool get isAuthenticated => _mode == SessionMode.authenticated;
  String? get guestId => _guestId;

  Future<void> initialize() async {
    final savedMode = await _storage.read(YeGamoStorageKeys.sessionMode);
    _mode = savedMode == SessionMode.authenticated.name
        ? SessionMode.authenticated
        : SessionMode.guest;
    _guestId = await _storage.read(YeGamoStorageKeys.sessionGuestId);
    if (_guestId == null && isGuest) {
      _guestId = _newGuestId();
      await _storage.write(YeGamoStorageKeys.sessionGuestId, _guestId!);
    }
    notifyListeners();
  }

  Future<void> setAuthenticated({required String accessToken}) async {
    // Tokens belong in secure storage; passwords are never accepted here.
    await _storage.writeSecure('access_token', accessToken);
    _mode = SessionMode.authenticated;
    await _storage.write(
      YeGamoStorageKeys.sessionMode,
      SessionMode.authenticated.name,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    await _storage.removeSecure('access_token');
    _mode = SessionMode.guest;
    _guestId ??= _newGuestId();
    await _storage.write(YeGamoStorageKeys.sessionMode, SessionMode.guest.name);
    await _storage.write(YeGamoStorageKeys.sessionGuestId, _guestId!);
    notifyListeners();
  }

  static String _newGuestId() {
    final random = Random().nextInt(1 << 32).toRadixString(16);
    return 'guest-${DateTime.now().microsecondsSinceEpoch}-$random';
  }
}

class PrivacyDataRepository {
  PrivacyDataRepository(this._storage);

  final LocalStorage _storage;

  Future<Map<String, Object?>> exportLocalData() async {
    final result = <String, Object?>{};
    for (final key in YeGamoStorageKeys.all) {
      result[key] = await _storage.read(key);
    }
    return result;
  }

  Future<void> deleteLocalData() async {
    for (final key in YeGamoStorageKeys.all) {
      await _storage.remove(key);
    }
    await _storage.removeSecure('access_token');
  }
}
