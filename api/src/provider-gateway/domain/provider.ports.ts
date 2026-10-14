import { GeoPoint, JourneyPlanRequest } from './provider.types';

export interface ProviderResult<T> {
  readonly providerKey: string;
  readonly isDemo: boolean;
  readonly sourceAuthorized?: boolean;
  readonly observedAt: string | null;
  readonly data: T;
}

export interface TransitProviderResult {
  readonly providerKey: string;
  readonly isDemo: boolean;
  readonly sourceAuthorized?: boolean;
  readonly observedAt: string | null;
  readonly plan: unknown;
}

export interface TransitPlannerProvider {
  readonly providerKey: string;
  readonly isDemo: boolean;
  plan(request: JourneyPlanRequest): Promise<TransitProviderResult>;
}

export interface GeocodingProvider {
  readonly providerKey: string;
  readonly isDemo: boolean;
  search(query: string, near?: GeoPoint): Promise<ProviderResult<unknown>>;
  reverse(point: GeoPoint): Promise<ProviderResult<unknown>>;
}

export interface TransitStopCandidate {
  externalId: string;
  name: string;
  location: GeoPoint;
}

export interface TransitStopDiscoveryInput {
  lat: number;
  lon: number;
  radiusM: number;
}

export interface TransitStopDiscoveryProvider {
  readonly providerKey: string;
  readonly isDemo: boolean;
  discoverStops(
    input: TransitStopDiscoveryInput,
  ): Promise<ProviderResult<TransitStopCandidate[]>>;
}

export interface VehiclePositionProvider {
  positions(routeIds: string[]): Promise<unknown>;
}

export interface TrafficIncidentProvider {
  incidents(area: { lat: number; lon: number; radiusM: number }): Promise<unknown>;
}
