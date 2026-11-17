import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/notifications/services/alerts_repository.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  const planId = '2b7f5e4e-8e4a-4db7-8f9c-0f6e1d0b6c11';
  const alertId = '3c8f6f5f-9f5b-4ec8-9a0d-1a7f2e1c7d22';
  final leaveAt = DateTime.now().add(const Duration(minutes: 20));

  Future<(AlertsRepository, List<HttpRequest>)> build({
    bool signedIn = true,
    int status = 201,
  }) async {
    final storage = InMemoryLocalStorage();
    final session = SessionManager(storage);
    if (signedIn) await session.setAuthenticated(accessToken: 't');
    final requests = <HttpRequest>[];
    final repo = AlertsRepository(
      storage,
      testClient((request) async {
        requests.add(request);
        if (request.method == HttpMethod.delete) {
          return jsonResponse(null, statusCode: 204);
        }
        return status == 201
            ? jsonResponse({
                'id': alertId,
                'scheduledFor': leaveAt.toUtc().toIso8601String(),
                'status': 'SCHEDULED',
              }, statusCode: 201)
            : jsonResponse({'code': 'ALERT_ALREADY_SCHEDULED', 'message': 'Ya existe un aviso.'}, statusCode: status);
      }),
      session,
    );
    return (repo, requests);
  }

  test('schedules with the exact contract body and remembers the alert', () async {
    final (repo, requests) = await build();

    final result = await repo.schedule(planId: planId, leaveAt: leaveAt);

    expect(result.ok, isTrue);
    expect(requests.single.uri.path, '/v1/alerts/leave');
    expect(requests.single.body, {
      'journeyPlanId': planId,
      'scheduledFor': leaveAt.toUtc().toIso8601String(),
    });
    expect(requests.single.headers['Idempotency-Key'], startsWith('leave-alert-$planId-'));
    expect(await repo.scheduledFor(planId), isNotNull);
  });

  test('guests get an explicit sign-in message and nothing is sent', () async {
    final (repo, requests) = await build(signedIn: false);
    final result = await repo.schedule(planId: planId, leaveAt: leaveAt);
    expect(result.error?.code, 'AUTH_REQUIRED');
    expect(requests, isEmpty);
  });

  test('a departure time in the past is never scheduled', () async {
    final (repo, requests) = await build();
    final result = await repo.schedule(
      planId: planId,
      leaveAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    expect(result.error?.code, 'ALERT_IN_PAST');
    expect(requests, isEmpty);
  });

  test('a conflict is surfaced and nothing is remembered', () async {
    final (repo, _) = await build(status: 409);
    final result = await repo.schedule(planId: planId, leaveAt: leaveAt);
    expect(result.ok, isFalse);
    expect(await repo.scheduledFor(planId), isNull);
  });

  test('cancel deletes the alert and forgets it', () async {
    final (repo, requests) = await build();
    await repo.schedule(planId: planId, leaveAt: leaveAt);
    final result = await repo.cancel(planId);
    expect(result.cancelled, isTrue);
    expect(requests.last.method, HttpMethod.delete);
    expect(requests.last.uri.path, '/v1/alerts/$alertId');
    expect(await repo.scheduledFor(planId), isNull);
  });
}
