import type {
  JourneyPlanRequest,
  TransitPlan,
} from '../../provider-gateway/domain/provider.types';

export const JOURNEY_TRANSIT_PORT = Symbol('JOURNEY_TRANSIT_PORT');
export const JOURNEY_PLAN_REPOSITORY = Symbol('JOURNEY_PLAN_REPOSITORY');

export interface RequestContext {
  traceId: string;
}

export interface JourneyTransitPort {
  plan(request: JourneyPlanRequest): Promise<TransitPlan>;
}

export interface SavePlanContext {
  /** Provider key that produced the plan (kept as audit metadata, never exposed). */
  providerKey: string;
  userId?: string | null;
  expiresAt: Date;
}

export interface JourneyPlanRepository {
  get(planId: string): Promise<TransitPlan | null>;
  save(plan: TransitPlan, request: JourneyPlanRequest, context: SavePlanContext): Promise<void>;
}

export interface JourneysUseCase {
  plan(input: JourneyPlanRequest, context: RequestContext): Promise<TransitPlan>;
  get(planId: string, context: RequestContext): Promise<TransitPlan>;
}
