import { Module } from '@nestjs/common';

import { ProviderGatewayModule } from '../provider-gateway/provider-gateway.module';
import { TransitGatewayService } from '../provider-gateway/application/transit-gateway.service';
import { InMemoryJourneyPlanRepository, JourneysService } from './application/journeys.service';
import {
  JOURNEY_PLAN_REPOSITORY,
  JOURNEY_TRANSIT_PORT,
} from './domain/journeys.ports';
import { JourneysController } from './http/journeys.controller';

@Module({
  imports: [ProviderGatewayModule],
  controllers: [JourneysController],
  providers: [
    {
      provide: JOURNEY_TRANSIT_PORT,
      useExisting: TransitGatewayService,
    },
    {
      provide: JOURNEY_PLAN_REPOSITORY,
      useClass: InMemoryJourneyPlanRepository,
    },
    JourneysService,
  ],
  exports: [JourneysService],
})
export class JourneysModule {}
