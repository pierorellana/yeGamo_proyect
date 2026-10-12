import 'package:flutter/foundation.dart';

import '../models/notification_models.dart';
import '../services/notifications_repository.dart';

class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel(this._repository);

  final NotificationsRepository _repository;
  NotificationsState _state = const NotificationsState();
  bool _loading = false;

  NotificationsState get state => _state;
  bool get loading => _loading;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    _state = NotificationsState(items: await _repository.list());
    _loading = false;
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    final result = await _repository.markRead(id);
    _state = NotificationsState(items: result.items, message: result.error?.message);
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final result = await _repository.markAllRead();
    _state = NotificationsState(items: result.items, message: result.error?.message);
    notifyListeners();
  }
}
