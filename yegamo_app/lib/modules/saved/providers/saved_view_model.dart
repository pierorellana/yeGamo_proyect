import 'package:flutter/foundation.dart';

import '../models/saved_models.dart';
import '../services/saved_places_repository.dart';

class SavedViewModel extends ChangeNotifier {
  SavedViewModel(this._repository);

  final SavedPlacesRepository _repository;
  SavedPlacesState _state = const SavedPlacesState();
  bool _loading = false;

  SavedPlacesState get state => _state;
  bool get loading => _loading;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    _state = SavedPlacesState(items: await _repository.list());
    _loading = false;
    notifyListeners();
  }

  Future<void> add(SavedPlace place) async {
    _loading = true;
    notifyListeners();
    final result = await _repository.add(place);
    _state = SavedPlacesState(items: result.items, message: result.error?.message ?? result.notice);
    _loading = false;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _loading = true;
    notifyListeners();
    final result = await _repository.remove(id);
    _state = SavedPlacesState(items: result.items, message: result.error?.message ?? result.notice);
    _loading = false;
    notifyListeners();
  }
}
