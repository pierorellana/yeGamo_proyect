import { Module } from '@nestjs/common';

import { IdentityModule } from '../identity/identity.module';
import { DatabaseModule } from '../shared/database/database.module';
import { NotificationsService } from './application/notifications.service';
import { NOTIFICATION_REPOSITORY } from './domain/notifications.ports';
import { NotificationsController } from './http/notifications.controller';
import { PrismaNotificationRepository } from './infrastructure/prisma-notifications.repository';

@Module({
  imports: [DatabaseModule, IdentityModule],
  controllers: [NotificationsController],
  providers: [PrismaNotificationRepository, { provide: NOTIFICATION_REPOSITORY, useExisting: PrismaNotificationRepository }, NotificationsService],
  exports: [NotificationsService, NOTIFICATION_REPOSITORY],
})
export class NotificationsModule {}
