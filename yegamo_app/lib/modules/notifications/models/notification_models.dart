enum NotificationKind { leaveAlert, service, journey, privacy }

extension NotificationKindApi on NotificationKind {
  /// `NotificationType` del API.
  String get apiValue => switch (this) {
    NotificationKind.leaveAlert => 'LEAVE_ALERT',
    NotificationKind.journey => 'GETOFF_ALERT',
    NotificationKind.privacy => 'SYSTEM',
    NotificationKind.service => 'ROUTE_CHANGE',
  };
}

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

  /// Lee el `Notification` del API (`type`, `title`, `body`, `isRead`,
  /// `createdAt`). `isRead` es el único indicador de lectura del servidor.
  factory NotificationItem.fromJson(Map<String, Object?> json) => NotificationItem(
    id: json['id'] as String? ?? 'notification-${json.hashCode}',
    title: json['title'] as String? ?? 'Aviso de yeGamo',
    message: json['body'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    kind: switch ((json['type'] as String? ?? '').toUpperCase()) {
      'LEAVE_ALERT' => NotificationKind.leaveAlert,
      'GETOFF_ALERT' || 'JOURNEY' => NotificationKind.journey,
      'PRIVACY' || 'SYSTEM' => NotificationKind.privacy,
      _ => NotificationKind.service,
    },
    read: json['isRead'] == true,
  );

  /// Misma forma que el API para que la caché local se lea igual que el servidor.
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': message,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'type': kind.apiValue,
    'isRead': read,
  };
}

class NotificationsState {
  const NotificationsState({this.items = const [], this.message});

  final List<NotificationItem> items;
  final String? message;

  int get unreadCount => items.where((item) => !item.read).length;
}
