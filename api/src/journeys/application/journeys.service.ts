import {
  HttpStatus,
  Inject,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';

import type {
  DataState,
  JourneyOption,
  JourneyPlanRequest,
  TransitPlan,
} from '../../provider-gateway/domain/provider.types';
import {
  JOURNEY_PLAN_REPOSITORY,
  JOURNEY_TRANSIT_PORT,
  JourneyPlanRepository,
  JourneyTransitPort,
  JourneysUseCase,
  RequestContext,
} from '../domain/journeys.ports';

@Injectable()
export class JourneysService implements JourneysUseCase {
  constructor(
    @Inject(JOURNEY_TRANSIT_PORT)
    private readonly transit: JourneyTransitPort,
    @Inject(JOURNEY_PLAN_REPOSITORY)
    private readonly plans: JourneyPlanRepository,
  ) {}

  async plan(input: JourneyPlanRequest, context: RequestContext): Promise<TransitPlan> {
    void context;
    if (input.timeMode !== 'LEAVE_NOW' && (input.time === undefined || input.time === null)) {
      throw new UnprocessableEntityException({
        code: 'VALIDATION_ERROR',
        message: 'time es obligatorio cuando timeMode no es LEAVE_NOW.',
        details: {
          validationErrors: [
            {
              property: 'time',
              constraints: { requiredForScheduledPlan: 'time es obligatorio.' },
            },
          ],
        },
      });
    }

    const plan = await this.transit.plan(input);
    const ordered = {
      ...plan,
      options: orderOptions(plan.options, input.preference ?? 'BALANCED'),
    } satisfies TransitPlan;

    await this.plans.save(ordered);
    return ordered;
  }

  async get(planId: string, context: RequestContext): Promise<TransitPlan> {
    void context;
    const plan = await this.plans.get(planId);
    if (plan === null) {
      throw new NotFoundException({
        code: 'NOT_FOUND',
        message: 'El plan de viaje solicitado no existe.',
        details: { resource: 'journey-plan', id: planId },
      });
    }

    return plan;
  }
}

export class InMemoryJourneyPlanRepository implements JourneyPlanRepository {
  private readonly plans = new Map<string, TransitPlan>();

  async get(planId: string): Promise<TransitPlan | null> {
    return this.plans.get(planId) ?? null;
  }

  async save(plan: TransitPlan): Promise<void> {
    this.plans.set(plan.planId, plan);
  }
}

function orderOptions(
  options: JourneyOption[],
  preference: JourneyPlanRequest['preference'],
): JourneyOption[] {
  const ordered = [...options];
  ordered.sort((left, right) => {
    const comparison = compareByPreference(left, right, preference ?? 'BALANCED');
    return comparison || left.id.localeCompare(right.id);
  });
  return ordered;
}

function compareByPreference(
  left: JourneyOption,
  right: JourneyOption,
  preference: NonNullable<JourneyPlanRequest['preference']>,
): number {
  switch (preference) {
    case 'FASTEST':
      return left.durationMin - right.durationMin;
    case 'LESS_WALKING':
      return left.walkMin - right.walkMin || left.durationMin - right.durationMin;
    case 'FEWER_TRANSFERS':
      return left.transfers - right.transfers || left.durationMin - right.durationMin;
    case 'RELIABLE':
      return reliabilityScore(right) - reliabilityScore(left) || left.durationMin - right.durationMin;
    case 'BALANCED':
      return balancedScore(left) - balancedScore(right);
  }
}

function balancedScore(option: JourneyOption): number {
  return option.durationMin + option.walkMin + option.transfers * 10;
}

function reliabilityScore(option: JourneyOption): number {
  const stateBonus = dataStateScore(option.dataQuality.dataState);
  return (option.reliability.score ?? -1) * 1000 + stateBonus;
}

function dataStateScore(state: DataState): number {
  switch (state) {
    case 'CURRENT':
      return 4;
    case 'STALE':
      return 3;
    case 'DEGRADED':
      return 2;
    case 'OFFLINE_CACHE':
      return 1;
    case 'UNAVAILABLE':
      return 0;
  }
}
