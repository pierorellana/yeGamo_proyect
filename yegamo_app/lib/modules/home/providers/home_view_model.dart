import 'package:flutter/foundation.dart';

import '../../../shared/models/data_state.dart';
import '../models/home_models.dart';
import '../services/home_repository.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required HomeRepository repository}) : this._(repository);

  HomeViewModel._(this._repository);

  final HomeRepository _repository;
  HomeSnapshot _snapshot = const HomeSnapshot(state: UxState.loading);
  bool _loading = false;

  HomeSnapshot get snapshot => _snapshot;
  bool get loading => _loading;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    _snapshot = await _repository.load();
    _loading = false;
    notifyListeners();
  }
}
