import 'dart:math';

import '../../planner/models/planner_models.dart';

enum CommuteStatus { active, paused }

class CommuteRoutine {
  const CommuteRoutine({
    required this.id,
    required this.label,
    required this.origin,
    required this.destination,
    required this.hour,
    required this.minute,
    required this.days,
    required this.status,
    required this.timeZoneName,
    required this.timeZoneOffsetMinutes,
    this.originPoint,
    this.destinationPoint,
  });

  final String id;
  final String label;
  final String origin;
  final String destination;
  final int hour;
  final int minute;
  final List<int> days;
  final CommuteStatus status;
  final String timeZoneName;
  final int timeZoneOffsetMinutes;

  /// Coordenadas canónicas; sin ellas la rutina solo existe en este dispositivo.
  final JourneyPoint? originPoint;
  final JourneyPoint? destinationPoint;

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  bool get hasLocations => originPoint != null && destinationPoint != null;
  bool get isRemote => _uuid.hasMatch(id);

  /// Interpreta «lat, lon» escrito a mano (mismo formato que el planificador).
  static JourneyPoint? parsePoint(String text) {
    final match = RegExp(
      r'^\s*(-?\d+(?:\.\d+)?)\s*[,; ]\s*(-?\d+(?:\.\d+)?)\s*$',
    ).firstMatch(text);
    if (match == null) return null;
    final lat = double.parse(match.group(1)!);
    final lon = double.parse(match.group(2)!);
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return JourneyPoint(latitude: lat, longitude: lon);
  }

  String get targetArrival =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Cuerpo de `POST/PATCH /v1/commute-profiles` (name, origin, destination,
  /// weekdays, targetArrival). Requiere [hasLocations].
  Map<String, Object?> toApiJson() {
    assert(hasLocations, 'Una rutina sin coordenadas no puede sincronizarse.');
    return {
      'name': label,
      'origin': originPoint!.toJson(),
      'destination': destinationPoint!.toJson(),
      'weekdays': days,
      'targetArrival': targetArrival,
    };
  }

  bool get isPaused => status == CommuteStatus.paused;

  CommuteRoutine copyWith({String? id, CommuteStatus? status}) => CommuteRoutine(
    id: id ?? this.id,
    label: label,
    origin: origin,
    destination: destination,
    hour: hour,
    minute: minute,
    days: days,
    status: status ?? this.status,
    timeZoneName: timeZoneName,
    timeZoneOffsetMinutes: timeZoneOffsetMinutes,
    originPoint: originPoint,
    destinationPoint: destinationPoint,
  );

  /// Acepta tanto el almacenamiento local como el `CommuteProfile` del API
  /// (`name`, `origin`/`destination` como GeoPoint, `weekdays`, `targetArrival`,
  /// `enabled`).
  factory CommuteRoutine.fromJson(Map<String, Object?> json) {
    if (json['weekdays'] is List) return CommuteRoutine._fromApi(json);
    return CommuteRoutine._fromLocal(json);
  }

  factory CommuteRoutine._fromApi(Map<String, Object?> json) {
    final origin = JourneyPoint.tryParse(json['origin']);
    final destination = JourneyPoint.tryParse(json['destination']);
    final time = RegExp(
      r'^(\d{2}):(\d{2})',
    ).firstMatch(json['targetArrival'] as String? ?? '');
    String describe(JourneyPoint? p) => p == null
        ? 'Ubicación guardada'
        : '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';
    return CommuteRoutine(
      id: json['id'] as String? ?? 'routine-${Random().nextInt(999999)}',
      label: json['name'] as String? ?? 'Rutina',
      origin: describe(origin),
      destination: describe(destination),
      hour: int.tryParse(time?.group(1) ?? '') ?? 8,
      minute: int.tryParse(time?.group(2) ?? '') ?? 0,
      days: (json['weekdays'] as List).whereType<num>().map((d) => d.toInt()).toList(),
      status: json['enabled'] == false ? CommuteStatus.paused : CommuteStatus.active,
      // El API fija la zona horaria del perfil (America/Guayaquil).
      timeZoneName: 'America/Guayaquil',
      timeZoneOffsetMinutes: -300,
      originPoint: origin,
      destinationPoint: destination,
    );
  }

  factory CommuteRoutine._fromLocal(Map<String, Object?> json) => CommuteRoutine(
    id: json['id'] as String? ?? 'routine-${Random().nextInt(999999)}',
    label: json['label'] as String? ?? 'Rutina',
    origin: json['origin'] as String? ?? 'Origen manual',
    destination: json['destination'] as String? ?? 'Destino manual',
    hour: (json['hour'] as num?)?.toInt() ?? 8,
    minute: (json['minute'] as num?)?.toInt() ?? 0,
    days: (json['days'] as List?)?.whereType<num>().map((day) => day.toInt()).toList() ?? const [1, 2, 3, 4, 5],
    status: json['status'] == CommuteStatus.paused.name
        ? CommuteStatus.paused
        : CommuteStatus.active,
    timeZoneName: json['timeZoneName'] as String? ?? DateTime.now().timeZoneName,
    timeZoneOffsetMinutes:
        (json['timeZoneOffsetMinutes'] as num?)?.toInt() ??
        DateTime.now().timeZoneOffset.inMinutes,
    originPoint: JourneyPoint.tryParse(json['originPoint']),
    destinationPoint: JourneyPoint.tryParse(json['destinationPoint']),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'origin': origin,
    'destination': destination,
    'hour': hour,
    'minute': minute,
    'days': days,
    'status': status.name,
    'timeZoneName': timeZoneName,
    'timeZoneOffsetMinutes': timeZoneOffsetMinutes,
    if (originPoint != null) 'originPoint': originPoint!.toJson(),
    if (destinationPoint != null) 'destinationPoint': destinationPoint!.toJson(),
  };

  DateTime nextAlertUtc({DateTime? now}) {
    final current = now ?? DateTime.now();
    final localNow = current.toLocal();
    for (var delta = 0; delta <= 7; delta++) {
      final candidateDate = DateTime(
        localNow.year,
        localNow.month,
        localNow.day + delta,
        hour,
        minute,
      );
      if (days.contains(candidateDate.weekday) && candidateDate.isAfter(localNow)) {
        return candidateDate.toUtc();
      }
    }
    return DateTime(localNow.year, localNow.month, localNow.day + 7, hour, minute).toUtc();
  }
}

class CommutesState {
  const CommutesState({this.items = const [], this.message});

  final List<CommuteRoutine> items;
  final String? message;
}
