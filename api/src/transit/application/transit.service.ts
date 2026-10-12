import { Inject, Injectable, NotFoundException } from '@nestjs/common';

import {
  NearbyStopsInput,
  TRANSIT_READ_PORT,
  TransitReadPort,
  TransitRoute,
  TransitStop,
  Departure,
} from '../domain/transit.ports';

@Injectable()
export class TransitService {
  constructor(
    @Inject(TRANSIT_READ_PORT)
    private readonly transit: TransitReadPort,
  ) {}

  nearbyStops(input: NearbyStopsInput): Promise<TransitStop[]> {
    return this.transit.nearbyStops(input);
  }

  departures(stopId: string): Promise<Departure[]> {
    return this.transit.departures(stopId);
  }

  async route(routeId: string): Promise<TransitRoute> {
    const route = await this.transit.route(routeId);
    if (route === null) {
      throw new NotFoundException({
        code: 'NOT_FOUND',
        message: 'La ruta de transporte solicitada no existe.',
        details: { resource: 'transit-route', id: routeId },
      });
    }

    return route;
  }
}
