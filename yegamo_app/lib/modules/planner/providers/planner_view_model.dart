import 'package:flutter/foundation.dart';

import '../../../shared/models/api_error.dart';
import '../models/planner_models.dart';
import '../services/journey_repository.dart';

class PlannerViewModel extends ChangeNotifier {
  PlannerViewModel({required JourneyRepository repository})
    : this._(repository);

  PlannerViewModel._(this._repository);

  final JourneyRepository _repository;
  PlannerState _state = const PlannerState.idle();
  TimeMode _timeMode = TimeMode.leaveNow;
  TravelPreference _preference = TravelPreference.balanced;
  JourneyPoint? _origin;
  JourneyPoint? _destination;
  int _maxWalkMin = 12;
  int _extraSafetyMarginMin = 0;
  int _operation = 0;
  DateTime? _targetTime;
  String? _selectedOptionId;

  PlannerState get state => _state;
  TimeMode get timeMode => _timeMode;
  TravelPreference get preference => _preference;
  int get maxWalkMin => _maxWalkMin;
  int get extraSafetyMarginMin => _extraSafetyMarginMin;

  /// Hora elegida para llegar o salir (null: se usa «ahora + 30 min»).
  DateTime? get targetTime => _targetTime;

  /// Opción elegida en Alternativas; por defecto la primera del plan.
  JourneyOption? get selectedOption {
    final options = _state.plan?.options;
    if (options == null || options.isEmpty) return null;
    for (final option in options) {
      if (option.id == _selectedOptionId) return option;
    }
    return options.first;
  }

  void setTargetTime(DateTime? value) {
    _targetTime = value;
    notifyListeners();
  }

  void selectOption(String id) {
    if (_selectedOptionId == id) return;
    _selectedOptionId = id;
    notifyListeners();
  }

  void setPoints({
    required JourneyPoint origin,
    required JourneyPoint destination,
  }) {
    _origin = origin;
    _destination = destination;
    notifyListeners();
  }

  void setTimeMode(TimeMode mode) {
    _timeMode = mode;
    notifyListeners();
  }

  void setPreference(TravelPreference preference) {
    _preference = preference;
    notifyListeners();
  }

  void setMaxWalkMin(int value) {
    _maxWalkMin = value.clamp(1, 60).toInt();
    notifyListeners();
  }

  void setExtraSafetyMarginMin(int value) {
    _extraSafetyMarginMin = value.clamp(0, 60).toInt();
    notifyListeners();
  }

  Future<void> calculate() async {
    final operation = ++_operation;
    if (_origin == null || _destination == null) {
      _state = const PlannerState(
        phase: PlannerPhase.failure,
        error: ApiError(
          code: 'INVALID_PLANNING_INPUT',
          message: 'Indica un origen y un destino válidos.',
        ),
      );
      notifyListeners();
      return;
    }
    _state = const PlannerState(phase: PlannerPhase.loading);
    notifyListeners();
    final result = await _repository.plan(
      JourneyPlanRequest(
        origin: _origin!,
        destination: _destination!,
        timeMode: _timeMode,
        time: _timeMode == TimeMode.leaveNow
            ? null
            : (_targetTime ?? DateTime.now().add(const Duration(minutes: 30))),
        preference: _preference,
        maxWalkMin: _maxWalkMin,
        extraSafetyMarginMin: _extraSafetyMarginMin,
      ),
    );
    if (operation != _operation) return;
    _state = result.plan == null
        ? PlannerState(phase: PlannerPhase.failure, error: result.error)
        : PlannerState(phase: PlannerPhase.ready, plan: result.plan);
    notifyListeners();
  }

  void cancel() {
    _operation++;
    _state = const PlannerState(phase: PlannerPhase.cancelled);
    notifyListeners();
  }
}
