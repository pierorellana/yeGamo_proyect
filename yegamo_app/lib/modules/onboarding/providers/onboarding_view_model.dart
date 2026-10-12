import 'package:flutter/foundation.dart';

import '../services/onboarding_repository.dart';

class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({required OnboardingRepository repository})
    : this._(repository);

  OnboardingViewModel._(this._repository);

  final OnboardingRepository _repository;
  int _page = 0;
  bool _saving = false;

  int get page => _page;
  bool get saving => _saving;

  void setPage(int value) {
    if (value == _page) return;
    _page = value;
    notifyListeners();
  }

  Future<void> complete() async {
    _saving = true;
    notifyListeners();
    await _repository.markCompleted();
    _saving = false;
    notifyListeners();
  }
}
