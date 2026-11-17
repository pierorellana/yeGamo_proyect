import { Module } from '@nestjs/common';

import { ProviderGatewayModule } from '../provider-gateway/provider-gateway.module';
import { TransitGatewayService } from '../provider-gateway/application/transit-gateway.service';
import { JourneysService } from './application/journeys.service';
import {
  JOURNEY_PLAN_REPOSITORY,
  JOURNEY_TRANSIT_PORT,
} from './domain/journeys.ports';
import { JourneysController } from './http/journeys.controller';
import { PrismaJourneyPlanRepository } from './infrastructure/prisma-journey-plans.repository';
import { DatabaseModule } from '../shared/database/database.module';

@Module({
  imports: [ProviderGatewayModule, DatabaseModule],
  controllers: [JourneysController],
  providers: [
    {
      provide: JOURNEY_TRANSIT_PORT,
      useExisting: TransitGatewayService,
    },
    PrismaJourneyPlanRepository,
    {
      provide: JOURNEY_PLAN_REPOSITORY,
      useExisting: PrismaJourneyPlanRepository,
    },
    JourneysService,
  ],
  exports: [JourneysService],
})
export class JourneysModule {}
