import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/modules/onboarding/task_five_app.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

Future<void> _loadGeist() async {
  final geist = FontLoader('Geist');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Geist-$w.ttf').readAsBytesSync();
    geist.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await geist.load();
}

void main() {
  setUpAll(_loadGeist);

  testWidgets('permiso denegado deja el banner recuperable y el origen manual', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = InMemoryLocalStorage();
    await storage.write('onboarding_completed', 'true');
    await tester.pumpWidget(
      TaskFiveApp(
        config: const AppConfig(reduceMotion: true),
        localStorage: storage,
        connectivityService: FakeConnectivityService(),
        locationService: FakeLocationService(permission: LocationAccess.denied),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushReplacementNamed(AppRoutes.permissions);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('permission_allow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('permission_dialog_once')));
    await tester.pumpAndSettle();

    expect(find.text('Puedes continuar con un origen manual.'), findsOneWidget);
    expect(find.byKey(const ValueKey('permission_manual')), findsOneWidget);
    expect(await storage.read('precise_location'), isNull);
  });
}
