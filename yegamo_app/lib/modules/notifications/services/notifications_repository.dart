import 'dart:convert';

import '../../../shared/models/api_error.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/session/session_service.dart';
import '../../../shared/storage/local_storage.dart';
import '../models/notification_models.dart';

class NotificationsRepository {
  NotificationsRepository(this._storage, this._apiClient, this._session);

  final LocalStorage _storage;
  final ApiClient _apiClient;
  final SessionManager _session;

  Future<List<NotificationItem>> list() async {
    final local = await _readLocal();
    if (!_session.isAuthenticated) return local;
    final response = await _apiClient.get<Object?>('notifications');
    final payload = response.data is Map
        ? (response.data! as Map)['items']
        : response.data;
    if (response.isSuccess && payload is List) {
      final remote = _dedupe(
        payload
            .whereType<Map>()
            .map((item) => NotificationItem.fromJson(Map<String, Object?>.from(item))),
      );
      await _writeLocal(remote);
      return remote;
    }
    return local;
  }

  Future<NotificationOperationResult> markRead(String id) async {
    final updated = (await _readLocal())
        .map((item) => item.id == id ? item.copyWith(read: true) : item)
        .toList();
    await _writeLocal(updated);
    ApiError? error;
    if (_session.isAuthenticated) {
      final response = await _apiClient.patch<Object?>('notifications/$id/read');
      if (!response.isSuccess) error = response.error;
    }
    return NotificationOperationResult(items: updated, error: error);
  }

  Future<NotificationOperationResult> markAllRead() async {
    final updated = (await _readLocal()).map((item) => item.copyWith(read: true)).toList();
    await _writeLocal(updated);
    ApiError? error;
    if (_session.isAuthenticated) {
      final response = await _apiClient.post<Object?>('notifications/read-all');
      if (!response.isSuccess) error = response.error;
    }
    return NotificationOperationResult(items: updated, error: error);
  }

  Future<List<NotificationItem>> _readLocal() async {
    final raw = await _storage.read(YeGamoStorageKeys.notifications);
    if (raw == null) return const [];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return const [];
      return _dedupe(
        value
            .whereType<Map>()
            .map((item) => NotificationItem.fromJson(Map<String, Object?>.from(item))),
      );
    } on FormatException {
      return const [];
    }
  }

  Future<void> _writeLocal(List<NotificationItem> items) => _storage.write(
    YeGamoStorageKeys.notifications,
    jsonEncode(items.map((item) => item.toJson()).toList()),
  );

  static List<NotificationItem> _dedupe(Iterable<NotificationItem> items) {
    final byId = <String, NotificationItem>{};
    for (final item in items) {
      byId[item.id] = item;
    }
    final result = byId.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
}

class NotificationOperationResult {
  const NotificationOperationResult({required this.items, this.error});

  final List<NotificationItem> items;
  final ApiError? error;
}
