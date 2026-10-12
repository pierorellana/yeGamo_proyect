import { Body, Controller, Delete, Get, Headers, HttpCode, HttpStatus, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import type { AuthenticatedRequest } from './auth.guard';
import { principalOf, PrincipalAuthGuard } from './auth.guard';
import { IdentityOperationsService } from '../application/identity-operations.service';
import { IdentityService } from '../application/identity.service';
import { DeviceIdDto, DeviceInstallationDto, GuestMigrationDto, PreferencesDto } from './identity.dto';

@Controller('me')
@UseGuards(PrincipalAuthGuard)
export class IdentityController {
  constructor(private readonly identity: IdentityService, private readonly operations: IdentityOperationsService) {}

  @Get()
  me(@Req() request: AuthenticatedRequest) {
    return this.identity.getCurrentUser(principalOf(request).userId);
  }

  @Delete()
  @HttpCode(HttpStatus.ACCEPTED)
  async delete(@Req() request: AuthenticatedRequest, @Headers('idempotency-key') key: string | undefined): Promise<void> {
    await this.operations.deleteAccount(principalOf(request), key);
  }

  @Post('guest-migration')
  @HttpCode(HttpStatus.OK)
  migrate(@Req() request: AuthenticatedRequest, @Body() body: GuestMigrationDto, @Headers('idempotency-key') key: string | undefined) {
    return this.operations.migrateGuest(principalOf(request), body, key);
  }

  @Post('devices')
  registerDevice(@Req() request: AuthenticatedRequest, @Body() body: DeviceInstallationDto, @Headers('idempotency-key') key: string | undefined) {
    return this.operations.registerDevice(principalOf(request), body, key);
  }

  @Delete('devices/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  revokeDevice(@Req() request: AuthenticatedRequest, @Param() params: DeviceIdDto): Promise<void> {
    return this.operations.revokeDevice(principalOf(request), params.id);
  }

  @Get('preferences')
  preferences(@Req() request: AuthenticatedRequest) {
    return this.identity.getPreferences(principalOf(request).userId);
  }

  @Patch('preferences')
  preferencesUpdate(@Req() request: AuthenticatedRequest, @Body() body: PreferencesDto) {
    return this.identity.updatePreferences(principalOf(request).userId, body);
  }

  @Post('data-export')
  @HttpCode(HttpStatus.ACCEPTED)
  requestExport(@Req() request: AuthenticatedRequest, @Headers('idempotency-key') key: string | undefined) {
    return this.operations.requestExport(principalOf(request), key);
  }
}
