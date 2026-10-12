export type NotificationType = 'LEAVE_ALERT' | 'GETOFF_ALERT' | 'ROUTE_CHANGE' | 'INCIDENT' | 'SYSTEM';

export interface NotificationRecord {
  readonly id: string;
  readonly type: NotificationType;
  readonly title: string;
  readonly body: string;
  readonly isRead: boolean;
  readonly createdAt: string;
}

export interface NotificationInput {
  readonly type: NotificationType;
  readonly title: string;
  readonly body: string;
  readonly payload?: Record<string, unknown>;
  readonly deduplicationKey?: string;
}

export interface PaginatedNotificationRecords {
  readonly items: NotificationRecord[];
  readonly page: number;
  readonly pageSize: number;
  readonly total: number;
  readonly hasNext: boolean;
}

export interface NotificationRepository {
  list(userId: string, page: number, pageSize: number): Promise<PaginatedNotificationRecords>;
  markRead(userId: string, id: string): Promise<NotificationRecord | null>;
  markAllRead(userId: string): Promise<void>;
  create(userId: string, input: NotificationInput): Promise<NotificationRecord>;
}

export const NOTIFICATION_REPOSITORY = Symbol('NOTIFICATION_REPOSITORY');
