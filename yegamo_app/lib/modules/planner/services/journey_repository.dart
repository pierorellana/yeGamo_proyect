import '../../../shared/models/api_error.dart';
import '../../../shared/services/api_client.dart';
import '../models/planner_models.dart';

class JourneyRepository {
  JourneyRepository({required ApiClient apiClient}) : this._(apiClient);

  JourneyRepository._(this._apiClient);

  final ApiClient _apiClient;

  Future<JourneyResult> plan(JourneyPlanRequest request) async {
    final response = await _apiClient.post<Object?>(
      'journeys/plan',
      body: request.toJson(),
      idempotencyKey: 'plan-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!response.isSuccess) {
      return JourneyResult(error: response.error);
    }
    final body = response.data;
    if (body is! Map) {
      return const JourneyResult(
        error: ApiError(
          code: 'INVALID_RESPONSE',
          message: 'La respuesta no coincide con el contrato de planificación.',
        ),
      );
    }
    return JourneyResult(
      plan: JourneyPlan.fromJson(Map<String, Object?>.from(body)),
    );
  }

  Future<JourneyResult> getPlan(String planId) async {
    final response = await _apiClient.get<Object?>('journeys/$planId');
    if (!response.isSuccess) return JourneyResult(error: response.error);
    final body = response.data;
    if (body is! Map) {
      return const JourneyResult(
        error: ApiError(
          code: 'INVALID_RESPONSE',
          message: 'La respuesta no coincide con el contrato de planificación.',
        ),
      );
    }
    return JourneyResult(
      plan: JourneyPlan.fromJson(Map<String, Object?>.from(body)),
    );
  }
}

class JourneyResult {
  const JourneyResult({this.plan, this.error});

  final JourneyPlan? plan;
  final ApiError? error;
}
