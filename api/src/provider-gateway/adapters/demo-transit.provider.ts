import { randomUUID } from 'node:crypto';

import { ProviderGatewayError } from '../domain/provider.errors';
import { JourneyPlanRequest, GeoPoint } from '../domain/provider.types';
import { TransitPlannerProvider, TransitProviderResult } from '../domain/provider.ports';

export class DemoTransitProvider implements TransitPlannerProvider {
  readonly providerKey = 'demo-transit';
  readonly isDemo = true;

  constructor(nodeEnv = process.env.NODE_ENV ?? 'development') {
    if (nodeEnv.toLowerCase() === 'production') {
      throw new ProviderGatewayError(
        'PROVIDER_UNAVAILABLE',
        'DemoTransitProvider is disabled in production',
        false,
      );
    }
  }

  /**
   * Development-only fixture. It never fabricates public transit: it splits the
   * straight line between the requested points into two WALK legs whose duration
   * is derived from the real distance (4.8 km/h). Every leg is labelled as a
   * fixture and the mapper downgrades the result to DEGRADED / non-live.
   */
  async plan(request: JourneyPlanRequest): Promise<TransitProviderResult> {
    const midpoint = {
      lat: (request.origin.lat + request.destination.lat) / 2,
      lon: (request.origin.lon + request.destination.lon) / 2,
    };
    const first = demoWalkLeg(request.origin, midpoint, 'Tramo 1 de 2 (fixture de desarrollo)');
    const second = demoWalkLeg(midpoint, request.destination, 'Tramo 2 de 2 (fixture de desarrollo)');
    const walkMin = first.durationMin + second.durationMin;
    return {
      providerKey: this.providerKey,
      isDemo: this.isDemo,
      observedAt: null,
      sourceAuthorized: false,
      plan: {
        planId: randomUUID(),
        recommendedLeaveAt: request.time ?? null,
        arrivalWindow: null,
        dataState: 'DEGRADED',
        options: [
          {
            id: randomUUID(),
            durationMin: walkMin,
            walkMin,
            transfers: 0,
            liveVehicle: false,
            observedAt: null,
            dataState: 'DEGRADED',
            providerDisplayName: null,
            reliability: { score: null, level: null, sampleSize: null },
            legs: [first, second],
          },
        ],
      },
    };
  }
}

const WALK_SPEED_M_PER_MIN = 80;

function demoWalkLeg(from: GeoPoint, to: GeoPoint, label: string) {
  return {
    mode: 'WALK' as const,
    from,
    to,
    durationMin: Math.max(1, Math.round(distanceM(from, to) / WALK_SPEED_M_PER_MIN)),
    departureAt: null,
    arrivalAt: null,
    instructions: [`${label}: camina en línea recta hacia el destino. No es una ruta de transporte público.`],
    routeId: null,
    fromStopId: null,
    toStopId: null,
  };
}

function distanceM(from: GeoPoint, to: GeoPoint): number {
  const rad = Math.PI / 180;
  const dLat = (to.lat - from.lat) * rad;
  const dLon = (to.lon - from.lon) * rad;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(from.lat * rad) * Math.cos(to.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
