import 'package:flutter/foundation.dart';

import '../../../shared/location/location_service.dart';
import '../../../shared/models/data_state.dart';
import '../models/nearby_models.dart';
import '../services/nearby_repository.dart';

class NearbyViewModel extends ChangeNotifier {
  NearbyViewModel({required NearbyRepository repository}) : this._(repository);

  NearbyViewModel._(this._repository);

  final NearbyRepository _repository;
  NearbySnapshot _snapshot = const NearbySnapshot(state: UxState.empty);
  bool _loading = false;
  GeoCoordinate? _manualOrigin;

  NearbySnapshot get snapshot => _snapshot;
  bool get loading => _loading;

  void setManualOrigin(GeoCoordinate? origin) {
    _manualOrigin = origin;
    notifyListeners();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _snapshot = const NearbySnapshot(state: UxState.loading);
    notifyListeners();
    _snapshot = await _repository.load(manualOrigin: _manualOrigin);
    _loading = false;
    notifyListeners();
  }
}
