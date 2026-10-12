import '../../../shared/location/location_service.dart';
import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';

enum JourneyStatus {
  stepByStep,
  active,
  getOffAlert,
  arrived,
  finished,
  canceled,
}

extension JourneyStatusParsing on JourneyStatus {
  String get apiValue => switch (this) {
    JourneyStatus.stepByStep => 'STEP_BY_STEP',
    JourneyStatus.active => 'ACTIVE',
    JourneyStatus.getOffAlert => 'GET_OFF_ALERT',
    JourneyStatus.arrived => 'ARRIVED',
    JourneyStatus.finished => 'FINISHED',
    JourneyStatus.canceled => 'CANCELED',
  };

  static JourneyStatus fromApi(Object? raw) {
    final value = raw is String ? raw.toUpperCase() : '';
    return switch (value) {
      'STEP_BY_STEP' => JourneyStatus.stepByStep,
      'GET_OFF_ALERT' => JourneyStatus.getOffAlert,
      'ARRIVED' => JourneyStatus.arrived,
      'FINISHED' => JourneyStatus.finished,
      'CANCELED' || 'CANCELLED' => JourneyStatus.canceled,
      _ => JourneyStatus.active,
    };
  }
}

class JourneyProgress {
  const JourneyProgress({
    required this.stepIndex,
    this.status = JourneyStatus.active,
    this.sequence = 0,
  });

  final int stepIndex;
  final JourneyStatus status;
  final int sequence;

  Map<String, Object?> toJson({GeoCoordinate? preciseLocation}) => {
    'stepIndex': stepIndex,
    'status': status.apiValue,
    'sequence': sequence,
    if (preciseLocation != null)
      'location': {
        'lat': preciseLocation.latitude,
        'lon': preciseLocation.longitude,
      },
  };
}

class ActiveJourney {
  const ActiveJourney({
    required this.id,
    required this.planId,
    required this.optionId,
    required this.status,
    required this.dataState,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.instruction,
    this.nextStop,
    this.eta,
    this.observedAt,
    this.sourceAuthorized = false,
    this.liveVehicle = false,
  });

  final String id;
  final String planId;
  final String optionId;
  final JourneyStatus status;
  final DataState dataState;
  final int currentStep;
  final int totalSteps;
  final String? instruction;
  final String? nextStop;
  final DateTime? eta;
  final DateTime? observedAt;
  final bool sourceAuthorized;
  final bool liveVehicle;

  bool get isTerminal =>
      status == JourneyStatus.finished || status == JourneyStatus.canceled;

  ActiveJourney copyWith({
    JourneyStatus? status,
    DataState? dataState,
    int? currentStep,
    int? totalSteps,
    String? instruction,
    String? nextStop,
    DateTime? eta,
    DateTime? observedAt,
    bool? sourceAuthorized,
    bool? liveVehicle,
  }) {
    return ActiveJourney(
      id: id,
      planId: planId,
      optionId: optionId,
      status: status ?? this.status,
      dataState: dataState ?? this.dataState,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      instruction: instruction ?? this.instruction,
      nextStop: nextStop ?? this.nextStop,
      eta: eta ?? this.eta,
      observedAt: observedAt ?? this.observedAt,
      sourceAuthorized: sourceAuthorized ?? this.sourceAuthorized,
      liveVehicle: liveVehicle ?? this.liveVehicle,
    );
  }

  factory ActiveJourney.fromJson(Map<String, Object?> json) {
    final quality = json['dataQuality'] is Map
        ? Map<String, Object?>.from(json['dataQuality'] as Map)
        : const <String, Object?>{};
    final rawState = json['dataState'] ?? quality['dataState'];
    return ActiveJourney(
      id: json['id'] as String? ?? 'unknown',
      planId: json['planId'] as String? ?? 'unknown',
      optionId: json['optionId'] as String? ?? 'unknown',
      status: JourneyStatusParsing.fromApi(json['status']),
      dataState:
          DataStateParsing.fromApiValue(rawState) ?? DataState.unavailable,
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
      instruction: json['instruction'] as String? ?? json['nextInstruction'] as String?,
      nextStop: json['nextStop'] as String?,
      eta: _date(json['eta']),
      observedAt: _date(json['observedAt'] ?? quality['observedAt']),
      sourceAuthorized:
          json['sourceAuthorized'] == true || quality['sourceAuthorized'] == true,
      liveVehicle: json['liveVehicle'] == true || quality['liveVehicle'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'planId': planId,
    'optionId': optionId,
    'status': status.apiValue,
    'dataState': dataState.apiValue,
    'currentStep': currentStep,
    'totalSteps': totalSteps,
    if (instruction != null) 'instruction': instruction,
    if (nextStop != null) 'nextStop': nextStop,
    if (eta != null) 'eta': eta!.toIso8601String(),
    if (observedAt != null) 'observedAt': observedAt!.toIso8601String(),
    'sourceAuthorized': sourceAuthorized,
    'liveVehicle': liveVehicle,
  };

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class JourneyState {
  const JourneyState({
    this.journey,
    this.error,
    this.uxState = UxState.loading,
    this.message,
  });

  const JourneyState.idle() : this(uxState: UxState.empty);

  final ActiveJourney? journey;
  final ApiError? error;
  final UxState uxState;
  final String? message;

  bool get isLoading => uxState == UxState.loading;
}
