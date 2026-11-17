import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/main.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/navigation/app_routes.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';
import '../../support/fakes.dart';

Future<void> _openSearch(WidgetTester tester, ApiClient client) async {
  final storage = InMemoryLocalStorage();
  await storage.write('onboarding_completed', 'true');
  await storage.write('search_recent_queries', '["Malecón 2000"]');
  await tester.pumpWidget(
    YeGamoApp(
      localStorage: storage,
      apiClient: client,
      connectivityService: FakeConnectivityService(),
      locationService: FakeLocationService(permission: LocationAccess.granted),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  Navigator.of(tester.element(find.byType(Navigator).first))
      .pushNamed(AppRoutes.search);
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
  testWidgets('search waits for three characters and debounces input', (
    tester,
  ) async {
    var calls = 0;
    await _openSearch(
      tester,
      testClient((_) async {
        calls += 1;
        return jsonResponse(<Object?>[]);
      }),
    );
    final callsBeforeTyping = calls;

    await tester.enterText(find.byKey(const ValueKey('search_query')), 'te');
    await tester.pump(const Duration(milliseconds: 600));
    expect(calls, callsBeforeTyping);

    await tester.enterText(
      find.byKey(const ValueKey('search_query')),
      'terminal',
    );
    await tester.pump(const Duration(milliseconds: 499));
    expect(calls, callsBeforeTyping);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(calls, callsBeforeTyping + 1);
  });

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

  testWidgets(
    'search keeps the sheet at mid height while the field is focused',
    (tester) async {
      await _openSearch(
        tester,
        testClient((_) async => jsonResponse(<Object?>[])),
      );

      final sheet = find.byKey(const ValueKey('search_sheet'));
      final initialTop = tester.getTopLeft(sheet).dy;
      await tester.tap(find.byKey(const ValueKey('search_query')));
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.getTopLeft(sheet).dy, closeTo(initialTop, 2));
    },
  );

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

  testWidgets('search renders the canonical label and provider source', (
    tester,
  ) async {
    await _openSearch(
      tester,
      testClient(
        (_) async => jsonResponse([
          <String, Object?>{
            'id': 'place-1',
            'label': 'Malecón 2000',
            'location': <String, Object?>{'lat': -2.19, 'lon': -79.88},
            'source': 'openstreetmap-nominatim',
            'dataState': 'CURRENT',
          },
        ]),
      ),
    );
    await _search(tester, 'Malecón 2000');

    final result = find.byKey(const ValueKey('result_place-1'));
    expect(
      find.descendant(of: result, matching: find.text('Malecón 2000')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: result,
        matching: find.text('OpenStreetMap · lugar geocodificado'),
      ),
      findsOneWidget,
    );
  });
}
