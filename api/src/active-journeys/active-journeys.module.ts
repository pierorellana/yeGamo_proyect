import { Module } from '@nestjs/common';

import { IdentityModule } from '../identity/identity.module';
import { DatabaseModule } from '../shared/database/database.module';
import { ActiveJourneysService } from './application/active-journeys.service';
import { ACTIVE_JOURNEY_REPOSITORY } from './domain/active-journeys.ports';
import { ActiveJourneysController } from './http/active-journeys.controller';
import { PrismaActiveJourneyRepository } from './infrastructure/prisma-active-journeys.repository';

@Module({
  imports: [DatabaseModule, IdentityModule],
  controllers: [ActiveJourneysController],
  providers: [PrismaActiveJourneyRepository, { provide: ACTIVE_JOURNEY_REPOSITORY, useExisting: PrismaActiveJourneyRepository }, ActiveJourneysService],
  exports: [ActiveJourneysService, ACTIVE_JOURNEY_REPOSITORY],
})
export class ActiveJourneysModule {}
