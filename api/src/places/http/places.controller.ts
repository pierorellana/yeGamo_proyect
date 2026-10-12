import { Controller, Get, Query } from '@nestjs/common';

import type { Place } from '../../provider-gateway/domain/provider.types';
import { PlacesService } from '../application/places.service';
import { ReversePlaceQueryDto, SearchPlacesQueryDto } from './places.dto';

@Controller('places')
export class PlacesController {
  constructor(private readonly places: PlacesService) {}

  @Get('search')
  search(@Query() query: SearchPlacesQueryDto): Promise<Place[]> {
    const near =
      query.lat === undefined || query.lon === undefined
        ? undefined
        : { lat: query.lat, lon: query.lon };

    return near === undefined
      ? this.places.search({ query: query.q })
      : this.places.search({ query: query.q, near });
  }

  @Get('reverse')
  reverse(@Query() query: ReversePlaceQueryDto): Promise<Place> {
    return this.places.reverse({ lat: query.lat, lon: query.lon });
  }
}
