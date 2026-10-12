import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/env/theme/yegamo_theme.dart';
import 'package:yegamo_app/modules/settings/pages/settings_page.dart';
import 'package:yegamo_app/modules/settings/providers/settings_view_model.dart';
import 'package:yegamo_app/modules/settings/services/settings_repository.dart';
import 'package:yegamo_app/shared/design_system/yg_components.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

Future<void> pumpSettings(WidgetTester tester, AppConfig config) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final storage = InMemoryLocalStorage();
  final session = SessionManager(storage);
  final repository = SettingsRepository(
    storage,
    testClient((_) async => jsonResponse(const <String, Object?>{})),
    session,
    config,
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => SettingsViewModel(repository)),
      ],
      child: MaterialApp(
        theme: YegamoTheme.light(reduceMotion: true),
        builder: (context, child) => YgMotionScope(reduceMotion: true, child: child!),
        home: const SettingsPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('hides the demo catalog unless demo data is enabled', (tester) async {
    await pumpSettings(tester, const AppConfig());
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Modo invitado'), findsOneWidget);
    expect(find.text('Catálogo de estados de desarrollo'.toUpperCase()), findsNothing);
  });

  testWidgets('shows the demo catalog only with the explicit flag', (tester) async {
    await pumpSettings(tester, const AppConfig(demoDataEnabled: true));
    expect(find.text('Catálogo de estados de desarrollo'.toUpperCase()), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
  });

  testWidgets('location consent switch persists without coordinates', (tester) async {
    await pumpSettings(tester, const AppConfig());
    await tester.tap(find.byType(YgSwitch));
    await tester.pump(const Duration(milliseconds: 300));
    final vm = tester.element(find.byType(SettingsPage)).read<SettingsViewModel>();
    expect(vm.state!.locationConsent, isTrue);
  });
}
