import 'dart:convert';

abstract final class YgMapStyle {
  static String fallback({required String tileUrl}) {
    return jsonEncode(<String, Object?>{
      'version': 8,
      'name': 'yeGamo OSM fallback',
      'sources': <String, Object?>{
        'yegamo-base': <String, Object?>{
          'type': 'raster',
          'tiles': <String>[tileUrl],
          'tileSize': 256,
          'attribution': '© OpenStreetMap contributors',
        },
        'yegamo-stops': <String, Object?>{
          'type': 'geojson',
          'data': _emptyFeatureCollection,
        },
        'yegamo-places': <String, Object?>{
          'type': 'geojson',
          'data': _emptyFeatureCollection,
        },
      },
      'layers': <Object?>[
        <String, Object?>{
          'id': 'yegamo-background',
          'type': 'background',
          'paint': <String, Object?>{
            'background-color': '#E8EEE8',
          },
        },
        <String, Object?>{
          'id': 'yegamo-base',
          'type': 'raster',
          'source': 'yegamo-base',
        },
        <String, Object?>{
          'id': 'yegamo-stops',
          'type': 'circle',
          'source': 'yegamo-stops',
          'paint': <String, Object?>{
            'circle-radius': 7,
            'circle-color': '#4C583E',
            'circle-stroke-color': '#FFFFFF',
            'circle-stroke-width': 2,
            'circle-opacity': <Object?>[
              'match',
              <Object?>['get', 'dataState'],
              'CURRENT',
              1,
              0.55,
            ],
          },
        },
        <String, Object?>{
          'id': 'yegamo-places',
          'type': 'circle',
          'source': 'yegamo-places',
          'paint': <String, Object?>{
            'circle-radius': 8,
            'circle-color': '#9C4F3A',
            'circle-stroke-color': '#FFFFFF',
            'circle-stroke-width': 2,
            'circle-opacity': <Object?>[
              'match',
              <Object?>['get', 'dataState'],
              'CURRENT',
              1,
              0.55,
            ],
          },
        },
      ],
    });
  }

  static const Map<String, Object?> _emptyFeatureCollection = <String, Object?>{
    'type': 'FeatureCollection',
    'features': <Object?>[],
  };
}
