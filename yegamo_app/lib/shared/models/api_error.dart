import 'data_state.dart';

class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
    this.traceId,
    this.statusCode,
    this.dataState,
    this.retryable = false,
  });

  factory ApiError.fromResponse({
    required int statusCode,
    required Object? body,
    String? traceId,
  }) {
    final payload = _asMap(body);
    final details = _asMap(payload['details']);
    final mappedDataState =
        DataStateParsing.fromApiValue(
          details['dataState'] ?? payload['dataState'],
        ) ??
        (statusCode == 503 ? DataState.unavailable : null);

    final rawRetryable = details['retryable'] ?? payload['retryable'];
    final retryable = rawRetryable is bool
        ? rawRetryable
        : statusCode == 408 || statusCode == 429 || statusCode >= 500;

    return ApiError(
      code:
          payload['code'] as String? ??
          (statusCode == 503 ? 'PROVIDER_UNAVAILABLE' : 'HTTP_ERROR'),
      message:
          payload['message'] as String? ??
          'No fue posible completar la solicitud.',
      details: details,
      traceId: payload['traceId'] as String? ?? traceId,
      statusCode: statusCode,
      dataState: mappedDataState,
      retryable: retryable,
    );
  }

  final String code;
  final String message;
  final Map<String, Object?> details;
  final String? traceId;
  final int? statusCode;
  final DataState? dataState;
  final bool retryable;

  static Map<String, Object?> _asMap(Object? value) {
    if (value is! Map) return const <String, Object?>{};
    return Map<String, Object?>.fromEntries(
      value.entries
          .where((entry) => entry.key is String)
          .map((entry) => MapEntry(entry.key as String, entry.value)),
    );
  }
}

class ApiResponse<T> {
  const ApiResponse({
    required this.statusCode,
    required this.traceId,
    this.data,
    this.error,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final String? traceId;
  final T? data;
  final ApiError? error;
  final Map<String, String> headers;

  bool get isSuccess => error == null && statusCode >= 200 && statusCode < 300;
}
