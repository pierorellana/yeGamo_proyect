import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yegamo_app/env/theme/yegamo_theme.dart';
import 'package:yegamo_app/modules/saved/models/saved_models.dart';
import 'package:yegamo_app/modules/saved/pages/saved_page.dart';
import 'package:yegamo_app/modules/saved/providers/saved_view_model.dart';
import 'package:yegamo_app/modules/saved/services/saved_places_repository.dart';
import 'package:yegamo_app/shared/design_system/yg_components.dart';
import 'package:yegamo_app/shared/navigation/app_navigator.dart';
import 'package:yegamo_app/shared/session/session_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

Future<void> pumpSaved(WidgetTester tester, InMemoryLocalStorage storage) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final session = SessionManager(storage);
  final repository = SavedPlacesRepository(
    storage,
    testClient((_) async => jsonResponse(const <Object?>[])),
    session,
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => SavedViewModel(repository)),
        ChangeNotifierProvider(create: (_) => AppShellController()),
      ],
      child: MaterialApp(
        theme: YegamoTheme.light(reduceMotion: true),
        builder: (context, child) => YgMotionScope(reduceMotion: true, child: child!),
        home: const SavedPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('shows the prototype empty state with its illustration', (tester) async {
    await pumpSaved(tester, InMemoryLocalStorage());
    expect(find.text('Guardados'), findsOneWidget);
    expect(find.text('Aún no tienes lugares'), findsOneWidget);
    expect(find.text('Añadir Casa'), findsOneWidget);
  });

  testWidgets('pins Casa and lists other places with a delete action', (tester) async {
    final storage = InMemoryLocalStorage();
    await SavedPlacesRepository(
      storage,
      testClient((_) async => jsonResponse(const <Object?>[])),
      SessionManager(storage),
    ).add(const SavedPlace(id: 'casa', label: 'Casa', subtitle: 'Urdesa'));
    await SavedPlacesRepository(
      storage,
      testClient((_) async => jsonResponse(const <Object?>[])),
      SessionManager(storage),
    ).add(const SavedPlace(id: 'gym', label: 'Gimnasio'));
    await pumpSaved(tester, storage);

    expect(find.text('Otros lugares'.toUpperCase()), findsOneWidget);
    expect(find.bySemanticsLabel('Eliminar Casa'), findsOneWidget);
    expect(find.bySemanticsLabel('Eliminar Gimnasio'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Eliminar Gimnasio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Gimnasio'), findsNothing);
  });
}
