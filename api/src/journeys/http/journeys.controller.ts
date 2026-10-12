import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Req } from '@nestjs/common';
import type { Request } from 'express';

import type { TraceableRequest } from '../../shared/trace/trace-context';
import type { TransitPlan } from '../../provider-gateway/domain/provider.types';
import { JourneysService } from '../application/journeys.service';
import { RequestContext } from '../domain/journeys.ports';
import {
  JourneyPlanParamDto,
  JourneyPlanRequestDto,
} from './journeys.dto';

@Controller('journeys')
export class JourneysController {
  constructor(private readonly journeys: JourneysService) {}

  @Post('plan')
  @HttpCode(HttpStatus.OK)
  plan(
    @Body() body: JourneyPlanRequestDto,
    @Req() request: TraceableRequest,
  ): Promise<TransitPlan> {
    return this.journeys.plan(toJourneyPlanRequest(body), contextOf(request));
  }

  @Get(':planId')
  get(
    @Param() params: JourneyPlanParamDto,
    @Req() request: TraceableRequest,
  ): Promise<TransitPlan> {
    return this.journeys.get(params.planId, contextOf(request));
  }
}

function contextOf(request: Request & { traceId?: string }): RequestContext {
  return { traceId: request.traceId ?? 'unknown' };
}

function toJourneyPlanRequest(body: JourneyPlanRequestDto) {
  const request = {
    origin: { lat: body.origin.lat, lon: body.origin.lon },
    destination: { lat: body.destination.lat, lon: body.destination.lon },
    timeMode: body.timeMode,
    preference: body.preference,
    maxWalkMin: body.maxWalkMin,
    extraSafetyMarginMin: body.extraSafetyMarginMin,
  };

  return body.time === undefined ? request : { ...request, time: body.time };
}
