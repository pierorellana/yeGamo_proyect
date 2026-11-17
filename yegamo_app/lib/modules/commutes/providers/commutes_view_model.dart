import 'package:flutter/foundation.dart';

import '../models/commute_models.dart';
import '../services/commutes_repository.dart';

class CommutesViewModel extends ChangeNotifier {
  CommutesViewModel(this._repository);

  final CommutesRepository _repository;
  CommutesState _state = const CommutesState();
  bool _loading = false;

  CommutesState get state => _state;
  bool get loading => _loading;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    _state = CommutesState(items: await _repository.list());
    _loading = false;
    notifyListeners();
  }

  Future<void> save(CommuteRoutine routine) async {
    _loading = true;
    notifyListeners();
    final result = await _repository.save(routine);
    _state = CommutesState(items: result.items, message: result.error?.message ?? result.notice);
    _loading = false;
    notifyListeners();
  }

  Future<void> toggle(CommuteRoutine routine) async {
    _loading = true;
    notifyListeners();
    final result = await _repository.setPaused(routine, !routine.isPaused);
    _state = CommutesState(items: result.items, message: result.error?.message ?? result.notice);
    _loading = false;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _loading = true;
    notifyListeners();
    final result = await _repository.remove(id);
    _state = CommutesState(items: result.items, message: result.error?.message ?? result.notice);
    _loading = false;
    notifyListeners();
  }
}
