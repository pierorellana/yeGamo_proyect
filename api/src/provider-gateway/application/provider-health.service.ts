import { Injectable } from '@nestjs/common';

import {
  ProviderAvailability,
  ProviderCapability,
  ProviderHealthSnapshot,
} from '../domain/provider.types';

export interface ProviderHealthSource {
  readonly providerKey: string;
  readonly isDemo: boolean;
}

export interface ProviderHealthSources {
  readonly transit?: readonly ProviderHealthSource[];
  readonly geocoding?: readonly ProviderHealthSource[];
  readonly vehiclePosition?: readonly ProviderHealthSource[];
  readonly incidents?: readonly ProviderHealthSource[];
}

@Injectable()
export class ProviderHealthService {
  constructor(private readonly sources: ProviderHealthSources = {}) {}

  getAvailability(): ProviderAvailability[] {
    return this.entries().map(({ capability, providers }) => {
      const provider = providers.find((candidate) => !candidate.isDemo) ?? providers[0];

      return {
        capability,
        status:
          provider === undefined
            ? 'UNAVAILABLE'
            : provider.isDemo
              ? 'DEGRADED'
              : 'HEALTHY',
        provider: provider?.providerKey ?? null,
      };
    });
  }

  getSnapshots(now = new Date()): ProviderHealthSnapshot[] {
    return this.getAvailability().map((availability) => ({
      ...availability,
      latencyMs: null,
      checkedAt: now.toISOString(),
    }));
  }

  private entries(): Array<{
    capability: ProviderCapability;
    providers: readonly ProviderHealthSource[];
  }> {
    return [
      { capability: 'transit', providers: this.sources.transit ?? [] },
      { capability: 'geocoding', providers: this.sources.geocoding ?? [] },
      { capability: 'vehicle-position', providers: this.sources.vehiclePosition ?? [] },
      { capability: 'incidents', providers: this.sources.incidents ?? [] },
    ];
  }
}
