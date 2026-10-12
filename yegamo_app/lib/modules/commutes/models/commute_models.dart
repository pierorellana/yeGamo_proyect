import 'dart:math';

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

  bool get isPaused => status == CommuteStatus.paused;

  CommuteRoutine copyWith({CommuteStatus? status}) => CommuteRoutine(
    id: id,
    label: label,
    origin: origin,
    destination: destination,
    hour: hour,
    minute: minute,
    days: days,
    status: status ?? this.status,
    timeZoneName: timeZoneName,
    timeZoneOffsetMinutes: timeZoneOffsetMinutes,
  );

  factory CommuteRoutine.fromJson(Map<String, Object?> json) => CommuteRoutine(
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
