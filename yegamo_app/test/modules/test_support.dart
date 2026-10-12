import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/shared/services/api_client.dart';

class FunctionTransport implements HttpTransport {
  FunctionTransport(this.handler);

  final Future<TransportResponse> Function(HttpRequest request) handler;
  final List<HttpRequest> requests = <HttpRequest>[];

  @override
  Future<TransportResponse> send(HttpRequest request) async {
    requests.add(request);
    return handler(request);
  }
}

ApiClient testClient(
  Future<TransportResponse> Function(HttpRequest request) handler,
) {
  return ApiClient(
    config: const AppConfig(apiBaseUrl: 'https://api.test'),
    transport: FunctionTransport(handler),
    maxRetries: 0,
  );
}

TransportResponse jsonResponse(Object? body, {int statusCode = 200}) {
  return TransportResponse(
    statusCode: statusCode,
    headers: const <String, String>{'x-trace-id': 'test-trace'},
    body: body,
  );
}

TransportResponse unavailableResponse({String code = 'PROVIDER_UNAVAILABLE'}) {
  return jsonResponse(<String, Object?>{
    'code': code,
    'message': 'No existe una fuente autorizada para esta capacidad.',
    'details': <String, Object?>{
      'dataState': code == 'LOCATION_OUT_OF_COVERAGE'
          ? 'UNAVAILABLE'
          : 'UNAVAILABLE',
      'retryable': false,
    },
  }, statusCode: code == 'LOCATION_OUT_OF_COVERAGE' ? 422 : 503);
}

Map<String, Object?> validPlanBody() => <String, Object?>{
  'planId': '00000000-0000-0000-0000-000000000001',
  'dataState': 'DEGRADED',
  'options': <Object?>[
    <String, Object?>{
      'id': '00000000-0000-0000-0000-000000000002',
      'durationMin': 32,
      'walkMin': 8,
      'transfers': 1,
      'reliability': <String, Object?>{
        'score': 70,
        'level': 'MEDIUM',
        'sampleSize': 4,
      },
      'dataQuality': <String, Object?>{
        'freshness': 'DEGRADED',
        'dataState': 'DEGRADED',
        'liveVehicle': false,
        'observedAt': null,
        'providerDisplayName': null,
        'sourceAuthorized': false,
      },
      'legs': <Object?>[],
    },
  ],
};
