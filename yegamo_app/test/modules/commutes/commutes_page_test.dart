import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yegamo_app/env/theme/yegamo_theme.dart';
import 'package:yegamo_app/modules/commutes/models/commute_models.dart';
import 'package:yegamo_app/modules/commutes/pages/commutes_page.dart';
import 'package:yegamo_app/modules/commutes/providers/commutes_view_model.dart';
import 'package:yegamo_app/modules/commutes/services/commutes_repository.dart';
import 'package:yegamo_app/modules/commutes/widgets/routine_widgets.dart';
import 'package:yegamo_app/shared/design_system/yg_components.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

CommuteRoutine routine({CommuteStatus status = CommuteStatus.active}) => CommuteRoutine(
  id: 'r1',
  label: 'Ida al trabajo',
  origin: 'Casa',
  destination: 'Trabajo',
  hour: 7,
  minute: 32,
  days: const [1, 2, 3, 4, 5],
  status: status,
  timeZoneName: 'ECT',
  timeZoneOffsetMinutes: -300,
);

void main() {
  test('next alert text never invents a time', () {
    final now = DateTime(2026, 10, 12, 6); // lunes
    expect(nextAlertText(routine(), now: now), 'Hoy · aviso 07:32');
    expect(nextAlertText(routine(status: CommuteStatus.paused), now: now), 'En pausa · sin avisos');
  });

  testWidgets('routine card toggles and persists the paused state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final storage = InMemoryLocalStorage();
    final repository = CommutesRepository(
      storage,
      testClient((_) async => jsonResponse(const <Object?>[])),
      SessionManager(storage),
    );
    await repository.save(routine());
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CommutesViewModel(repository),
        child: MaterialApp(
          theme: YegamoTheme.light(reduceMotion: true),
          builder: (context, child) => YgMotionScope(reduceMotion: true, child: child!),
          home: const CommutesPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ida al trabajo'), findsOneWidget);
    expect(find.text('Casa → Trabajo'), findsOneWidget);

    await tester.tap(find.byType(YgSwitch));
    await tester.pump(const Duration(milliseconds: 300));
    expect((await repository.list()).single.isPaused, isTrue);
    expect(find.text('En pausa · sin avisos'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
