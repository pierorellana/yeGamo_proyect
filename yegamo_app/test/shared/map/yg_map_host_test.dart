import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/shared/map/yg_map_host.dart';
import 'package:yegamo_app/shared/map/yg_map_view.dart';

void main() {
  testWidgets('la superficie transparente deja pasar gestos al mapa inferior', (
    tester,
  ) async {
    var downs = 0;
    var moves = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => downs++,
              onPointerMove: (_) => moves++,
              child: const SizedBox.expand(),
            ),
            const YgMapScaffold(body: SizedBox.expand()),
          ],
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(195, 280));
    await gesture.moveBy(const Offset(80, 40));
    await gesture.up();

    expect(downs, 1);
    expect(moves, greaterThan(0));
  });

  testWidgets('la superficie sobre el Navigator traduce el arrastre al mapa', (
    tester,
  ) async {
    var pans = 0;
    var totalPan = Offset.zero;
    final controller = YgMapController()
      ..attachNativeCamera(
        zoomBy: (_) async {},
        panBy: (delta) async {
          pans++;
          totalPan += delta;
        },
        reset: () async {},
      );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => YgMapGestureSurface(
          controller: controller,
          mapBottom: 600,
          child: child!,
        ),
        home: const YgMapScaffold(body: SizedBox.expand()),
      ),
    );

    final gesture = await tester.startGesture(const Offset(195, 280));
    await gesture.moveBy(const Offset(80, 40));
    await gesture.up();

    expect(pans, greaterThan(0));
    expect(totalPan.dx, closeTo(80, 1));
    expect(totalPan.dy, closeTo(40, 1));
  });

  testWidgets(
    'la superficie traduce el pellizco a zoom nativo con sensibilidad amplia',
    (tester) async {
      var accumulatedZoom = 1.0;
      final controller = YgMapController()
        ..attachNativeCamera(
          zoomBy: (factor) async => accumulatedZoom *= factor,
          panBy: (_) async {},
          reset: () async {},
        );

      await tester.pumpWidget(
        MaterialApp(
          home: YgMapGestureSurface(
            controller: controller,
            mapBottom: 600,
            child: const SizedBox.expand(),
          ),
        ),
      );

      final first = await tester.startGesture(
        const Offset(150, 280),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(240, 280),
        pointer: 2,
      );
      await first.moveTo(const Offset(120, 280));
      await second.moveTo(const Offset(270, 280));
      await first.up();
      await second.up();

      expect(accumulatedZoom, greaterThan(2.1));
    },
  );

  testWidgets('el panel inferior conserva sus gestos fuera del mapa', (
    tester,
  ) async {
    var pans = 0;
    final controller = YgMapController()
      ..attachNativeCamera(
        zoomBy: (_) async {},
        panBy: (_) async => pans++,
        reset: () async {},
      );

    await tester.pumpWidget(
      MaterialApp(
        home: YgMapGestureSurface(
          controller: controller,
          mapBottom: 300,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(195, 500));
    await gesture.moveBy(const Offset(0, -120));
    await gesture.up();

    expect(pans, 0);
  });
}
