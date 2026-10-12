import { Controller, Get, HttpCode, HttpStatus, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AuthenticatedRequest, principalOf, PrincipalAuthGuard } from '../../identity/http/auth.guard';
import { NotificationsService } from '../application/notifications.service';
import { NotificationIdDto, NotificationQueryDto } from './notifications.dto';

@Controller('notifications')
@UseGuards(PrincipalAuthGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest, @Query() query: NotificationQueryDto) { return this.notifications.list(principalOf(request).userId, query.page, query.pageSize); }

  @Patch(':id/read')
  markRead(@Req() request: AuthenticatedRequest, @Param() params: NotificationIdDto) { return this.notifications.markRead(principalOf(request).userId, params.id); }

  @Post('read-all')
  @HttpCode(HttpStatus.NO_CONTENT)
  markAllRead(@Req() request: AuthenticatedRequest): Promise<void> { return this.notifications.markAllRead(principalOf(request).userId); }
}
