import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/modules/onboarding/task_five_app.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  required AppConfig config,
  LocationAccess permission = LocationAccess.denied,
  LocalStorage? storage,
}) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    TaskFiveApp(
      config: config,
      localStorage: storage ?? InMemoryLocalStorage(),
      connectivityService: FakeConnectivityService(),
      locationService: FakeLocationService(permission: permission),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

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

  testWidgets('splash muestra el pie de demostración solo con datos demo y se salta con un toque', (
    tester,
  ) async {
    await _pumpApp(tester, config: const AppConfig(demoDataEnabled: true));
    expect(find.byKey(const ValueKey('splash_continue')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text('GUAYAQUIL · DATOS DE DEMOSTRACIÓN'), findsOneWidget);
    expect(find.text('Sal a tiempo.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('splash_continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('onboarding_pages')), findsOneWidget);
  });

  testWidgets('splash sin datos demo omite el pie y avanza solo a los 3,5 s', (
    tester,
  ) async {
    await _pumpApp(tester, config: const AppConfig());
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.textContaining('DEMOSTRACIÓN'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('onboarding_pages')), findsOneWidget);
  });

  testWidgets('onboarding: tres páginas, atrás colapsa en la primera y Saltar se oculta en la última', (
    tester,
  ) async {
    await _pumpApp(tester, config: const AppConfig(reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.text('Sabe cuándo salir'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_skip')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Contigo de puerta a puerta'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Rangos honestos, no promesas'), findsOneWidget);
    expect(find.text('Empezar'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding_back')));
    await tester.pumpAndSettle();
    expect(find.text('Contigo de puerta a puerta'), findsOneWidget);
  });

  testWidgets('onboarding completo lleva a permisos y el diálogo iOS precede a la solicitud', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await _pumpApp(
      tester,
      config: const AppConfig(reduceMotion: true),
      permission: LocationAccess.granted,
      storage: storage,
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('onboarding_next')));
      await tester.pumpAndSettle();
    }
    expect(await storage.read('onboarding_completed'), 'true');
    expect(find.text('¿Usamos tu ubicación?'), findsOneWidget);
    expect(find.byKey(const ValueKey('permission_manual')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('permission_allow')));
    await tester.pumpAndSettle();
    expect(find.text('¿Permitir que “yeGamo” use tu ubicación?'), findsOneWidget);
    // El permiso real todavía no se solicitó.
    expect(await storage.read('location_permission_result'), isNull);

    await tester.tap(find.byKey(const ValueKey('permission_dialog_allow')));
    await tester.pumpAndSettle();
    expect(await storage.read('location_permission_result'), 'granted');
    expect(find.text('¿Usamos tu ubicación?'), findsNothing);
  });

  testWidgets('«No permitir» continúa con origen manual sin solicitar permiso', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await _pumpApp(
      tester,
      config: const AppConfig(reduceMotion: true),
      storage: storage,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(find.text('¿Usamos tu ubicación?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('permission_allow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('permission_dialog_deny')));
    await tester.pumpAndSettle();
    expect(await storage.read('location_permission_result'), isNull);
    expect(find.text('¿Usamos tu ubicación?'), findsNothing);
  });
}
