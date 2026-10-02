import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { DemoTransitProvider } from './adapters/demo-transit.provider';
import { TransitGatewayService, TRANSIT_PLANNER_PROVIDERS } from './application/transit-gateway.service';

@Module({
  providers: [
    {
      provide: TRANSIT_PLANNER_PROVIDERS,
      inject: [ConfigService],
      useFactory: (config: ConfigService) =>
        config.get<string>('nodeEnv', 'development') === 'production'
          ? []
          : [new DemoTransitProvider(config.get<string>('nodeEnv', 'development'))],
    },
    TransitGatewayService,
  ],
  exports: [TransitGatewayService],
})
export class ProviderGatewayModule {}
