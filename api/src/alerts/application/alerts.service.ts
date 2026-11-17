import { Inject, Injectable, NotFoundException, UnprocessableEntityException } from '@nestjs/common';

import { CommutesService } from '../../commutes/application/commutes.service';
import { IdentityService } from '../../identity/application/identity.service';
import { IdempotencyService } from '../../shared/idempotency/idempotency.service';
import { LEAVE_ALERT_REPOSITORY, LeaveAlertInput, LeaveAlertRepository } from '../domain/alerts.ports';

const MAX_ALERT_HORIZON_MS = 7 * 24 * 60 * 60 * 1000;

@Injectable()
export class AlertsService {
  constructor(
    @Inject(LEAVE_ALERT_REPOSITORY) private readonly alerts: LeaveAlertRepository,
    private readonly commutes: CommutesService,
    private readonly identity: IdentityService,
    private readonly idempotency: IdempotencyService,
  ) {}

  async create(userId: string, input: LeaveAlertInput, key: string | undefined) {
    if ((input.commuteProfileId === undefined) === (input.journeyPlanId === undefined)) throw new UnprocessableEntityException({ code: 'VALIDATION_ERROR', message: 'El aviso debe apuntar exactamente a una rutina o a un plan.', details: { target: 'exclusive' } });
    const scheduled = Date.parse(input.scheduledFor);
    if (scheduled <= Date.now() || scheduled > Date.now() + MAX_ALERT_HORIZON_MS) {
      throw new UnprocessableEntityException({ code: 'VALIDATION_ERROR', message: 'scheduledFor debe ser un instante futuro dentro de los próximos 7 días.', details: { validationErrors: [{ property: 'scheduledFor', constraints: { futureWithinHorizon: 'Debe ser futuro y ≤ 7 días.' } }] } });
    }
    if (input.commuteProfileId !== undefined && !(await this.commutes.existsForUser(userId, input.commuteProfileId))) throw new NotFoundException({ code: 'NOT_FOUND', message: 'La rutina no existe.', details: { resource: 'commute-profile', id: input.commuteProfileId } });
    if (input.journeyPlanId !== undefined && !(await this.alerts.journeyPlanBelongsToUser(userId, input.journeyPlanId))) throw new NotFoundException({ code: 'NOT_FOUND', message: 'El plan de viaje no existe.', details: { resource: 'journey-plan', id: input.journeyPlanId } });
    return this.idempotency.execute(userId, key, input, () => this.alerts.create(userId, input, key ?? ''), 201);
  }

  async delete(userId: string, id: string): Promise<void> {
    if (!(await this.alerts.delete(userId, id))) throw new NotFoundException({ code: 'NOT_FOUND', message: 'El aviso no existe.', details: { resource: 'leave-alert', id } });
  }

  due(now: Date) { return this.alerts.due(now); }
  markTriggered(id: string) { return this.alerts.markTriggered(id); }
  claim(id: string, now: Date) { return this.alerts.claim(id, now); }
  markExpired(id: string) { return this.alerts.markExpired(id); }
}
