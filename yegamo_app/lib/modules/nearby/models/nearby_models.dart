import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';
import '../../../shared/location/location_service.dart';

class NearbyStop {
  const NearbyStop({
    required this.id,
    required this.name,
    required this.distanceM,
    required this.dataState,
    this.source,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final double? distanceM;
  final DataState dataState;
  final String? source;
  final double? latitude;
  final double? longitude;

  factory NearbyStop.fromJson(Map<String, Object?> json) {
    return NearbyStop(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Parada sin nombre',
      distanceM: _number(json['distanceM']),
      dataState:
          DataStateParsing.fromApiValue(json['dataState']) ?? DataState.current,
      source: json['source'] as String?,
      latitude: _number(_location(json)['lat'] ?? json['lat']),
      longitude: _number(_location(json)['lon'] ?? json['lon']),
    );
  }

  static Map<String, Object?> _location(Map<String, Object?> json) =>
      json['location'] is Map
      ? Map<String, Object?>.from(json['location'] as Map)
      : const <String, Object?>{};

  static double? _number(Object? value) => switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };
}

class NearbySnapshot {
  const NearbySnapshot({
    required this.state,
    this.stops = const <NearbyStop>[],
    this.origin,
    this.error,
  });

  final UxState state;
  final List<NearbyStop> stops;
  final GeoCoordinate? origin;
  final ApiError? error;
}
