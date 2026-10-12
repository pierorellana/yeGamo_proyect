import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yegamo_app/env/theme/yegamo_theme.dart';
import 'package:yegamo_app/shared/models/data_state.dart';
import 'package:yegamo_app/shared/widgets/data_quality_badge.dart';
import 'package:yegamo_app/shared/widgets/remote_state_view.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(
    theme: YegamoTheme.dark(),
    home: Scaffold(body: child),
  );

  testWidgets('never announces LIVE without authorization and timestamp', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const DataQualityBadge(dataState: DataState.current, liveVehicle: true),
      ),
    );
    expect(find.text('EN VIVO'), findsNothing);
    expect(find.text('ACTUAL'), findsOneWidget);

    await tester.pumpWidget(
      harness(
        DataQualityBadge(
          dataState: DataState.current,
          liveVehicle: true,
          sourceAuthorized: true,
          observedAt: DateTime(2026, 10, 12),
        ),
      ),
    );
    expect(find.text('EN VIVO'), findsOneWidget);
  });

  testWidgets('renders recoverable no-coverage state with an action', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      harness(
        RemoteStateView(
          state: UxState.noCoverage,
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Sin cobertura'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);

    await tester.pumpWidget(
      harness(
        RemoteStateView(state: UxState.error, onRetry: () => retried = true),
      ),
    );
    await tester.tap(find.text('Reintentar'));
    expect(retried, isTrue);
  });

  testWidgets('every UX state renders its recoverable copy', (tester) async {
    const titles = {
      UxState.loading: 'Cargando',
      UxState.empty: 'Sin resultados',
      UxState.error: 'No se pudo cargar',
      UxState.offline: 'Sin conexión',
      UxState.stale: 'Datos desactualizados',
      UxState.degraded: 'Datos degradados',
      UxState.permission: 'Permiso de ubicación necesario',
      UxState.noCoverage: 'Sin cobertura',
    };
    for (final entry in titles.entries) {
      await tester.pumpWidget(
        harness(RemoteStateView(state: entry.key, onRetry: () {})),
      );
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('badge labels stay honest for every data state', (tester) async {
    const labels = {
      DataState.current: 'ACTUAL',
      DataState.stale: 'DESACTUALIZADO',
      DataState.degraded: 'DEGRADADO',
      DataState.offlineCache: 'OFFLINE_CACHE',
      DataState.unavailable: 'NO DISPONIBLE',
    };
    for (final entry in labels.entries) {
      await tester.pumpWidget(
        harness(
          DataQualityBadge(
            dataState: entry.key,
            liveVehicle: true,
            sourceAuthorized: true,
            observedAt: null,
          ),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('EN VIVO'), findsNothing);
    }
  });
}
