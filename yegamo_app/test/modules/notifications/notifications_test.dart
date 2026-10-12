import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/notifications/services/notifications_repository.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  test('deduplicates notifications and marks all read locally', () async {
    final storage = InMemoryLocalStorage();
    await storage.write(
      YeGamoStorageKeys.notifications,
      jsonEncode([
        {
          'id': 'n1',
          'title': 'Salida',
          'message': 'Es hora de salir',
          'createdAt': '2026-10-12T10:00:00Z',
          'type': 'LEAVE_ALERT',
          'read': false,
        },
        {
          'id': 'n1',
          'title': 'Salida',
          'message': 'Es hora de salir',
          'createdAt': '2026-10-12T10:00:00Z',
          'type': 'LEAVE_ALERT',
          'read': false,
        },
      ]),
    );
    final repository = NotificationsRepository(
      storage,
      testClient((_) async => jsonResponse(const <Object?>[])),
      SessionManager(storage),
    );

    expect(await repository.list(), hasLength(1));
    final result = await repository.markAllRead();
    expect(result.items.single.read, isTrue);
  });
}
