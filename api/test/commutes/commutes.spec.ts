import { CommutesService } from '../../src/commutes/application/commutes.service';
import { InMemoryIdempotencyStore, IdempotencyService } from '../../src/shared/idempotency/idempotency.service';
import type { CommuteRepository } from '../../src/commutes/domain/commutes.ports';

describe('commutes service', () => {
  it('preserves ownership through repository operations', async () => {
    const profile = { id: 'c-1', name: 'Trabajo', origin: { lat: -2.17, lon: -79.9 }, destination: { lat: -2.14, lon: -79.89 }, weekdays: [1, 2], targetArrival: '08:00:00', enabled: true };
    const repo: CommuteRepository = { list: async () => [profile], create: async () => profile, update: async () => profile, setEnabled: async () => profile, delete: async () => true, existsForUser: async (userId, id) => userId === 'user-1' && id === 'c-1' };
    const service = new CommutesService(repo, { requireLocationConsent: async () => undefined } as never, new IdempotencyService(new InMemoryIdempotencyStore()));
    expect(await service.existsForUser('user-1', 'c-1')).toBe(true);
    expect(await service.existsForUser('other-user', 'c-1')).toBe(false);
  });
});
