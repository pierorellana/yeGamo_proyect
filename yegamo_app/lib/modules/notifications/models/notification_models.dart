enum NotificationKind { leaveAlert, service, journey, privacy }

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.kind,
    this.read = false,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final NotificationKind kind;
  final bool read;

  NotificationItem copyWith({bool? read}) => NotificationItem(
    id: id,
    title: title,
    message: message,
    createdAt: createdAt,
    kind: kind,
    read: read ?? this.read,
  );

  factory NotificationItem.fromJson(Map<String, Object?> json) => NotificationItem(
    id: json['id'] as String? ?? 'notification-${json.hashCode}',
    title: json['title'] as String? ?? 'Aviso de yeGamo',
    message: json['message'] as String? ?? json['body'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    kind: switch ((json['type'] as String? ?? '').toUpperCase()) {
      'LEAVE_ALERT' => NotificationKind.leaveAlert,
      'JOURNEY' => NotificationKind.journey,
      'PRIVACY' => NotificationKind.privacy,
      _ => NotificationKind.service,
    },
    read: json['read'] == true || json['readAt'] != null,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'type': kind.name,
    'read': read,
  };
}

class NotificationsState {
  const NotificationsState({this.items = const [], this.message});

  final List<NotificationItem> items;
  final String? message;

  int get unreadCount => items.where((item) => !item.read).length;
}
