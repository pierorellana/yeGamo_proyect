import 'package:flutter/foundation.dart';

import '../models/settings_models.dart';
import '../services/settings_repository.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._repository);

  final SettingsRepository _repository;
  SettingsState? _state;
  bool _loading = false;

  SettingsState? get state => _state;
  bool get loading => _loading;

  Future<void> load() async {
    if (_state != null || _loading) return;
    _loading = true;
    notifyListeners();
    _state = await _repository.load();
    _loading = false;
    notifyListeners();
  }

  Future<void> setLocationConsent(bool value) async {
    _state = await _repository.setLocationConsent(value);
    notifyListeners();
  }

  Future<void> exportData() async {
    _state = await _repository.exportLocalData();
    notifyListeners();
  }

  Future<void> deleteData() async {
    _loading = true;
    notifyListeners();
    _state = await _repository.deleteData();
    _loading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _state = await _repository.load();
    notifyListeners();
  }
}
