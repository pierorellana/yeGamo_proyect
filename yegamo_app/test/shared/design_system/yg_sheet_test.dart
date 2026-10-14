import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/shared/design_system/yg_motion.dart';
import 'package:yegamo_app/shared/design_system/yg_sheet.dart';

void main() {
  testWidgets(
    'el panel se mantiene dentro del viewport cuando aparece el teclado',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 360);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: YgMotionScope(
            reduceMotion: true,
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Stack(
                children: [
                  YgSheet(
                    config: YgSheetConfig.planner,
                    initial: YgSnap.max,
                    body: (context, snap) => const SingleChildScrollView(
                      child: Text('Contenido del planificador'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Contenido del planificador'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Contenido del planificador')).dy,
        greaterThanOrEqualTo(0),
      );
    },
  );
}
