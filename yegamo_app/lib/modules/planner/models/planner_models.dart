import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';

enum TimeMode { leaveNow, departAt, arriveBy }

enum TravelPreference {
  balanced,
  fastest,
  lessWalking,
  fewerTransfers,
  reliable,
}

extension TimeModeApi on TimeMode {
  String get apiValue => switch (this) {
    TimeMode.leaveNow => 'LEAVE_NOW',
    TimeMode.departAt => 'DEPART_AT',
    TimeMode.arriveBy => 'ARRIVE_BY',
  };
}

extension TravelPreferenceApi on TravelPreference {
  String get apiValue => switch (this) {
    TravelPreference.balanced => 'BALANCED',
    TravelPreference.fastest => 'FASTEST',
    TravelPreference.lessWalking => 'LESS_WALKING',
    TravelPreference.fewerTransfers => 'FEWER_TRANSFERS',
    TravelPreference.reliable => 'RELIABLE',
  };
}

class JourneyPoint {
  const JourneyPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => <String, Object?>{
    'lat': latitude,
    'lon': longitude,
  };

  static JourneyPoint? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'];
    final lon = raw['lon'];
    if (lat is! num || lon is! num) return null;
    return JourneyPoint(latitude: lat.toDouble(), longitude: lon.toDouble());
  }
}

class JourneyPlanRequest {
  const JourneyPlanRequest({
    required this.origin,
    required this.destination,
    required this.timeMode,
    this.time,
    this.preference = TravelPreference.balanced,
    this.maxWalkMin = 12,
    this.extraSafetyMarginMin = 0,
  });

  final JourneyPoint origin;
  final JourneyPoint destination;
  final TimeMode timeMode;
  final DateTime? time;
  final TravelPreference preference;
  final int maxWalkMin;
  final int extraSafetyMarginMin;

  Map<String, Object?> toJson() => <String, Object?>{
    'origin': origin.toJson(),
    'destination': destination.toJson(),
    'timeMode': timeMode.apiValue,
    if (time != null) 'time': time!.toUtc().toIso8601String(),
    'preference': preference.apiValue,
    'maxWalkMin': maxWalkMin,
    'extraSafetyMarginMin': extraSafetyMarginMin,
  };
}

class JourneyDataQuality {
  const JourneyDataQuality({
    required this.dataState,
    required this.liveVehicle,
    required this.sourceAuthorized,
    this.observedAt,
    this.providerDisplayName,
  });

  final DataState dataState;
  final bool liveVehicle;
  final bool sourceAuthorized;
  final DateTime? observedAt;
  final String? providerDisplayName;

  Map<String, Object?> toJson() => <String, Object?>{
    'dataState': dataState.apiValue,
    'liveVehicle': liveVehicle,
    'sourceAuthorized': sourceAuthorized,
    'observedAt': observedAt?.toUtc().toIso8601String(),
    'providerDisplayName': providerDisplayName,
  };

  factory JourneyDataQuality.fromJson(Map<String, Object?> json) {
    return JourneyDataQuality(
      dataState:
          DataStateParsing.fromApiValue(json['dataState']) ??
          DataState.unavailable,
      liveVehicle: json['liveVehicle'] == true,
      sourceAuthorized: json['sourceAuthorized'] == true,
      observedAt: _date(json['observedAt']),
      providerDisplayName: json['providerDisplayName'] as String?,
    );
  }
}

class JourneyLeg {
  const JourneyLeg({
    required this.mode,
    required this.durationMin,
    this.instructions = const [],
    this.departureAt,
    this.arrivalAt,
    this.from,
    this.to,
    this.routeId,
    this.fromStopId,
    this.toStopId,
  });

  final String mode;
  final int durationMin;
  final List<String> instructions;
  final DateTime? departureAt;
  final DateTime? arrivalAt;
  final JourneyPoint? from;
  final JourneyPoint? to;
  final String? routeId;
  final String? fromStopId;
  final String? toStopId;

