import { Inject, Injectable, NotFoundException } from '@nestjs/common';

import { IdentityService } from '../../identity/application/identity.service';
import { IdempotencyService } from '../../shared/idempotency/idempotency.service';
import { COMMUTE_REPOSITORY, CommuteProfile, CommuteProfileInput, CommuteRepository } from '../domain/commutes.ports';

@Injectable()
export class CommutesService {
  constructor(
    @Inject(COMMUTE_REPOSITORY) private readonly commutes: CommuteRepository,
    private readonly identity: IdentityService,
    private readonly idempotency: IdempotencyService,
  ) {}

  list(userId: string): Promise<CommuteProfile[]> { return this.commutes.list(userId); }

  async create(userId: string, input: CommuteProfileInput, key: string | undefined): Promise<CommuteProfile> {
    await this.identity.requireLocationConsent(userId);
    return this.idempotency.execute(userId, key, input, () => this.commutes.create(userId, input), 201);
  }

  async update(userId: string, id: string, input: CommuteProfileInput): Promise<CommuteProfile> {
    await this.identity.requireLocationConsent(userId);
    const result = await this.commutes.update(userId, id, input);
    if (result === null) throw this.notFound(id);
    return result;
  }

  async setEnabled(userId: string, id: string, enabled: boolean, key: string | undefined): Promise<CommuteProfile> {
    const result = await this.idempotency.execute(userId, key, { id, enabled }, () => this.commutes.setEnabled(userId, id, enabled), 200);
    if (result === null) throw this.notFound(id);
    return result;
  }

  async delete(userId: string, id: string): Promise<void> {
    if (!(await this.commutes.delete(userId, id))) throw this.notFound(id);
  }

  existsForUser(userId: string, id: string): Promise<boolean> { return this.commutes.existsForUser(userId, id); }

  private notFound(id: string): NotFoundException { return new NotFoundException({ code: 'NOT_FOUND', message: 'La rutina no existe.', details: { resource: 'commute-profile', id } }); }
}
