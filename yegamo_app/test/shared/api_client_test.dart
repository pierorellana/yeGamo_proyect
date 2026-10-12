import 'package:flutter_test/flutter_test.dart';

import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/services/api_client.dart';

class QueueTransport implements HttpTransport {
  QueueTransport(this.responses);

  final List<TransportResponse> responses;
  final List<HttpRequest> requests = <HttpRequest>[];

  @override
  Future<TransportResponse> send(HttpRequest request) async {
    requests.add(request);
    return responses.removeAt(0);
  }
}

void main() {
  const config = AppConfig(apiBaseUrl: 'https://api.example.test');

  test('builds versioned requests with trace and bearer headers', () async {
    final transport = QueueTransport(<TransportResponse>[
      const TransportResponse(
        statusCode: 200,
        headers: <String, String>{'x-trace-id': 'server-trace'},
        body: <String, Object?>{'status': 'ok'},
      ),
    ]);
    final client = ApiClient(
      config: config,
      transport: transport,
      tokenProvider: () async => 'token-123',
      traceIdFactory: () => 'request-trace',
    );

    final response = await client.get<Map<String, Object?>>(
      '/health',
      query: <String, String>{'scope': 'app'},
    );

    expect(response.isSuccess, isTrue);
    expect(response.traceId, 'server-trace');
    expect(
      transport.requests.single.uri.toString(),
      'https://api.example.test/v1/health?scope=app',
    );
    expect(transport.requests.single.headers['X-Trace-Id'], 'request-trace');
    expect(
      transport.requests.single.headers['Authorization'],
      'Bearer token-123',
    );
  });

  test(
    'maps provider unavailable responses to DataState.unavailable',
    () async {
      final transport = QueueTransport(<TransportResponse>[
        const TransportResponse(
          statusCode: 503,
          headers: <String, String>{'x-trace-id': 'unavailable-trace'},
          body: <String, Object?>{
            'code': 'PROVIDER_UNAVAILABLE',
            'message': 'Sin proveedor autorizado.',
            'details': <String, Object?>{'retryable': false},
          },
        ),
      ]);
      final client = ApiClient(
        config: config,
        transport: transport,
        maxRetries: 0,
      );

      final response = await client.get<Object?>('/journeys/plan');

      expect(response.isSuccess, isFalse);
      expect(response.error?.dataState, DataState.unavailable);
      expect(response.error?.traceId, 'unavailable-trace');
      expect(transport.requests, hasLength(1));
    },
  );

  test(
    'retries safe GET once and does not retry non-idempotent POST',
    () async {
      final getTransport = QueueTransport(<TransportResponse>[
        const TransportResponse(statusCode: 503, headers: <String, String>{}),
        const TransportResponse(
          statusCode: 200,
          headers: <String, String>{},
          body: 'ok',
        ),
      ]);
      final getClient = ApiClient(
        config: config,
        transport: getTransport,
        maxRetries: 1,
      );
      final getResponse = await getClient.get<String>('/health');

      final postTransport = QueueTransport(<TransportResponse>[
        const TransportResponse(statusCode: 503, headers: <String, String>{}),
        const TransportResponse(
          statusCode: 200,
          headers: <String, String>{},
          body: 'unexpected',
        ),
      ]);
      final postClient = ApiClient(
        config: config,
        transport: postTransport,
        maxRetries: 1,
      );
      final postResponse = await postClient.post<String>(
        '/journeys/plan',
        body: const {},
      );

      expect(getResponse.isSuccess, isTrue);
      expect(getTransport.requests, hasLength(2));
      expect(postResponse.isSuccess, isFalse);
      expect(postTransport.requests, hasLength(1));
    },
  );

  test('allows POST retry only with an idempotency key', () async {
    final transport = QueueTransport(<TransportResponse>[
      const TransportResponse(statusCode: 503, headers: <String, String>{}),
      const TransportResponse(
        statusCode: 200,
        headers: <String, String>{},
        body: 'ok',
      ),
    ]);
    final client = ApiClient(
      config: config,
      transport: transport,
      maxRetries: 1,
    );

    final response = await client.post<String>(
      '/journeys/plan',
      body: const {},
      idempotencyKey: 'operation-1',
    );

    expect(response.isSuccess, isTrue);
    expect(transport.requests, hasLength(2));
    expect(transport.requests.first.headers['Idempotency-Key'], 'operation-1');
  });
}
