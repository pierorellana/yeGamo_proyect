import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/main.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';

Future<void> _openSearch(WidgetTester tester, ApiClient client) async {
  final storage = InMemoryLocalStorage();
  await storage.write('onboarding_completed', 'true');
  await storage.write('search_recent_queries', '["Malecón 2000"]');
  await tester.pumpWidget(
    YeGamoApp(
      localStorage: storage,
      apiClient: client,
      connectivityService: FakeConnectivityService(),
      locationService: FakeLocationService(
        permission: LocationAccess.granted,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  Navigator.of(
    tester.element(find.byType(Scaffold).first),
  ).pushNamed(AppRoutes.search);
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('search_query')), text);
  await tester.tap(find.byKey(const ValueKey('search_submit')));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('search lists recents and keeps its keys', (tester) async {
    await _openSearch(
      tester,
      testClient((_) async => jsonResponse(const <String, Object?>{})),
    );

    expect(find.text('¿A dónde vas?'), findsWidgets);
    expect(find.byKey(const ValueKey('search_query')), findsOneWidget);
    expect(find.byKey(const ValueKey('search_manual_origin')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent_Malecón 2000')), findsOneWidget);
  });

  testWidgets('search shows the empty illustration without results', (
    tester,
  ) async {
    await _openSearch(
      tester,
      testClient(
        (_) async => jsonResponse(<String, Object?>{'results': <Object?>[]}),
      ),
    );
    await _search(tester, 'Zzz');

    expect(find.text('No encontramos “Zzz”'), findsOneWidget);
    expect(find.text('Borrar búsqueda'), findsOneWidget);
  });

  testWidgets('search shows the no-coverage screen out of coverage', (
    tester,
  ) async {
    await _openSearch(
      tester,
      testClient(
        (_) async => unavailableResponse(code: 'LOCATION_OUT_OF_COVERAGE'),
      ),
    );
    await _search(tester, 'Playas');

    expect(find.text('Fuera de cobertura'), findsOneWidget);
    expect(find.text('Aún no llegamos a Playas'), findsOneWidget);
    expect(find.text('Cambiar destino'), findsOneWidget);
  });
}
