import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';

class PlaceResult {
  const PlaceResult({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.dataState,
    this.source,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DataState dataState;
  final String? source;

  factory PlaceResult.fromJson(Map<String, Object?> json) {
    final location = json['location'] is Map
        ? Map<String, Object?>.from(json['location'] as Map)
        : const <String, Object?>{};
    return PlaceResult(
      id: json['id'] as String? ?? 'unknown',
      name:
          json['label'] as String? ??
          json['name'] as String? ??
          'Lugar sin nombre',
      latitude: _number(location['lat'] ?? json['lat']) ?? 0,
      longitude: _number(location['lon'] ?? json['lon']) ?? 0,
      dataState:
          DataStateParsing.fromApiValue(json['dataState']) ?? DataState.current,
      source: json['source'] as String?,
    );
  }

  static double? _number(Object? value) => switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };
}

class SearchSnapshot {
  const SearchSnapshot({
    required this.state,
    this.results = const <PlaceResult>[],
    this.recentQueries = const <String>[],
    this.error,
  });

  final UxState state;
  final List<PlaceResult> results;
  final List<String> recentQueries;
  final ApiError? error;
}
