import { randomUUID } from 'node:crypto';

import { ProviderGatewayError } from '../domain/provider.errors';
import { JourneyPlanRequest, GeoPoint } from '../domain/provider.types';
import { TransitPlannerProvider, TransitProviderResult } from '../domain/provider.ports';

export class DemoTransitProvider implements TransitPlannerProvider {
  readonly providerKey = 'demo-transit';
  readonly isDemo = true;

  constructor(nodeEnv = process.env.NODE_ENV ?? 'development') {
    if (nodeEnv === 'production') {
      throw new ProviderGatewayError(
        'PROVIDER_UNAVAILABLE',
        'DemoTransitProvider is disabled in production',
        false,
      );
    }
  }

  async plan(request: JourneyPlanRequest): Promise<TransitProviderResult> {
    return {
      providerKey: this.providerKey,
      isDemo: this.isDemo,
      observedAt: null,
      plan: {
        planId: randomUUID(),
        recommendedLeaveAt: request.time ?? null,
        arrivalWindow: null,
        dataState: 'DEGRADED',
        options: [
          {
            id: randomUUID(),
            durationMin: 45,
            walkMin: Math.min(request.maxWalkMin ?? 12, 12),
            transfers: 1,
            liveVehicle: false,
            observedAt: null,
            dataState: 'DEGRADED',
            providerDisplayName: null,
            reliability: { score: null, level: null, sampleSize: null },
            legs: [
              demoWalkLeg(request.origin, request.destination),
            ],
          },
        ],
      },
    };
  }
}

function demoWalkLeg(from: GeoPoint, to: GeoPoint) {
  return {
    mode: 'WALK' as const,
    from,
    to,
    durationMin: 12,
    departureAt: null,
    arrivalAt: null,
    instructions: ['Datos de demostración: confirma la ruta antes de salir.'],
    routeId: null,
    fromStopId: null,
    toStopId: null,
  };
}
