import { ActiveJourneysService } from '../../src/active-journeys/application/active-journeys.service';
import type { ActiveJourneyRecord, ActiveJourneyRepository } from '../../src/active-journeys/domain/active-journeys.ports';
import { InMemoryIdempotencyStore, IdempotencyService } from '../../src/shared/idempotency/idempotency.service';

describe('active journeys service', () => {
  it('makes start idempotent and enforces terminal transitions', async () => {
    const record: ActiveJourneyRecord = { id: 'j-1', optionId: 'o-1', status: 'ACTIVE', currentLegIndex: 0, eta: null, dataState: 'CURRENT', events: [] };
    let starts = 0;
    const repo: ActiveJourneyRepository = {
      optionBelongsToPlan: async () => true,
      create: async () => { starts += 1; return record; },
      get: async () => record,
      progress: async () => record,
      finish: async () => ({ ...record, status: 'COMPLETED' }),
      cancel: async () => ({ ...record, status: 'CANCELLED' }),
    };
    const service = new ActiveJourneysService(repo, { hasLocationConsent: async () => false } as never, new IdempotencyService(new InMemoryIdempotencyStore()));
    await service.start('user-1', 'plan-1', 'o-1', 'journey-1');
    await service.start('user-1', 'plan-1', 'o-1', 'journey-1');
    expect(starts).toBe(1);
    await expect(service.progress('user-1', 'j-1', { location: { lat: -2.17, lon: -79.9 } }, 'progress-1')).rejects.toMatchObject({ status: 403 });
  });
});
