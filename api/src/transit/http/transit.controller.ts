import { Controller, Get, Param, Query } from '@nestjs/common';

import { TransitService } from '../application/transit.service';
import {
  NearbyStopsQueryDto,
  RouteIdParamDto,
  StopIdParamDto,
} from './transit.dto';

@Controller('transit')
export class TransitController {
  constructor(private readonly transit: TransitService) {}

  @Get('stops/nearby')
  nearbyStops(@Query() query: NearbyStopsQueryDto) {
    return this.transit.nearbyStops({
      lat: query.lat,
      lon: query.lon,
      radiusM: query.radiusM,
    });
  }

  @Get('stops/:stopId/departures')
  departures(@Param() params: StopIdParamDto) {
    return this.transit.departures(params.stopId);
  }

  @Get('routes/:routeId')
  route(@Param() params: RouteIdParamDto) {
    return this.transit.route(params.routeId);
  }
}
