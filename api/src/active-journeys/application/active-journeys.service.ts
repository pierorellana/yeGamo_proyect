import { ConflictException, ForbiddenException, Inject, Injectable, NotFoundException, UnprocessableEntityException } from '@nestjs/common';

import { IdentityService } from '../../identity/application/identity.service';
import { IdempotencyService } from '../../shared/idempotency/idempotency.service';
import { ACTIVE_JOURNEY_REPOSITORY, ActiveJourneyRecord, ActiveJourneyRepository, ProgressInput } from '../domain/active-journeys.ports';

@Injectable()
export class ActiveJourneysService {
  constructor(
    @Inject(ACTIVE_JOURNEY_REPOSITORY) private readonly journeys: ActiveJourneyRepository,
    private readonly identity: IdentityService,
    private readonly idempotency: IdempotencyService,
  ) {}

  async start(userId: string, planId: string, optionId: string, key: string | undefined): Promise<ActiveJourneyRecord> {
    return this.idempotency.execute(userId, key, { planId, optionId }, async () => {
      if (!(await this.journeys.optionBelongsToPlan(planId, optionId))) throw new NotFoundException({ code: 'NOT_FOUND', message: 'La opción del plan no existe.', details: { resource: 'journey-option', id: optionId } });
      return this.journeys.create(userId, optionId);
    }, 201);
  }

  async get(userId: string, id: string): Promise<ActiveJourneyRecord> {
    const journey = await this.journeys.get(userId, id);
    if (journey === null) throw this.notFound(id);
    return journey;
  }

  async progress(userId: string, id: string, input: ProgressInput, key: string | undefined): Promise<ActiveJourneyRecord> {
    return this.idempotency.execute(userId, key, { id, input }, async () => {
      const current = await this.get(userId, id);
      if (current.status !== 'ACTIVE' && current.status !== 'PLANNED') throw new ConflictException({ code: 'JOURNEY_NOT_ACTIVE', message: 'El viaje ya terminó y no acepta progreso.', details: { status: current.status } });
      if (input.currentLegIndex !== undefined && input.currentLegIndex >= current.legs.length) {
        throw new UnprocessableEntityException({ code: 'VALIDATION_ERROR', message: 'currentLegIndex excede los tramos del viaje; finaliza el viaje para registrar la llegada.', details: { validationErrors: [{ property: 'currentLegIndex', constraints: { max: `Debe ser menor que ${current.legs.length}.` } }] } });
      }
      const payload: Record<string, unknown> = {};
      if (input.location !== undefined) {
        if (!(await this.identity.hasLocationConsent(userId))) throw new ForbiddenException({ code: 'LOCATION_CONSENT_REQUIRED', message: 'Se requiere consentimiento explícito para registrar ubicación precisa.', details: { locationConsent: false } });
        payload.location = input.location;
      }
      const updated = await this.journeys.progress(userId, id, input.currentLegIndex, payload, input.occurredAt === undefined ? new Date() : new Date(input.occurredAt));
      if (updated === null) throw this.notFound(id);
      return updated;
    });
  }

  async finish(userId: string, id: string, key: string | undefined): Promise<ActiveJourneyRecord> { return this.transition(userId, id, key, () => this.journeys.finish(userId, id, new Date()), 'COMPLETED'); }
  async cancel(userId: string, id: string, key: string | undefined): Promise<ActiveJourneyRecord> { return this.transition(userId, id, key, () => this.journeys.cancel(userId, id, new Date()), 'CANCELLED'); }

  private async transition(userId: string, id: string, key: string | undefined, operation: () => Promise<ActiveJourneyRecord | null>, status: string): Promise<ActiveJourneyRecord> {
    return this.idempotency.execute(userId, key, { id, status }, async () => {
      const current = await this.get(userId, id);
      if (current.status !== 'ACTIVE' && current.status !== 'PLANNED') throw new ConflictException({ code: 'JOURNEY_ALREADY_FINISHED', message: 'El viaje ya se encuentra en un estado terminal.', details: { status: current.status } });
      const result = await operation();
      if (result === null) throw this.notFound(id);
      return result;
    });
  }

  private notFound(id: string): NotFoundException { return new NotFoundException({ code: 'NOT_FOUND', message: 'El viaje activo no existe.', details: { resource: 'active-journey', id } }); }
}
