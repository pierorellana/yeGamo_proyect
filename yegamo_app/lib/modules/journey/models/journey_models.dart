import '../../../shared/location/location_service.dart';
import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';
import '../../planner/models/planner_models.dart';

/// Estado del viaje en la interfaz. El API solo conoce PLANNED/ACTIVE/
/// COMPLETED/CANCELLED/ABANDONED; `getOffAlert` y `arrived` son estados de
/// pantalla derivados en el cliente y nunca se envían ni se persisten.
enum JourneyStatus {
  stepByStep,
  active,
  getOffAlert,
  arrived,
  finished,
  canceled,
}

extension JourneyStatusParsing on JourneyStatus {
  /// Estado canónico del API equivalente (los estados solo de pantalla son ACTIVE).
  String get apiValue => switch (this) {
    JourneyStatus.stepByStep ||
    JourneyStatus.active ||
    JourneyStatus.getOffAlert ||
    JourneyStatus.arrived => 'ACTIVE',
    JourneyStatus.finished => 'COMPLETED',
    JourneyStatus.canceled => 'CANCELLED',
  };

  static JourneyStatus fromApi(Object? raw) {
    return switch (raw is String ? raw.toUpperCase() : '') {
      'COMPLETED' => JourneyStatus.finished,
      'CANCELLED' || 'ABANDONED' => JourneyStatus.canceled,
      _ => JourneyStatus.active,
    };
  }
}

/// Cuerpo de `PATCH /v1/active-journeys/{id}/progress`: únicamente
/// `currentLegIndex`, `location` (con consentimiento) y `occurredAt`.
class JourneyProgress {
  const JourneyProgress({required this.currentLegIndex, this.occurredAt});

  final int currentLegIndex;
  final DateTime? occurredAt;

  Map<String, Object?> toJson({
    GeoCoordinate? preciseLocation,
    DateTime? now,
  }) => {
    'currentLegIndex': currentLegIndex,
    'occurredAt': (occurredAt ?? now ?? DateTime.now())
        .toUtc()
        .toIso8601String(),
    if (preciseLocation != null)
      'location': {
        'lat': preciseLocation.latitude,
        'lon': preciseLocation.longitude,
      },
  };
}

/// Viaje activo tal como lo devuelve el API (`ActiveJourney`).
class ActiveJourney {
  const ActiveJourney({
    required this.id,
    required this.planId,
    required this.optionId,
    required this.status,
    required this.dataState,
    this.currentLegIndex = 0,
    this.legs = const [],
    this.dataQuality,
    this.eta,
  });

  final String id;
  final String planId;
  final String optionId;
  final JourneyStatus status;
  final DataState dataState;
  final int currentLegIndex;
  final List<JourneyLeg> legs;
  final JourneyDataQuality? dataQuality;

  /// Solo existe cuando una fuente autorizada entrega un estimado.
  final DateTime? eta;

  int get totalLegs => legs.length;

  JourneyLeg? get currentLeg =>
      currentLegIndex >= 0 && currentLegIndex < legs.length
      ? legs[currentLegIndex]
      : null;

  /// Primera instrucción del tramo actual, si el plan la trae.
  String? get instruction {
    final leg = currentLeg;
    return leg == null || leg.instructions.isEmpty
        ? null
        : leg.instructions.first;
  }

  DateTime? get observedAt => dataQuality?.observedAt;
  bool get sourceAuthorized => dataQuality?.sourceAuthorized ?? false;
  bool get liveVehicle => dataQuality?.liveVehicle ?? false;

  bool get isTerminal =>
      status == JourneyStatus.finished || status == JourneyStatus.canceled;

  ActiveJourney copyWith({
    JourneyStatus? status,
    DataState? dataState,
    int? currentLegIndex,
  }) {
    return ActiveJourney(
      id: id,
      planId: planId,
      optionId: optionId,
      status: status ?? this.status,
      dataState: dataState ?? this.dataState,
      currentLegIndex: currentLegIndex ?? this.currentLegIndex,
      legs: legs,
      dataQuality: dataQuality,
      eta: eta,
    );
  }

  /// Lanza [FormatException] si falta un campo obligatorio del contrato: un
  /// viaje que no cumple el contrato no debe mostrarse como válido.
  factory ActiveJourney.fromJson(Map<String, Object?> json) {
    String required(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
      throw FormatException('ActiveJourney.$key es obligatorio.');
    }

    final legIndex = json['currentLegIndex'];
    if (legIndex is! int || legIndex < 0) {
      throw const FormatException('ActiveJourney.currentLegIndex inválido.');
    }
    final rawLegs = json['legs'];
    if (rawLegs is! List) {
      throw const FormatException('ActiveJourney.legs es obligatorio.');
    }
    final quality = json['dataQuality'] is Map
        ? JourneyDataQuality.fromJson(
            Map<String, Object?>.from(json['dataQuality'] as Map),
          )
        : null;
    final dataState =
        DataStateParsing.fromApiValue(json['dataState']) ??
        DataState.unavailable;
    return ActiveJourney(
      id: required('id'),
      planId: required('planId'),
      optionId: required('optionId'),
      status: JourneyStatusParsing.fromApi(json['status']),
      dataState: dataState,
      currentLegIndex: legIndex,
      legs: rawLegs
          .whereType<Map>()
          .map((leg) => JourneyLeg.fromJson(Map<String, Object?>.from(leg)))
          .toList(growable: false),
      dataQuality: quality,
      eta: null,
    );
  }

  /// Serialización de caché local: misma forma que el API.
  Map<String, Object?> toJson() => {
    'id': id,
    'planId': planId,
    'optionId': optionId,
    'status': status.apiValue,
    'dataState': dataState.apiValue,
    'currentLegIndex': currentLegIndex,
    'legs': legs.map((leg) => leg.toJson()).toList(growable: false),
    if (dataQuality != null) 'dataQuality': dataQuality!.toJson(),
  };
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
