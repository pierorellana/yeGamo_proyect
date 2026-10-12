import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yegamo_app/env/theme/yegamo_theme.dart';
import 'package:yegamo_app/modules/notifications/models/notification_models.dart';
import 'package:yegamo_app/modules/notifications/pages/notifications_page.dart';
import 'package:yegamo_app/modules/notifications/providers/notifications_view_model.dart';
import 'package:yegamo_app/modules/notifications/services/notifications_repository.dart';
import 'package:yegamo_app/modules/notifications/widgets/notification_widgets.dart';
import 'package:yegamo_app/shared/design_system/yg_components.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

void main() {
  test('groups notifications by day, newest first', () {
    final now = DateTime(2026, 10, 12, 18);
    final groups = groupByDay([
      NotificationItem(id: 'a', title: 'A', message: '', createdAt: DateTime(2026, 10, 11, 9), kind: NotificationKind.service),
      NotificationItem(id: 'b', title: 'B', message: '', createdAt: DateTime(2026, 10, 12, 8), kind: NotificationKind.leaveAlert),
      NotificationItem(id: 'c', title: 'C', message: '', createdAt: DateTime(2026, 10, 12, 9), kind: NotificationKind.journey),
    ], now: now);
    expect(groups.map((g) => g.$1), ['Hoy', 'Ayer']);
    expect(groups.first.$2.map((n) => n.id), ['c', 'b']);
  });

  testWidgets('empty state and mark-all-read', (tester) async {
    final storage = InMemoryLocalStorage();
    final repository = NotificationsRepository(
      storage,
      testClient((_) async => jsonResponse(const <Object?>[])),
      SessionManager(storage),
    );
    Future<void> pump() async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => NotificationsViewModel(repository),
          child: MaterialApp(
            theme: YegamoTheme.light(reduceMotion: true),
            builder: (context, child) => YgMotionScope(reduceMotion: true, child: child!),
            home: const NotificationsPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await pump();
    expect(find.text('Todo tranquilo'), findsOneWidget);
    expect(find.text('Marcar todo leído'), findsNothing);
  });
}
