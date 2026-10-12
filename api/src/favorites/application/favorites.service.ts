import { Inject, Injectable, NotFoundException } from '@nestjs/common';

import { IdentityService } from '../../identity/application/identity.service';
import { IdempotencyService } from '../../shared/idempotency/idempotency.service';
import { FAVORITE_PLACES_REPOSITORY, FavoritePlaceInput, FavoritePlacesRepository } from '../domain/favorites.ports';

@Injectable()
export class FavoritesService {
  constructor(
    @Inject(FAVORITE_PLACES_REPOSITORY) private readonly places: FavoritePlacesRepository,
    private readonly identity: IdentityService,
    private readonly idempotency: IdempotencyService,
  ) {}

  list(userId: string) { return this.places.list(userId); }

  async create(userId: string, input: FavoritePlaceInput, key: string | undefined) {
    await this.identity.requireLocationConsent(userId);
    return this.idempotency.execute(userId, key, input, () => this.places.create(userId, input), 201);
  }

  async update(userId: string, id: string, input: FavoritePlaceInput) {
    await this.identity.requireLocationConsent(userId);
    const place = await this.places.update(userId, id, input);
    if (place === null) throw new NotFoundException({ code: 'NOT_FOUND', message: 'El lugar guardado no existe.', details: { resource: 'saved-place', id } });
    return place;
  }

  async delete(userId: string, id: string): Promise<void> {
    if (!(await this.places.delete(userId, id))) throw new NotFoundException({ code: 'NOT_FOUND', message: 'El lugar guardado no existe.', details: { resource: 'saved-place', id } });
  }
}
