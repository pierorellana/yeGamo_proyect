import { Inject, Injectable } from '@nestjs/common';

import type { Place } from '../../provider-gateway/domain/provider.types';
import {
  PLACES_GATEWAY,
  PlacesGatewayPort,
  SearchPlacesInput,
} from '../domain/places.ports';

@Injectable()
export class PlacesService {
  constructor(
    @Inject(PLACES_GATEWAY)
    private readonly gateway: PlacesGatewayPort,
  ) {}

  search(input: SearchPlacesInput): Promise<Place[]> {
    return this.gateway.search(input.query, input.near);
  }

  reverse(point: { lat: number; lon: number }): Promise<Place> {
    return this.gateway.reverse(point);
  }
}
