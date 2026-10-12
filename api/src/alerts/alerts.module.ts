import { Module } from '@nestjs/common';

import { CommutesModule } from '../commutes/commutes.module';
import { IdentityModule } from '../identity/identity.module';
import { DatabaseModule } from '../shared/database/database.module';
import { AlertsService } from './application/alerts.service';
import { LEAVE_ALERT_REPOSITORY } from './domain/alerts.ports';
import { AlertsController } from './http/alerts.controller';
import { PrismaLeaveAlertRepository } from './infrastructure/prisma-alerts.repository';

@Module({
  imports: [DatabaseModule, IdentityModule, CommutesModule],
  controllers: [AlertsController],
  providers: [PrismaLeaveAlertRepository, { provide: LEAVE_ALERT_REPOSITORY, useExisting: PrismaLeaveAlertRepository }, AlertsService],
  exports: [AlertsService, LEAVE_ALERT_REPOSITORY],
})
export class AlertsModule {}
