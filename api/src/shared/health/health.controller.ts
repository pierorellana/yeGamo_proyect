import { Controller, Get, Req } from '@nestjs/common';
import type { TraceableRequest } from '../trace/trace-context';
import { HealthResponse, HealthService } from './health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly health: HealthService) {}

  @Get()
  getHealth(@Req() request: TraceableRequest): HealthResponse {
    return this.health.getHealth(request.traceId ?? 'unknown');
  }
}
