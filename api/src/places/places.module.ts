import { Module } from '@nestjs/common';

import {
  GeocodingGatewayService,
} from '../provider-gateway/application/geocoding-gateway.service';
import { ProviderGatewayModule } from '../provider-gateway/provider-gateway.module';
import { PlacesService } from './application/places.service';
import { PLACES_GATEWAY } from './domain/places.ports';
import { PlacesController } from './http/places.controller';

@Module({
  imports: [ProviderGatewayModule],
  controllers: [PlacesController],
  providers: [
    {
      provide: PLACES_GATEWAY,
      useExisting: GeocodingGatewayService,
    },
    PlacesService,
  ],
  exports: [PlacesService],
})
export class PlacesModule {}
