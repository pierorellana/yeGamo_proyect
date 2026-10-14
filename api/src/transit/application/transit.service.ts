import { Inject, Injectable, NotFoundException } from '@nestjs/common';

import {
  TransitStopDiscoveryGatewayService,
  TransitStopDiscoveryPort,
} from '../../provider-gateway/application/transit-stop-discovery-gateway.service';
import { ProviderGatewayError } from '../../provider-gateway/domain/provider.errors';
import {
  TRANSIT_CATALOG_WRITE_PORT,
  NearbyStopsInput,
  TRANSIT_READ_PORT,
  TransitCatalogWritePort,
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
    @Inject(TransitStopDiscoveryGatewayService)
    private readonly discovery: TransitStopDiscoveryPort,
    @Inject(TRANSIT_CATALOG_WRITE_PORT)
    private readonly catalog: TransitCatalogWritePort,
  ) {}

  async nearbyStops(input: NearbyStopsInput): Promise<TransitStop[]> {
    const localStops = await this.transit.nearbyStops(input);
    if (localStops.length > 0) return localStops;

    try {
      const discovered = await this.discovery.discover(input);
      if (discovered.stops.length > 0) {
        await this.catalog.upsertDiscoveredStops(
          discovered.stops.map((stop) => ({
            ...stop,
            provider: sourceProvider(discovered.providerKey),
          })),
        );
        return this.transit.nearbyStops(input);
      }
      return localStops;
    } catch (error) {
      if (error instanceof ProviderGatewayError) return localStops;
      throw error;
    }
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

function sourceProvider(providerKey: string): string {
  if (
    providerKey === 'openstreetmap-overpass' ||
    providerKey === 'openstreetmap-map'
  ) {
    return 'openstreetmap';
  }
  return providerKey;
}
