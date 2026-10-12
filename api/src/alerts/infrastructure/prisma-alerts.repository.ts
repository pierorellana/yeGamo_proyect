import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/database/prisma.service';
import type { LeaveAlert, LeaveAlertInput, LeaveAlertRepository } from '../domain/alerts.ports';

@Injectable()
export class PrismaLeaveAlertRepository implements LeaveAlertRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, input: LeaveAlertInput, idempotencyKey: string): Promise<LeaveAlert> {
    const item = await this.prisma.leaveAlert.create({ data: { userId, ...(input.commuteProfileId === undefined ? {} : { commuteProfileId: input.commuteProfileId }), ...(input.journeyPlanId === undefined ? {} : { journeyPlanId: input.journeyPlanId }), scheduledFor: new Date(input.scheduledFor), idempotencyKey } });
    return toAlert(item);
  }

  async journeyPlanBelongsToUser(userId: string, id: string): Promise<boolean> {
    const plan = await this.prisma.journeyPlan.findFirst({ where: { id, userId } });
    return plan !== null;
  }

  async delete(userId: string, id: string): Promise<boolean> {
    const result = await this.prisma.leaveAlert.updateMany({ where: { id, userId, status: 'SCHEDULED' }, data: { status: 'CANCELLED' } });
    return result.count > 0;
  }

  async due(now: Date): Promise<Array<LeaveAlert & { userId: string }>> {
    const items = await this.prisma.leaveAlert.findMany({ where: { scheduledFor: { lte: now }, status: 'SCHEDULED' } });
    return items.map((item) => ({ ...toAlert(item), userId: item.userId }));
  }

  async markTriggered(id: string): Promise<void> {
    await this.prisma.leaveAlert.update({ where: { id }, data: { status: 'TRIGGERED', triggeredAt: new Date() } });
  }
}

function toAlert(item: { id: string; scheduledFor: Date; status: string }): LeaveAlert {
  return { id: item.id, scheduledFor: item.scheduledFor.toISOString(), status: item.status as LeaveAlert['status'] };
}
