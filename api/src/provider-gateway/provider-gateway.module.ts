import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { DemoTransitProvider } from './adapters/demo-transit.provider';
import { GeocodingGatewayService, GEOCODING_PROVIDERS } from './application/geocoding-gateway.service';
import { ProviderHealthService } from './application/provider-health.service';
import { TransitGatewayService, TRANSIT_PLANNER_PROVIDERS } from './application/transit-gateway.service';
import { GeocodingProvider, TransitPlannerProvider } from './domain/provider.ports';
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
        const nodeEnv = config.get<string>('nodeEnv', process.env.NODE_ENV ?? 'development');
        const demoEnabled = config.get<string>('DEMO_PROVIDER_ENABLED') === 'true';

        return createTransitProviders(nodeEnv, demoEnabled);
      },
    },
    {
      provide: GEOCODING_PROVIDERS,
      useValue: [] as GeocodingProvider[],
    },
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
  exports: [TransitGatewayService, GeocodingGatewayService, ProviderHealthService],
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
