import { Controller, Get, UseGuards } from '@nestjs/common';

import { PrincipalAuthGuard } from '../../identity/http/auth.guard';
import { ProviderHealthService } from '../application/provider-health.service';

@Controller('providers')
@UseGuards(PrincipalAuthGuard)
export class ProviderStatusController {
  constructor(private readonly health: ProviderHealthService) {}

  @Get('status')
  status() {
    return this.health.getSnapshots();
  }
}
