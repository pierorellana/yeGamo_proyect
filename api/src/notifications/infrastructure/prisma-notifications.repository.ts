import { Injectable } from '@nestjs/common';

import { PrismaService } from '../../shared/database/prisma.service';
import { Prisma } from '@prisma/client';
import type { NotificationInput, NotificationRecord, NotificationRepository, PaginatedNotificationRecords } from '../domain/notifications.ports';

@Injectable()
export class PrismaNotificationRepository implements NotificationRepository {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, page: number, pageSize: number): Promise<PaginatedNotificationRecords> {
    const [items, total] = await Promise.all([
      this.prisma.notification.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, skip: (page - 1) * pageSize, take: pageSize }),
      this.prisma.notification.count({ where: { userId } }),
    ]);
    return { items: items.map(toNotification), page, pageSize, total, hasNext: page * pageSize < total };
  }

  async markRead(userId: string, id: string): Promise<NotificationRecord | null> {
    const existing = await this.prisma.notification.findFirst({ where: { id, userId } });
    if (existing === null) return null;
    const item = await this.prisma.notification.update({ where: { id }, data: { isRead: true, readAt: new Date() } });
    return toNotification(item);
  }

  async markAllRead(userId: string): Promise<void> {
    await this.prisma.notification.updateMany({ where: { userId, isRead: false }, data: { isRead: true, readAt: new Date() } });
  }

  async create(userId: string, input: NotificationInput): Promise<NotificationRecord> {
    const item = await this.prisma.notification.create({
      data: {
        userId,
        type: input.type,
        title: input.title,
        body: input.body,
        payload: (input.payload === undefined ? {} : JSON.parse(JSON.stringify(input.payload))) as Prisma.InputJsonValue,
        ...(input.deduplicationKey === undefined ? {} : { deduplicationKey: input.deduplicationKey }),
      },
    });
    return toNotification(item);
  }
}

function toNotification(item: { id: string; type: string; title: string; body: string; isRead: boolean; createdAt: Date }): NotificationRecord {
  return { id: item.id, type: item.type as NotificationRecord['type'], title: item.title, body: item.body, isRead: item.isRead, createdAt: item.createdAt.toISOString() };
}
