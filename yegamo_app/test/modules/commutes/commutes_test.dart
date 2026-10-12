import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/commutes/models/commute_models.dart';
import 'package:yegamo_app/modules/commutes/services/commutes_repository.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  test('pause and resume are persisted and next alert is UTC-safe', () async {
    final storage = InMemoryLocalStorage();
    final repository = CommutesRepository(
      storage,
      testClient((_) async => jsonResponse(const <Object?>[])),
      SessionManager(storage),
    );
    final routine = CommuteRoutine(
      id: 'routine-1',
      label: 'Trabajo',
      origin: 'Casa',
      destination: 'Oficina',
      hour: 8,
      minute: 30,
      days: const [1, 2, 3, 4, 5],
      status: CommuteStatus.active,
      timeZoneName: 'America/Guayaquil',
      timeZoneOffsetMinutes: -300,
    );

    await repository.save(routine);
    final paused = await repository.setPaused(routine, true);
    expect(paused.items.single.isPaused, isTrue);
    expect(paused.items.single.nextAlertUtc(now: DateTime(2026, 10, 12, 7)), isA<DateTime>());
    final resumed = await repository.setPaused(paused.items.single, false);
    expect(resumed.items.single.status, CommuteStatus.active);
  });
}
