import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface HealthResponse {
  status: 'ok' | 'degraded';
  version: string;
  traceId: string;
}

@Injectable()
export class HealthService {
  constructor(private readonly config: ConfigService) {}

  getHealth(traceId: string): HealthResponse {
    return {
      status: 'ok',
      version: this.config.get<string>('appVersion', '1.1.1'),
      traceId,
    };
  }
}
