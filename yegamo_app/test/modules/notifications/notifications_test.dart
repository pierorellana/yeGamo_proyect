import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/notifications/models/notification_models.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
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
          'body': 'Es hora de salir',
          'createdAt': '2026-10-12T10:00:00Z',
          'type': 'LEAVE_ALERT',
          'isRead': false,
        },
        {
          'id': 'n1',
          'title': 'Salida',
          'body': 'Es hora de salir',
          'createdAt': '2026-10-12T10:00:00Z',
          'type': 'LEAVE_ALERT',
          'isRead': false,
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

  test('reads the API isRead flag, round-trips the cache and syncs read state', () async {
    const id = '2b7f5e4e-8e4a-4db7-8f9c-0f6e1d0b6c11';
    final storage = InMemoryLocalStorage();
    final session = SessionManager(storage);
    await session.setAuthenticated(accessToken: 't');
    final requests = <HttpRequest>[];
    final repository = NotificationsRepository(
      storage,
      testClient((request) async {
        requests.add(request);
        if (request.method == HttpMethod.get) {
          return jsonResponse({
            'items': [
              {
                'id': id,
                'type': 'LEAVE_ALERT',
                'title': 'Sal ya',
                'body': 'Hora de salir',
                'isRead': true,
                'createdAt': '2026-11-17T12:00:00.000Z',
              },
            ],
            'page': 1,
            'pageSize': 20,
            'total': 1,
            'hasNext': false,
          });
        }
        return jsonResponse(null, statusCode: 204);
      }),
      session,
    );

    final remote = await repository.list();
    expect(remote.single.read, isTrue);
    expect(remote.single.kind, NotificationKind.leaveAlert);
    expect(remote.single.message, 'Hora de salir');

    // La caché local conserva el estado de lectura y el tipo del servidor.
    final cached = jsonDecode((await storage.read(YeGamoStorageKeys.notifications))!) as List;
    expect((cached.single as Map)['isRead'], isTrue);
    expect((cached.single as Map)['type'], 'LEAVE_ALERT');

    await repository.markRead(id);
    expect(requests.last.method, HttpMethod.patch);
    expect(requests.last.uri.path, '/v1/notifications/$id/read');
  });
}
