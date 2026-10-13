import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/shared/design_system/yg_surfaces.dart';

void main() {
  testWidgets('YgGlass can render a map-safe surface without backdrop blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: YgGlass(blur: 0, child: SizedBox(key: Key('surface'))),
      ),
    );

    expect(find.byKey(const Key('surface')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('YgGlass keeps backdrop blur when enabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: YgGlass(child: SizedBox())),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
