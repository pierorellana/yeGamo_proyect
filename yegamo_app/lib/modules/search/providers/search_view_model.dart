import 'package:flutter/foundation.dart';

import '../../../shared/models/data_state.dart';
import '../models/search_models.dart';
import '../services/search_repository.dart';

class SearchViewModel extends ChangeNotifier {
  SearchViewModel({required SearchRepository repository}) : this._(repository);

  SearchViewModel._(this._repository);

  final SearchRepository _repository;
  String _query = '';
  bool _loading = false;
  int _requestVersion = 0;
  SearchSnapshot _snapshot = const SearchSnapshot(state: UxState.empty);

  String get query => _query;
  bool get loading => _loading;
  SearchSnapshot get snapshot => _snapshot;

  Future<void> loadRecents() async {
    final version = ++_requestVersion;
    final recents = await _repository.recentQueries();
    if (version != _requestVersion) return;
    _snapshot = SearchSnapshot(state: UxState.empty, recentQueries: recents);
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  Future<void> search([String? value]) async {
    final version = ++_requestVersion;
    if (value != null) {
      _query = value;
    }
    _loading = true;
    _snapshot = SearchSnapshot(
      state: UxState.loading,
      recentQueries: _snapshot.recentQueries,
    );
    notifyListeners();
    final snapshot = await _repository.search(_query);
    if (version != _requestVersion) return;
    _snapshot = snapshot;
    _loading = false;
    notifyListeners();
  }
}
