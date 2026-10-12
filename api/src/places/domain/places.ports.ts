import type { GeoPoint, Place } from '../../provider-gateway/domain/provider.types';

export const PLACES_GATEWAY = Symbol('PLACES_GATEWAY');

export interface PlacesGatewayPort {
  search(query: string, near?: GeoPoint): Promise<Place[]>;
  reverse(point: GeoPoint): Promise<Place>;
}

export interface SearchPlacesInput {
  query: string;
  near?: GeoPoint;
}
