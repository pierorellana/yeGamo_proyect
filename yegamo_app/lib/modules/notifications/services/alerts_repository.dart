import 'dart:convert';

import '../../../shared/models/api_error.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/session/session_service.dart';
import '../../../shared/storage/local_storage.dart';

class LeaveAlertResult {
  const LeaveAlertResult({this.scheduledFor, this.error, this.cancelled = false});

  final DateTime? scheduledFor;
  final ApiError? error;
  final bool cancelled;
  bool get ok => error == null;
}

/// Avisos de «hora de salir» (`POST /v1/alerts/leave`, `DELETE /v1/alerts/{id}`).
/// Solo se programan con una hora de salida real del plan: nunca se estima una.
class AlertsRepository {
  AlertsRepository(this._storage, this._apiClient, this._session);

  final LocalStorage _storage;
  final ApiClient _apiClient;
  final SessionManager _session;

  /// Aviso pendiente para [planId], si existe.
  Future<DateTime?> scheduledFor(String planId) async {
    final entry = (await _read())[planId];
    return entry == null ? null : DateTime.tryParse(entry['scheduledFor'] ?? '');
  }

  Future<LeaveAlertResult> schedule({
    required String planId,
    required DateTime leaveAt,
    DateTime? now,
  }) async {
    if (!_session.isAuthenticated) {
      return const LeaveAlertResult(
        error: ApiError(
          code: 'AUTH_REQUIRED',
          message: 'Inicia sesión para recibir avisos de salida.',
        ),
      );
    }
    if (!leaveAt.isAfter(now ?? DateTime.now())) {
      return const LeaveAlertResult(
        error: ApiError(
          code: 'ALERT_IN_PAST',
          message: 'La hora de salida ya pasó; calcula el plan de nuevo.',
        ),
      );
    }
    final scheduled = leaveAt.toUtc();
    final response = await _apiClient.post<Object?>(
      'alerts/leave',
      body: {
        'journeyPlanId': planId,
        'scheduledFor': scheduled.toIso8601String(),
      },
      // Misma clave para el mismo plan y hora: reintentos y toques repetidos no duplican.
      idempotencyKey: 'leave-alert-$planId-${scheduled.millisecondsSinceEpoch ~/ 60000}',
    );
    final body = response.data;
    if (!response.isSuccess || body is! Map || body['id'] is! String) {
      return LeaveAlertResult(
        error: response.error ??
            const ApiError(
              code: 'INVALID_RESPONSE',
              message: 'La respuesta del aviso no coincide con el contrato.',
            ),
      );
    }
    final entries = await _read();
    entries[planId] = {
      'id': body['id'] as String,
      'scheduledFor': scheduled.toIso8601String(),
    };
    await _write(entries);
    return LeaveAlertResult(scheduledFor: scheduled);
  }

  Future<LeaveAlertResult> cancel(String planId) async {
    final entries = await _read();
    final entry = entries[planId];
    if (entry == null) return const LeaveAlertResult(cancelled: true);
    final response = await _apiClient.delete<Object?>(
      'alerts/${entry['id']}',
      idempotencyKey: 'leave-alert-cancel-${entry['id']}',
    );
    if (!response.isSuccess && response.error?.statusCode != 404) {
      return LeaveAlertResult(error: response.error);
    }
    entries.remove(planId);
    await _write(entries);
    return const LeaveAlertResult(cancelled: true);
  }

  Future<Map<String, Map<String, String>>> _read() async {
    final raw = await _storage.read(YeGamoStorageKeys.leaveAlerts);
    if (raw == null) return {};
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return {};
      return {
        for (final e in value.entries)
          if (e.value is Map)
            e.key as String: Map<String, String>.from(
              (e.value as Map).map((k, v) => MapEntry('$k', '$v')),
            ),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> _write(Map<String, Map<String, String>> entries) =>
      _storage.write(YeGamoStorageKeys.leaveAlerts, jsonEncode(entries));
}
