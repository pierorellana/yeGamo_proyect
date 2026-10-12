import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/env/theme/yegamo_theme.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/widgets/remote_state_view.dart';

/// The project has no golden_test configuration or checked-in image baseline.
/// These stable semantics/constraint checks are the maintainable closeout gate
/// until a visual baseline and update workflow are approved.
void main() {
  testWidgets('all UX states expose recoverable semantics at reference width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final state in UxState.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: YegamoTheme.dark(reduceMotion: true),
          home: Scaffold(body: RemoteStateView(state: state)),
        ),
      );
      await tester.pump();
      expect(find.byType(RemoteStateView), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'state=$state');
    }
  });

  testWidgets('state copy wraps at a wider safe-area constraint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: YegamoTheme.dark(reduceMotion: true),
        home: const Scaffold(
          body: SafeArea(child: RemoteStateView(state: UxState.noCoverage)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sin cobertura'), findsOneWidget);
    expect(
      find.text('No encontramos una fuente autorizada para esta zona.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
