import { ForbiddenException } from '@nestjs/common';

import { FavoritesService } from '../../src/favorites/application/favorites.service';
import { InMemoryIdempotencyStore, IdempotencyService } from '../../src/shared/idempotency/idempotency.service';
import type { FavoritePlacesRepository } from '../../src/favorites/domain/favorites.ports';

describe('favorites service', () => {
  it('requires location consent before persisting a precise favorite', async () => {
    const repo: FavoritePlacesRepository = { list: async () => [], create: jest.fn(), update: jest.fn(), delete: async () => false };
    const identity = { requireLocationConsent: async () => { throw new ForbiddenException({ code: 'LOCATION_CONSENT_REQUIRED' }); } };
    const service = new FavoritesService(repo, identity as never, new IdempotencyService(new InMemoryIdempotencyStore()));
    await expect(service.create('user-1', { label: 'Casa', location: { lat: -2.17, lon: -79.9 } }, 'favorite-1')).rejects.toMatchObject({ status: 403 });
    expect(repo.create).not.toHaveBeenCalled();
  });

  it('replays the same response for the same idempotency key', async () => {
    let calls = 0;
    const repo: FavoritePlacesRepository = { list: async () => [], create: async () => { calls += 1; return { id: 'p-1', label: 'Casa', location: { lat: -2.17, lon: -79.9 }, source: null }; }, update: jest.fn(), delete: async () => false };
    const identity = { requireLocationConsent: async () => undefined };
    const service = new FavoritesService(repo, identity as never, new IdempotencyService(new InMemoryIdempotencyStore()));
    const input = { label: 'Casa', location: { lat: -2.17, lon: -79.9 } };
    const first = await service.create('user-1', input, 'favorite-1');
    const second = await service.create('user-1', input, 'favorite-1');
    expect(second).toEqual(first);
    expect(calls).toBe(1);
  });
});
