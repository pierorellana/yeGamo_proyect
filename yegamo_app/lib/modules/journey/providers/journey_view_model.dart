import 'package:flutter/foundation.dart';

import '../../../shared/models/data_state.dart';
import '../../planner/models/planner_models.dart';
import '../models/journey_models.dart';
import '../services/active_journey_repository.dart';

class JourneyViewModel extends ChangeNotifier {
  JourneyViewModel(this._repository);

  final ActiveJourneyRepository _repository;
  JourneyState _state = const JourneyState.idle();
  bool _loading = false;

  JourneyState get state => _state;
  bool get loading => _loading;

  Future<void> start(
    String planId,
    String optionId, {
    JourneyOption? option,
  }) async {
    await _run(() => _repository.start(planId, optionId, option: option));
  }

  Future<void> updateProgress(JourneyProgress progress) async {
    await _run(() => _repository.updateProgress(progress));
  }

  Future<void> finish() async {
    await _run(_repository.finish);
  }

  Future<void> cancel() async {
    await _run(_repository.cancel);
  }

  void showPermissionRequired() {
    _state = const JourneyState(
      uxState: UxState.permission,
      message: 'Activa ubicación mientras usas la app para actualizar tu progreso.',
    );
    notifyListeners();
  }

  /// Estado de pantalla: se superó el último tramo. No se envía al API.
  void markArrived() {
    final journey = _state.journey;
    if (journey == null) return;
    _state = JourneyState(
      journey: journey.copyWith(status: JourneyStatus.arrived),
      uxState: _state.uxState,
    );
    notifyListeners();
  }

  void showGetOffAlert() {
    final journey = _state.journey;
    if (journey == null) return;
    _state = JourneyState(
      journey: journey.copyWith(status: JourneyStatus.getOffAlert),
      uxState: _state.uxState,
    );
    notifyListeners();
  }

  Future<void> _run(Future<ActiveJourneyResult> Function() operation) async {
    if (_loading) return;
    _loading = true;
    _state = JourneyState(
      journey: _state.journey,
      uxState: UxState.loading,
    );
    notifyListeners();
    final result = await operation();
    _loading = false;
    final journey = result.journey;
    if (journey != null) {
      _state = JourneyState(
        journey: journey,
        uxState: _stateFor(journey),
      );
    } else {
      _state = JourneyState(
        journey: _state.journey,
        error: result.error,
        uxState: result.error == null
            ? UxState.error
            : UxStateMapping.fromError(
                code: result.error!.code,
                dataState: result.error!.dataState,
              ),
      );
    }
    notifyListeners();
  }

  static UxState _stateFor(ActiveJourney journey) {
    if (journey.dataState == DataState.offlineCache) return UxState.offline;
    if (journey.dataState == DataState.stale) return UxState.stale;
    if (journey.dataState == DataState.degraded ||
        journey.dataState == DataState.unavailable) {
      return UxState.degraded;
    }
    return UxState.ok;
  }
}
