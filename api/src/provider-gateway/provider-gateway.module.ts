import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { DemoTransitProvider } from './adapters/demo-transit.provider';
import { NominatimGeocodingProvider } from './adapters/nominatim-geocoding.provider';
import { OpenStreetMapTransitProvider } from './adapters/overpass-transit.provider';
import { OpenStreetMapMapTransitProvider } from './adapters/openstreetmap-map-transit.provider';
import {
  GeocodingGatewayService,
  GEOCODING_PROVIDERS,
} from './application/geocoding-gateway.service';
import { ProviderHealthService } from './application/provider-health.service';
import {
  TransitGatewayService,
  TRANSIT_PLANNER_PROVIDERS,
} from './application/transit-gateway.service';
import {
  GeocodingProvider,
  TransitPlannerProvider,
  TransitStopDiscoveryProvider,
} from './domain/provider.ports';
import {
  TransitStopDiscoveryGatewayService,
  TRANSIT_STOP_DISCOVERY_PROVIDERS,
} from './application/transit-stop-discovery-gateway.service';
import { ProviderStatusController } from './http/provider-status.controller';
import { IdentityModule } from '../identity/identity.module';

@Module({
  imports: [IdentityModule],
  controllers: [ProviderStatusController],
  providers: [
    {
      provide: TRANSIT_PLANNER_PROVIDERS,
      inject: [ConfigService],
      useFactory: (config: ConfigService): TransitPlannerProvider[] => {
        const nodeEnv = config.get<string>(
          'nodeEnv',
          process.env.NODE_ENV ?? 'development',
        );
        const demoEnabled =
          config.get<string>('DEMO_PROVIDER_ENABLED') === 'true';

        return createTransitProviders(nodeEnv, demoEnabled);
      },
    },
    {
      provide: GEOCODING_PROVIDERS,
      inject: [ConfigService],
      useFactory: (config: ConfigService): GeocodingProvider[] => {
        const nodeEnv = config.get<string>(
          'nodeEnv',
          process.env.NODE_ENV ?? 'development',
        );
        const configured = config.get<string>('NOMINATIM_ENABLED');
        const enabled =
          configured === undefined
            ? nodeEnv.toLowerCase() !== 'production'
            : configured === 'true';
        if (!enabled) return [];

        const userAgent = config.get<string>('NOMINATIM_USER_AGENT');
        if (nodeEnv.toLowerCase() === 'production' && !userAgent) return [];

        return [
          new NominatimGeocodingProvider({
            baseUrl: config.get<string>(
              'NOMINATIM_BASE_URL',
              'https://nominatim.openstreetmap.org',
            ),
            userAgent: userAgent ?? 'yeGamo-local-dev/1.0',
          }),
        ];
      },
    },
    {
      provide: TRANSIT_STOP_DISCOVERY_PROVIDERS,
      inject: [ConfigService],
      useFactory: (config: ConfigService): TransitStopDiscoveryProvider[] => {
        const nodeEnv = config.get<string>(
          'nodeEnv',
          process.env.NODE_ENV ?? 'development',
        );
        const enabled = config.get<string>('OVERPASS_ENABLED') === 'true';
        if (!enabled || nodeEnv.toLowerCase() === 'test') return [];

        const common = {
          baseUrls: (config.get<string>(
            'OVERPASS_BASE_URLS',
            config.get<string>(
              'OVERPASS_BASE_URL',
              'https://overpass-api.de/api/interpreter',
            ),
          ) ?? '')
            .split(',')
            .map((url) => url.trim())
            .filter((url) => url.length > 0),
          userAgent: config.get<string>(
            'NOMINATIM_USER_AGENT',
            'yeGamo-local-dev/1.0',
          ),
          timeoutMs: Number.parseInt(
            config.get<string>('OVERPASS_TIMEOUT_MS', '20000'),
            10,
          ),
          cacheTtlMs: Number.parseInt(
            config.get<string>('OVERPASS_CACHE_TTL_MS', '900000'),
            10,
          ),
        };
        return [
          new OpenStreetMapTransitProvider(common),
          new OpenStreetMapMapTransitProvider({
            userAgent: common.userAgent,
            timeoutMs: common.timeoutMs,
          }),
        ];
      },
    },
    TransitStopDiscoveryGatewayService,
    TransitGatewayService,
    GeocodingGatewayService,
    {
      provide: ProviderHealthService,
      inject: [TRANSIT_PLANNER_PROVIDERS, GEOCODING_PROVIDERS],
      useFactory: (
        transitProviders: TransitPlannerProvider[],
        geocodingProviders: GeocodingProvider[],
      ) =>
        new ProviderHealthService({
          transit: transitProviders,
          geocoding: geocodingProviders,
        }),
    },
  ],
  exports: [
    TransitGatewayService,
    GeocodingGatewayService,
    ProviderHealthService,
    TransitStopDiscoveryGatewayService,
  ],
})
export class ProviderGatewayModule {}

export function createTransitProviders(
  nodeEnv: string,
  demoEnabled: boolean,
): TransitPlannerProvider[] {
  return nodeEnv.toLowerCase() === 'production' || !demoEnabled
    ? []
    : [new DemoTransitProvider(nodeEnv)];
}