  factory JourneyLeg.fromJson(Map<String, Object?> json) {
    return JourneyLeg(
      mode: json['mode'] as String? ?? 'WALK',
      durationMin: (json['durationMin'] as num?)?.toInt() ?? 0,
      instructions:
          (json['instructions'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      departureAt: _date(json['departureAt']),
      arrivalAt: _date(json['arrivalAt']),
      from: JourneyPoint.tryParse(json['from']),
      to: JourneyPoint.tryParse(json['to']),
      routeId: json['routeId'] as String?,
      fromStopId: json['fromStopId'] as String?,
      toStopId: json['toStopId'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode,
    'durationMin': durationMin,
    'instructions': instructions,
    'departureAt': departureAt?.toUtc().toIso8601String(),
    'arrivalAt': arrivalAt?.toUtc().toIso8601String(),
    if (from != null) 'from': from!.toJson(),
    if (to != null) 'to': to!.toJson(),
    'routeId': routeId,
    'fromStopId': fromStopId,
    'toStopId': toStopId,
  };
}

class JourneyOption {
  const JourneyOption({
    required this.id,
    required this.durationMin,
    required this.walkMin,
    required this.transfers,
    required this.reliabilityScore,
    required this.dataQuality,
    required this.legs,
    this.reliabilityLevel,
    this.reliabilitySamples,
  });

  final String id;
  final int durationMin;
  final int walkMin;
  final int transfers;
  final int reliabilityScore;
  final JourneyDataQuality dataQuality;
  final List<JourneyLeg> legs;

  /// `HIGH`, `MEDIUM`, `LOW` o `UNKNOWN` tal como lo entrega el API.
  final String? reliabilityLevel;

  /// Viajes observados que respaldan la fiabilidad (`sampleSize`).
  final int? reliabilitySamples;

  /// Solo se muestra la fiabilidad cuando el API la respalda con datos.
  bool get hasReliability =>
      reliabilityLevel != 'UNKNOWN' &&
      (reliabilityScore > 0 || (reliabilitySamples ?? 0) > 0);

  factory JourneyOption.fromJson(Map<String, Object?> json) {
    final reliability = json['reliability'] is Map
        ? Map<String, Object?>.from(json['reliability'] as Map)
        : const <String, Object?>{};
    final quality = json['dataQuality'] is Map
        ? Map<String, Object?>.from(json['dataQuality'] as Map)
        : const <String, Object?>{};
    final legs = json['legs'] is List
        ? (json['legs'] as List)
              .whereType<Map>()
              .map(
                (value) =>
                    JourneyLeg.fromJson(Map<String, Object?>.from(value)),
              )
              .toList(growable: false)
        : const <JourneyLeg>[];
    return JourneyOption(
      id: json['id'] as String? ?? 'unknown',
      durationMin: (json['durationMin'] as num?)?.toInt() ?? 0,
      walkMin: (json['walkMin'] as num?)?.toInt() ?? 0,
      transfers: (json['transfers'] as num?)?.toInt() ?? 0,
      reliabilityScore: (reliability['score'] as num?)?.toInt() ?? 0,
      dataQuality: JourneyDataQuality.fromJson(quality),
      legs: legs,
      reliabilityLevel: reliability['level'] as String?,
      reliabilitySamples: (reliability['sampleSize'] as num?)?.toInt(),
    );
  }
}

class JourneyPlan {
  const JourneyPlan({
    required this.planId,
    required this.dataState,
    required this.options,
    this.recommendedLeaveAt,
    this.arrivalFrom,
    this.arrivalTo,
  });

  final String planId;
  final DataState dataState;
  final List<JourneyOption> options;
  final DateTime? recommendedLeaveAt;
  final DateTime? arrivalFrom;
  final DateTime? arrivalTo;

  factory JourneyPlan.fromJson(Map<String, Object?> json) {
    final window = json['arrivalWindow'] is Map
        ? Map<String, Object?>.from(json['arrivalWindow'] as Map)
        : const <String, Object?>{};
    final options = json['options'] is List
        ? (json['options'] as List)
              .whereType<Map>()
              .map(
                (value) =>
                    JourneyOption.fromJson(Map<String, Object?>.from(value)),
              )
              .toList(growable: false)
        : const <JourneyOption>[];
    return JourneyPlan(
      planId: json['planId'] as String? ?? 'unknown',
      dataState:
          DataStateParsing.fromApiValue(json['dataState']) ??
          DataState.unavailable,
      options: options,
      recommendedLeaveAt: _date(json['recommendedLeaveAt']),
      arrivalFrom: _date(window['from']),
      arrivalTo: _date(window['to']),
    );
  }
}

enum PlannerPhase { idle, loading, ready, failure, cancelled }

class PlannerState {
  const PlannerState({required this.phase, this.plan, this.error});

  const PlannerState.idle() : this(phase: PlannerPhase.idle);

  final PlannerPhase phase;
  final JourneyPlan? plan;
  final ApiError? error;

  UxState get uxState {
    if (phase == PlannerPhase.loading) return UxState.loading;
    if (phase == PlannerPhase.ready && plan?.options.isNotEmpty == true) {
      return UxState.ok;
    }
    if (phase == PlannerPhase.ready) return UxState.empty;
    if (error == null) return UxState.error;
    return UxStateMapping.fromError(
      code: error!.code,
      dataState: error!.dataState,
    );
  }
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
