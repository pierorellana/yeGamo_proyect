import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/local_storage.dart';

/// Tokens OIDC emitidos por el proveedor configurado. El API solo valida el JWT
/// (ADR-006); renovarlo es el flujo estándar `refresh_token` del proveedor.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
}

/// Renueva tokens contra el endpoint del proveedor OIDC (sin contraseñas).
abstract interface class TokenRefresher {
  /// Devuelve tokens nuevos o `null` si el proveedor rechazó el refresco.
  Future<AuthTokens?> refresh(String refreshToken);
}

class OidcTokenRefresher implements TokenRefresher {
  OidcTokenRefresher({
    required this.tokenEndpoint,
    required this.clientId,
    http.Client? client,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

  final Uri tokenEndpoint;
  final String clientId;
  final http.Client _client;
  final DateTime Function() _now;

  @override
  Future<AuthTokens?> refresh(String refreshToken) async {
    try {
      final response = await _client
          .post(
            tokenEndpoint,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
              'client_id': clientId,
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map || body['access_token'] is! String) return null;
      final seconds = (body['expires_in'] as num?)?.toInt() ?? 300;
      return AuthTokens(
        accessToken: body['access_token'] as String,
        // Algunos proveedores rotan el refresh token; otros lo conservan.
        refreshToken: body['refresh_token'] as String? ?? refreshToken,
        expiresAt: _now().add(Duration(seconds: seconds)),
      );
    } on Exception {
      return null;
    }
  }
}

/// Almacén seguro de tokens con expiración y renovación única en vuelo.
class TokenStore {
  TokenStore(this._storage, {this.refresher, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const accessKey = 'access_token';
  static const refreshKey = 'refresh_token';
  static const expiresKey = 'access_token_expires_at';

  /// Margen para no enviar un token a punto de expirar.
  static const skew = Duration(seconds: 30);

  final LocalStorage _storage;
  final TokenRefresher? refresher;
  final DateTime Function() _now;
  Future<String?>? _refreshing;

  Future<void> save(AuthTokens tokens) async {
    await _storage.writeSecure(accessKey, tokens.accessToken);
    await _storage.writeSecure(expiresKey, tokens.expiresAt.toUtc().toIso8601String());
    if (tokens.refreshToken != null) {
      await _storage.writeSecure(refreshKey, tokens.refreshToken!);
    }
  }

  Future<void> clear() async {
    await _storage.removeSecure(accessKey);
    await _storage.removeSecure(refreshKey);
    await _storage.removeSecure(expiresKey);
  }

  Future<bool> get hasSession async => (await _storage.readSecure(accessKey)) != null;

  /// Token vigente para el encabezado `Authorization`, renovándolo si venció.
  /// `null` cuando no hay sesión o ya no se puede renovar (sesión expirada).
  Future<String?> validAccessToken() async {
    final token = await _storage.readSecure(accessKey);
    if (token == null || token.isEmpty) return null;
    final expiresAt = DateTime.tryParse(
      await _storage.readSecure(expiresKey) ?? '',
    );
    if (expiresAt == null || expiresAt.isAfter(_now().add(skew))) return token;
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh() async {
    final refreshToken = await _storage.readSecure(refreshKey);
    final refresher = this.refresher;
    if (refreshToken == null || refresher == null) return null;
    final tokens = await refresher.refresh(refreshToken);
    if (tokens == null) return null;
    await save(tokens);
    return tokens.accessToken;
  }
}
