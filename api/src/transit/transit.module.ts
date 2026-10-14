import { Module } from '@nestjs/common';

import { ProviderGatewayModule } from '../provider-gateway/provider-gateway.module';
import { DatabaseModule } from '../shared/database/database.module';
import {
  TransitService,
} from './application/transit.service';
import {
  TRANSIT_CATALOG_WRITE_PORT,
  TRANSIT_READ_PORT,
} from './domain/transit.ports';
import { TransitController } from './http/transit.controller';
import { PrismaTransitReadRepository } from './infrastructure/prisma-transit.repository';

@Module({
  imports: [DatabaseModule, ProviderGatewayModule],
  controllers: [TransitController],
  providers: [
    PrismaTransitReadRepository,
    {
      provide: TRANSIT_READ_PORT,
      useExisting: PrismaTransitReadRepository,
    },
    {
      provide: TRANSIT_CATALOG_WRITE_PORT,
      useExisting: PrismaTransitReadRepository,
    },
    TransitService,
  ],
  exports: [TransitService],
})
export class TransitModule {}
