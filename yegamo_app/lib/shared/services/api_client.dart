import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../env/config/app_config.dart';
import '../models/api_error.dart';

enum HttpMethod { get, post, put, patch, delete }

class HttpRequest {
  const HttpRequest({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
  });

  final HttpMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final Object? body;
}

class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    required this.headers,
    this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Object? body;
}

abstract interface class HttpTransport {
  Future<TransportResponse> send(HttpRequest request);
}

class HttpPackageTransport implements HttpTransport {
  HttpPackageTransport({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<TransportResponse> send(HttpRequest request) async {
    final headers = Map<String, String>.from(request.headers);
    final encodedBody = request.body == null ? null : jsonEncode(request.body);
    final response = switch (request.method) {
      HttpMethod.get => await _client.get(request.uri, headers: headers),
      HttpMethod.post => await _client.post(
        request.uri,
        headers: headers,
        body: encodedBody,
      ),
      HttpMethod.put => await _client.put(
        request.uri,
        headers: headers,
        body: encodedBody,
      ),
      HttpMethod.patch => await _client.patch(
        request.uri,
        headers: headers,
        body: encodedBody,
      ),
      HttpMethod.delete => await _client.delete(request.uri, headers: headers),
    };

    return TransportResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: _decodeBody(response.body),
    );
  }

  void close() => _client.close();

  static Object? _decodeBody(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }
}

class TransportException implements Exception {
  const TransportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required AppConfig config,
    HttpTransport? transport,
    Future<String?> Function()? tokenProvider,
    String Function()? traceIdFactory,
    Duration? timeout,
    int? maxRetries,
    Duration retryDelay = Duration.zero,
  }) : this._internal(
         config: config,
         transport: transport,
         tokenProvider: tokenProvider,
         traceIdFactory: traceIdFactory,
         timeout: timeout,
         maxRetries: maxRetries,
         retryDelay: retryDelay,
       );

  ApiClient._internal({
    required AppConfig config,
    HttpTransport? transport,
    this._tokenProvider,
    String Function()? traceIdFactory,
    Duration? timeout,
    int? maxRetries,
    this.retryDelay = Duration.zero,
  }) : _config = config,
       _transport = transport ?? HttpPackageTransport(),
       _ownsTransport = transport == null,
       _traceIdFactory = traceIdFactory ?? _defaultTraceId,
       _timeout = timeout ?? config.requestTimeout,
       _maxRetries = max(0, maxRetries ?? config.maxRetries);

  final AppConfig _config;
  final HttpTransport _transport;
  final bool _ownsTransport;
  final Future<String?> Function()? _tokenProvider;
  final String Function() _traceIdFactory;
  final Duration _timeout;
  final int _maxRetries;
  final Duration retryDelay;

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? query,
    T Function(Object? body)? decode,
  }) {
    return _request<T>(
      method: HttpMethod.get,
      path: path,
      query: query,
      decode: decode,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    T Function(Object? body)? decode,
  }) {
    return _request<T>(
      method: HttpMethod.post,
      path: path,
      body: body,
      idempotencyKey: idempotencyKey,
      decode: decode,
    );
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    T Function(Object? body)? decode,
  }) {
    return _request<T>(
      method: HttpMethod.patch,
      path: path,
      body: body,
      idempotencyKey: idempotencyKey,
      decode: decode,
    );
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    String? idempotencyKey,
    T Function(Object? body)? decode,
  }) {
    return _request<T>(
      method: HttpMethod.delete,
      path: path,
      idempotencyKey: idempotencyKey,
      decode: decode,
    );
  }

  Future<ApiResponse<T>> _request<T>({
    required HttpMethod method,
    required String path,
    Map<String, String>? query,
    Object? body,
    String? idempotencyKey,
    T Function(Object? body)? decode,
  }) async {
    final traceId = _traceIdFactory();
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Trace-Id': traceId,
      if (body != null) 'Content-Type': 'application/json',
    };
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final token = await _tokenProvider?.call();
    final authorization = token?.isNotEmpty == true ? 'Bearer $token' : null;
    if (authorization != null) {
      headers['Authorization'] = authorization;
    }

    final request = HttpRequest(
      method: method,
      uri: _buildUri(path, query),
      headers: headers,
      body: body,
    );
    var retryCount = 0;

    while (true) {
      try {
        final transportResponse = await _transport
            .send(request)
            .timeout(_timeout);
        final response = _mapResponse<T>(
          transportResponse,
          requestTraceId: traceId,
          decode: decode,
        );
        if (!_shouldRetryResponse(
              method,
              idempotencyKey,
              response.statusCode,
            ) ||
            retryCount >= _maxRetries) {
          return response;
        }
      } on TimeoutException {
        if (!_shouldRetry(method, idempotencyKey, retryCount)) {
          return _failure<T>(
            code: 'NETWORK_TIMEOUT',
            message: 'La solicitud tardó demasiado en responder.',
            traceId: traceId,
            retryable: true,
          );
        }
      } on Exception catch (error) {
        if (!_shouldRetry(method, idempotencyKey, retryCount)) {
          return _failure<T>(
            code: 'NETWORK_ERROR',
            message: error.toString(),
            traceId: traceId,
            retryable: true,
          );
        }
      }

      retryCount += 1;
      if (retryDelay > Duration.zero) await Future<void>.delayed(retryDelay);
    }
  }

  ApiResponse<T> _mapResponse<T>(
    TransportResponse response, {
    required String requestTraceId,
    T Function(Object? body)? decode,
  }) {
    final traceId = _header(response.headers, 'x-trace-id') ?? requestTraceId;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final data = decode == null
            ? response.body as T?
            : decode(response.body);
        return ApiResponse<T>(
          statusCode: response.statusCode,
          traceId: traceId,
          data: data,
          headers: response.headers,
        );
      } on TypeError {
        return _failure<T>(
          code: 'INVALID_RESPONSE',
          message: 'La respuesta no coincide con el contrato esperado.',
          statusCode: response.statusCode,
          traceId: traceId,
          retryable: false,
        );
      }
    }

    return ApiResponse<T>(
      statusCode: response.statusCode,
      traceId: traceId,
      headers: response.headers,
      error: ApiError.fromResponse(
        statusCode: response.statusCode,
        body: response.body,
        traceId: traceId,
      ),
    );
  }

  ApiResponse<T> _failure<T>({
    required String code,
    required String message,
    required String traceId,
    required bool retryable,
    int statusCode = 0,
  }) {
    return ApiResponse<T>(
      statusCode: statusCode,
      traceId: traceId,
      error: ApiError(
        code: code,
        message: message,
        traceId: traceId,
        statusCode: statusCode == 0 ? null : statusCode,
        retryable: retryable,
      ),
    );
  }

  bool _shouldRetryResponse(
    HttpMethod method,
    String? idempotencyKey,
    int statusCode,
  ) {
    if (!_safeToRetry(method, idempotencyKey)) return false;
    return statusCode == 408 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  bool _shouldRetry(HttpMethod method, String? idempotencyKey, int retryCount) {
    return _safeToRetry(method, idempotencyKey) && retryCount < _maxRetries;
  }

  bool _safeToRetry(HttpMethod method, String? idempotencyKey) {
    return method == HttpMethod.get ||
        (method == HttpMethod.post && idempotencyKey != null);
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final pathWithVersion =
        normalizedPath == 'v1' || normalizedPath.startsWith('v1/')
        ? normalizedPath
        : 'v1/$normalizedPath';
    final basePath = _config.apiBaseUri.path == '/'
        ? ''
        : _config.apiBaseUri.path.replaceFirst(RegExp(r'/$'), '');
    return _config.apiBaseUri.replace(
      path: '$basePath/$pathWithVersion',
      queryParameters: query,
    );
  }

  static String? _header(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
    }
    return null;
  }

  static String _defaultTraceId() {
    final random = Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  void dispose() {
    if (_ownsTransport) {
      final transport = _transport;
      if (transport is HttpPackageTransport) {
        transport.close();
      }
    }
  }
}
