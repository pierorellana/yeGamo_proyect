import { Module } from '@nestjs/common';

import { AlertsModule } from '../alerts/alerts.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ProviderGatewayModule } from '../provider-gateway/provider-gateway.module';
import { DatabaseModule } from '../shared/database/database.module';
import { WorkerScheduler } from './application/worker.scheduler';
import { DisabledNotificationDelivery, WorkerService } from './application/worker.service';
import { NOTIFICATION_DELIVERY_PORT } from './domain/worker.ports';

@Module({
  imports: [DatabaseModule, AlertsModule, NotificationsModule, ProviderGatewayModule],
  providers: [WorkerService, WorkerScheduler, DisabledNotificationDelivery, { provide: NOTIFICATION_DELIVERY_PORT, useExisting: DisabledNotificationDelivery }],
  exports: [WorkerService],
})
export class WorkerModule {}
