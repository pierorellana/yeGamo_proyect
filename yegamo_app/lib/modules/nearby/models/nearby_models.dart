import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';

class NearbyStop {
  const NearbyStop({
    required this.id,
    required this.name,
    required this.distanceM,
    required this.dataState,
  });

  final String id;
  final String name;
  final double? distanceM;
  final DataState dataState;

  factory NearbyStop.fromJson(Map<String, Object?> json) {
    return NearbyStop(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Parada sin nombre',
      distanceM: _number(json['distanceM']),
      dataState:
          DataStateParsing.fromApiValue(json['dataState']) ?? DataState.current,
    );
  }

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
    this.error,
  });

  final UxState state;
  final List<NearbyStop> stops;
  final ApiError? error;
}
