import type { GeoPoint, Place } from '../../provider-gateway/domain/provider.types';

export interface FavoritePlaceInput {
  readonly label: string;
  readonly location: GeoPoint;
}

export interface FavoritePlacesRepository {
  list(userId: string): Promise<Place[]>;
  create(userId: string, input: FavoritePlaceInput): Promise<Place>;
  update(userId: string, id: string, input: FavoritePlaceInput): Promise<Place | null>;
  delete(userId: string, id: string): Promise<boolean>;
}

export const FAVORITE_PLACES_REPOSITORY = Symbol('FAVORITE_PLACES_REPOSITORY');
