import { Module } from '@nestjs/common';

import {
  TransitService,
} from './application/transit.service';
import {
  TRANSIT_READ_PORT,
  UnavailableTransitReadPort,
} from './domain/transit.ports';
import { TransitController } from './http/transit.controller';

@Module({
  controllers: [TransitController],
  providers: [
    {
      provide: TRANSIT_READ_PORT,
      useClass: UnavailableTransitReadPort,
    },
    TransitService,
  ],
  exports: [TransitService],
})
export class TransitModule {}
