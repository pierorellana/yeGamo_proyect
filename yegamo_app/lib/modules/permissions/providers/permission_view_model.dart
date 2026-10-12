import 'package:flutter/foundation.dart';

import '../models/permission_models.dart';
import '../services/permission_repository.dart';

class PermissionViewModel extends ChangeNotifier {
  PermissionViewModel({required PermissionRepository repository})
    : this._(repository);

  PermissionViewModel._(this._repository);

  final PermissionRepository _repository;
  PermissionUxState _state = PermissionUxState.initial;
  PermissionResult? _result;

  PermissionUxState get state => _state;
  PermissionResult? get result => _result;

  Future<void> request() async {
    _state = PermissionUxState.requesting;
    notifyListeners();
    _result = await _repository.requestWhileInUse();
    _state = _result!.state;
    notifyListeners();
  }
}
