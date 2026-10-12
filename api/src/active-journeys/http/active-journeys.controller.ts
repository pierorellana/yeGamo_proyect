import { Body, Controller, Headers, Param, Patch, Post, Req, UseGuards, Get } from '@nestjs/common';
import { AuthenticatedRequest, principalOf, PrincipalAuthGuard } from '../../identity/http/auth.guard';
import { ActiveJourneysService } from '../application/active-journeys.service';
import { ActiveJourneyIdDto, ActiveJourneyStartParamsDto, JourneyProgressDto } from './active-journeys.dto';

@Controller()
@UseGuards(PrincipalAuthGuard)
export class ActiveJourneysController {
  constructor(private readonly journeys: ActiveJourneysService) {}

  @Post('journeys/:planId/options/:optionId/start')
  start(@Req() request: AuthenticatedRequest, @Param() params: ActiveJourneyStartParamsDto, @Headers('idempotency-key') key: string | undefined) { return this.journeys.start(principalOf(request).userId, params.planId, params.optionId, key); }

  @Get('active-journeys/:id')
  get(@Req() request: AuthenticatedRequest, @Param() params: ActiveJourneyIdDto) { return this.journeys.get(principalOf(request).userId, params.id); }

  @Patch('active-journeys/:id/progress')
  progress(@Req() request: AuthenticatedRequest, @Param() params: ActiveJourneyIdDto, @Body() body: JourneyProgressDto, @Headers('idempotency-key') key: string | undefined) { return this.journeys.progress(principalOf(request).userId, params.id, body, key); }

  @Post('active-journeys/:id/finish')
  finish(@Req() request: AuthenticatedRequest, @Param() params: ActiveJourneyIdDto, @Headers('idempotency-key') key: string | undefined) { return this.journeys.finish(principalOf(request).userId, params.id, key); }

  @Post('active-journeys/:id/cancel')
  cancel(@Req() request: AuthenticatedRequest, @Param() params: ActiveJourneyIdDto, @Headers('idempotency-key') key: string | undefined) { return this.journeys.cancel(principalOf(request).userId, params.id, key); }
}
