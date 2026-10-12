import { AlertsService } from '../../src/alerts/application/alerts.service';
import { InMemoryIdempotencyStore, IdempotencyService } from '../../src/shared/idempotency/idempotency.service';
import type { LeaveAlertRepository } from '../../src/alerts/domain/alerts.ports';

describe('alerts service', () => {
  it('rejects a leave alert with no owned target', async () => {
    const repo: LeaveAlertRepository = { create: jest.fn(), journeyPlanBelongsToUser: async () => false, delete: async () => false, due: async () => [], markTriggered: async () => undefined };
    const service = new AlertsService(repo, { existsForUser: async () => false } as never, {} as never, new IdempotencyService(new InMemoryIdempotencyStore()));
    await expect(service.create('user-1', { scheduledFor: '2026-10-12T08:00:00Z' }, 'alert-001')).rejects.toMatchObject({ status: 422 });
    expect(repo.create).not.toHaveBeenCalled();
  });
});
