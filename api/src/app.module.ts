import { Module } from '@nestjs/common';

import { AppConfigModule } from './config/config.module';
import { ProviderGatewayModule } from './provider-gateway/provider-gateway.module';
import { HealthModule } from './shared/health/health.module';

@Module({
  imports: [AppConfigModule, HealthModule, ProviderGatewayModule],
})
export class AppModule {}
