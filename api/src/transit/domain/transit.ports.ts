import { ProviderGatewayError } from '../../provider-gateway/domain/provider.errors';
import type { DataState, GeoPoint } from '../../provider-gateway/domain/provider.types';

export const TRANSIT_READ_PORT = Symbol('TRANSIT_READ_PORT');

export interface TransitAgency {
  id: string;
  name: string;
  url: string | null;
  timezone: string;
}

export interface TransitRoute {
  id: string;
  shortName: string;
  longName: string | null;
  agency: TransitAgency;
  color: string | null;
  dataState: DataState;
}

export interface TransitStop {
  id: string;
  name: string;
  location: GeoPoint;
  distanceM?: number;
  dataState: DataState;
}

export interface TimeWindow {
  from: string;
  to: string;
}

export interface EtaEstimate {
  window: TimeWindow;
  dataState: DataState;
  liveVehicle: boolean;
  observedAt: string | null;
}

export interface Departure {
  routeId: string;
  estimate: EtaEstimate;
  dataState: DataState;
  stopId: string;
}

export interface NearbyStopsInput {
  lat: number;
  lon: number;
  radiusM: number;
}

export interface TransitReadPort {
  nearbyStops(input: NearbyStopsInput): Promise<TransitStop[]>;
  departures(stopId: string): Promise<Departure[]>;
  route(routeId: string): Promise<TransitRoute | null>;
}

export class UnavailableTransitReadPort implements TransitReadPort {
  nearbyStops(): Promise<TransitStop[]> {
    return Promise.reject(unavailable());
  }

  departures(): Promise<Departure[]> {
    return Promise.reject(unavailable());
  }

  route(): Promise<TransitRoute | null> {
    return Promise.reject(unavailable());
  }
}

function unavailable(): ProviderGatewayError {
  return new ProviderGatewayError(
    'PROVIDER_UNAVAILABLE',
    'No transit provider is configured for this capability',
    true,
    { capability: 'transit' },
  );
}
