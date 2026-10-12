import { Module } from '@nestjs/common';

import { IdentityModule } from '../identity/identity.module';
import { DatabaseModule } from '../shared/database/database.module';
import { CommutesService } from './application/commutes.service';
import { COMMUTE_REPOSITORY } from './domain/commutes.ports';
import { CommutesController } from './http/commutes.controller';
import { PrismaCommuteRepository } from './infrastructure/prisma-commutes.repository';

@Module({
  imports: [DatabaseModule, IdentityModule],
  controllers: [CommutesController],
  providers: [PrismaCommuteRepository, { provide: COMMUTE_REPOSITORY, useExisting: PrismaCommuteRepository }, CommutesService],
  exports: [CommutesService, COMMUTE_REPOSITORY],
})
export class CommutesModule {}
