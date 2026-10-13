import { Module } from '@nestjs/common';

import { DatabaseModule } from '../shared/database/database.module';
import {
  TransitService,
} from './application/transit.service';
import {
  TRANSIT_READ_PORT,
} from './domain/transit.ports';
import { TransitController } from './http/transit.controller';
import { PrismaTransitReadRepository } from './infrastructure/prisma-transit.repository';

@Module({
  imports: [DatabaseModule],
  controllers: [TransitController],
  providers: [
    PrismaTransitReadRepository,
    {
      provide: TRANSIT_READ_PORT,
      useClass: PrismaTransitReadRepository,
    },
    TransitService,
  ],
  exports: [TransitService],
})
export class TransitModule {}
