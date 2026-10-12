import { NotificationsService } from '../../src/notifications/application/notifications.service';
import type { NotificationRepository } from '../../src/notifications/domain/notifications.ports';

describe('notifications service', () => {
  it('delegates read state with the principal ownership key', async () => {
    const repo: NotificationRepository = { list: async () => ({ items: [], page: 1, pageSize: 20, total: 0, hasNext: false }), markRead: async (userId) => ({ id: userId, type: 'SYSTEM', title: 't', body: 'b', isRead: true, createdAt: new Date().toISOString() }), markAllRead: jest.fn(), create: jest.fn() };
    const service = new NotificationsService(repo);
    await expect(service.markRead('user-1', 'notification-1')).resolves.toMatchObject({ isRead: true });
    expect(await service.list('user-1', 1, 20)).toMatchObject({ total: 0, hasNext: false });
  });
});
