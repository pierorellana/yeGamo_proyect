import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yegamo_app/main.dart';
import 'package:yegamo_app/shared/design_system/yg_components.dart';
import 'package:yegamo_app/shared/location/location_service.dart';
import 'package:yegamo_app/shared/services/connectivity_service.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

void main() {
  testWidgets('boots the shared root shell', (tester) async {
    final storage = InMemoryLocalStorage();
    await storage.write('onboarding_completed', 'true');
    await tester.pumpWidget(
      YeGamoApp(
        localStorage: storage,
        connectivityService: FakeConnectivityService(online: false),
        locationService: FakeLocationService(),
      ),
    );
    await tester.pump();

    expect(find.byType(YeGamoApp), findsOneWidget);
    expect(find.text('Inicio'), findsWidgets);
    expect(find.byType(YgTabBar), findsOneWidget);
    expect(find.byType(IndexedStack), findsOneWidget);
  });
}
