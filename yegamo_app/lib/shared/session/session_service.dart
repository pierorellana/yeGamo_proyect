import 'dart:math';

import 'package:flutter/foundation.dart';

import '../storage/local_storage.dart';
import 'token_store.dart';

enum SessionMode { guest, authenticated }

class SessionManager extends ChangeNotifier {
  SessionManager(this._storage, {TokenStore? tokens})
    : _tokens = tokens ?? TokenStore(_storage) {
    _mode = SessionMode.guest;
  }

  final LocalStorage _storage;
  final TokenStore _tokens;
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
    // Sesión sin token (borrado del almacén seguro o expirada y sin refresco):
    // se vuelve a modo invitado en vez de enviar peticiones que fallarían con 401.
    if (_mode == SessionMode.authenticated && !await _tokens.hasSession) {
      _mode = SessionMode.guest;
      await _storage.write(YeGamoStorageKeys.sessionMode, SessionMode.guest.name);
    }
    _guestId = await _storage.read(YeGamoStorageKeys.sessionGuestId);
    if (_guestId == null && isGuest) {
      _guestId = _newGuestId();
      await _storage.write(YeGamoStorageKeys.sessionGuestId, _guestId!);
    }
    notifyListeners();
  }

  /// Token vigente (renovado si hace falta). Si la sesión ya no es recuperable
  /// se cierra y la app continúa como invitado sin perder datos locales.
  Future<String?> accessToken() async {
    if (_mode != SessionMode.authenticated) return null;
    final token = await _tokens.validAccessToken();
    if (token == null) await signOut();
    return token;
  }

  Future<void> setAuthenticated({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    // Tokens belong in secure storage; passwords are never accepted here.
    await _tokens.save(
      AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    _mode = SessionMode.authenticated;
    await _storage.write(
      YeGamoStorageKeys.sessionMode,
      SessionMode.authenticated.name,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    await _tokens.clear();
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
    await TokenStore(_storage).clear();
  }
}
