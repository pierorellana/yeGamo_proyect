import { Body, Controller, Delete, Headers, HttpCode, HttpStatus, Param, Post, Req, UseGuards } from '@nestjs/common';
import { AuthenticatedRequest, principalOf, PrincipalAuthGuard } from '../../identity/http/auth.guard';
import { AlertsService } from '../application/alerts.service';
import { LeaveAlertDto, LeaveAlertIdDto } from './alerts.dto';

@Controller('alerts')
@UseGuards(PrincipalAuthGuard)
export class AlertsController {
  constructor(private readonly alerts: AlertsService) {}

  @Post('leave')
  create(@Req() request: AuthenticatedRequest, @Body() body: LeaveAlertDto, @Headers('idempotency-key') key: string | undefined) { return this.alerts.create(principalOf(request).userId, body, key); }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  delete(@Req() request: AuthenticatedRequest, @Param() params: LeaveAlertIdDto): Promise<void> { return this.alerts.delete(principalOf(request).userId, params.id); }
}
