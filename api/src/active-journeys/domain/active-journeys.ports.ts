import type { DataQuality, DataState, GeoPoint, JourneyLeg } from '../../provider-gateway/domain/provider.types';

export type ActiveJourneyStatus = 'PLANNED' | 'ACTIVE' | 'COMPLETED' | 'CANCELLED' | 'ABANDONED';

export interface JourneyEventRecord {
  readonly id: string;
  readonly type: string;
  readonly occurredAt: string;
  readonly details: Record<string, unknown>;
}

export interface ActiveJourneyRecord {
  readonly id: string;
  readonly planId: string;
  readonly optionId: string;
  readonly status: ActiveJourneyStatus;
  readonly currentLegIndex: number;
  /** Canonical legs of the started option, persisted so the client can render instructions. */
  readonly legs: readonly JourneyLeg[];
  /** Always null until an authorized source provides a timestamped estimate. */
  readonly eta: null;
  readonly dataState: DataState;
  readonly dataQuality: DataQuality | null;
  readonly events: readonly JourneyEventRecord[];
}

export interface ActiveJourneyRepository {
  optionBelongsToPlan(planId: string, optionId: string): Promise<boolean>;
  create(userId: string, optionId: string): Promise<ActiveJourneyRecord>;
  get(userId: string, id: string): Promise<ActiveJourneyRecord | null>;
  progress(userId: string, id: string, currentLegIndex: number | undefined, payload: Record<string, unknown>, occurredAt: Date): Promise<ActiveJourneyRecord | null>;
  finish(userId: string, id: string, occurredAt: Date): Promise<ActiveJourneyRecord | null>;
  cancel(userId: string, id: string, occurredAt: Date): Promise<ActiveJourneyRecord | null>;
}

export const ACTIVE_JOURNEY_REPOSITORY = Symbol('ACTIVE_JOURNEY_REPOSITORY');

export interface ProgressInput {
  readonly currentLegIndex?: number;
  readonly location?: GeoPoint;
  readonly occurredAt?: string;
}
