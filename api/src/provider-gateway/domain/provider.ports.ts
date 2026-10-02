import { JourneyPlanRequest } from './provider.types';

export interface TransitProviderResult {
  readonly providerKey: string;
  readonly isDemo: boolean;
  readonly observedAt: string | null;
  readonly plan: unknown;
}

export interface TransitPlannerProvider {
  readonly providerKey: string;
  readonly isDemo: boolean;
  plan(request: JourneyPlanRequest): Promise<TransitProviderResult>;
}

export interface GeocodingProvider {
  search(query: string): Promise<unknown>;
  reverse(point: { lat: number; lon: number }): Promise<unknown>;
}

export interface VehiclePositionProvider {
  positions(routeIds: string[]): Promise<unknown>;
}

export interface TrafficIncidentProvider {
  incidents(area: { lat: number; lon: number; radiusM: number }): Promise<unknown>;
}
