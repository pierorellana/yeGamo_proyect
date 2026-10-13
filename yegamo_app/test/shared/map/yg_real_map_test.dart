import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/env/config/app_config.dart';
import 'package:yegamo_app/shared/map/yg_map_style.dart';

void main() {
  test('fallback style uses configurable OSM raster tiles', () {
    final style = jsonDecode(
      YgMapStyle.fallback(tileUrl: 'https://tiles.test/{z}/{x}/{y}.png'),
    ) as Map<String, dynamic>;
    final sources = style['sources'] as Map<String, dynamic>;
    final base = sources['yegamo-base'] as Map<String, dynamic>;

    expect(base['type'], 'raster');
    expect(base['tiles'], contains('https://tiles.test/{z}/{x}/{y}.png'));
    expect(base['attribution'], contains('OpenStreetMap contributors'));
    expect(style['layers'], isNotEmpty);
  });

  test('real map is disabled in the test config', () {
    expect(const AppConfig().realMapEnabled, isFalse);
  });
}
