import { Module } from '@nestjs/common';

import { AppConfigModule } from './config/config.module';
import { HealthModule } from './shared/health/health.module';

@Module({
  imports: [AppConfigModule, HealthModule],
})
export class AppModule {}
