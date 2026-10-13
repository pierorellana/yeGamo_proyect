import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/env/config/app_config.dart';

void main() {
  test('test config conserva el mapa ilustrado por defecto', () {
    const config = AppConfig();

    expect(config.realMapEnabled, isFalse);
    expect(config.mapStyleUrl, isEmpty);
    expect(config.mapTileUrl, contains('{z}/{x}/{y}'));
  });

  test('runtime config usa el estilo raster fallback por defecto', () {
    final config = AppConfig.fromEnvironment();

    expect(config.realMapEnabled, isTrue);
    expect(config.mapStyleUrl, isEmpty);
    expect(config.mapTileUrl, contains('{z}/{x}/{y}'));
  });
}
