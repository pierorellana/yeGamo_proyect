import type { GeoPoint } from '../../provider-gateway/domain/provider.types';

export interface CommuteProfile {
  readonly id: string;
  readonly name: string;
  readonly origin: GeoPoint;
  readonly destination: GeoPoint;
  readonly weekdays: readonly number[];
  readonly targetArrival: string;
  readonly enabled: boolean;
}

export interface CommuteProfileInput {
  readonly name: string;
  readonly origin: GeoPoint;
  readonly destination: GeoPoint;
  readonly weekdays: readonly number[];
  readonly targetArrival: string;
}

export interface CommuteRepository {
  list(userId: string): Promise<CommuteProfile[]>;
  create(userId: string, input: CommuteProfileInput): Promise<CommuteProfile>;
  update(userId: string, id: string, input: CommuteProfileInput): Promise<CommuteProfile | null>;
  setEnabled(userId: string, id: string, enabled: boolean): Promise<CommuteProfile | null>;
  delete(userId: string, id: string): Promise<boolean>;
  existsForUser(userId: string, id: string): Promise<boolean>;
}

export const COMMUTE_REPOSITORY = Symbol('COMMUTE_REPOSITORY');
