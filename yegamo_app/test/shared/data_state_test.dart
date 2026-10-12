import 'package:flutter_test/flutter_test.dart';

import 'package:yegamo_app/shared/models/api_error.dart';
import 'package:yegamo_app/shared/models/data_state.dart';

void main() {
  test('parses the canonical API data states', () {
    expect(DataStateParsing.fromApiValue('CURRENT'), DataState.current);
    expect(
      DataStateParsing.fromApiValue('OFFLINE_CACHE'),
      DataState.offlineCache,
    );
    expect(DataStateParsing.fromApiValue('unknown'), isNull);
  });

  test('maps provider 503 to unavailable and degraded UX', () {
    final error = ApiError.fromResponse(
      statusCode: 503,
      body: <String, Object?>{
        'code': 'PROVIDER_UNAVAILABLE',
        'message': 'No hay fuente autorizada.',
        'details': <String, Object?>{'retryable': true},
        'traceId': 'trace-503',
      },
    );

    expect(error.dataState, DataState.unavailable);
    expect(error.traceId, 'trace-503');
    expect(error.retryable, isTrue);
    expect(
      UxStateMapping.fromError(code: error.code, dataState: error.dataState),
      UxState.degraded,
    );
  });

  test('keeps permission and coverage distinct from provider degradation', () {
    expect(
      UxStateMapping.fromError(code: 'LOCATION_PERMISSION_REQUIRED'),
      UxState.permission,
    );
    expect(
      UxStateMapping.fromError(code: 'LOCATION_OUT_OF_COVERAGE'),
      UxState.noCoverage,
    );
  });
}
