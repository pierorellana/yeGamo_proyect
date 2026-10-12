import { Inject, Injectable, NotFoundException } from '@nestjs/common';

import { NOTIFICATION_REPOSITORY, NotificationInput, NotificationRepository } from '../domain/notifications.ports';

@Injectable()
export class NotificationsService {
  constructor(@Inject(NOTIFICATION_REPOSITORY) private readonly notifications: NotificationRepository) {}

  list(userId: string, page: number, pageSize: number) { return this.notifications.list(userId, page, pageSize); }

  async markRead(userId: string, id: string) {
    const notification = await this.notifications.markRead(userId, id);
    if (notification === null) throw new NotFoundException({ code: 'NOT_FOUND', message: 'La notificación no existe.', details: { resource: 'notification', id } });
    return notification;
  }

  markAllRead(userId: string): Promise<void> { return this.notifications.markAllRead(userId); }

  create(userId: string, input: NotificationInput) { return this.notifications.create(userId, input); }
}
