import { Body, Controller, Delete, Get, Headers, HttpCode, HttpStatus, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { AuthenticatedRequest, principalOf, PrincipalAuthGuard } from '../../identity/http/auth.guard';
import { CommutesService } from '../application/commutes.service';
import { CommuteIdDto, CommuteProfileDto } from './commutes.dto';

@Controller('commute-profiles')
@UseGuards(PrincipalAuthGuard)
export class CommutesController {
  constructor(private readonly commutes: CommutesService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest) { return this.commutes.list(principalOf(request).userId); }

  @Post()
  create(@Req() request: AuthenticatedRequest, @Body() body: CommuteProfileDto, @Headers('idempotency-key') key: string | undefined) { return this.commutes.create(principalOf(request).userId, body, key); }

  @Patch(':id')
  update(@Req() request: AuthenticatedRequest, @Param() params: CommuteIdDto, @Body() body: CommuteProfileDto) { return this.commutes.update(principalOf(request).userId, params.id, body); }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  delete(@Req() request: AuthenticatedRequest, @Param() params: CommuteIdDto): Promise<void> { return this.commutes.delete(principalOf(request).userId, params.id); }

  @Post(':id/pause')
  pause(@Req() request: AuthenticatedRequest, @Param() params: CommuteIdDto, @Headers('idempotency-key') key: string | undefined) { return this.commutes.setEnabled(principalOf(request).userId, params.id, false, key); }

  @Post(':id/resume')
  resume(@Req() request: AuthenticatedRequest, @Param() params: CommuteIdDto, @Headers('idempotency-key') key: string | undefined) { return this.commutes.setEnabled(principalOf(request).userId, params.id, true, key); }
}
