import { ConflictException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/database/prisma.service';
import type { LeaveAlert, LeaveAlertInput, LeaveAlertRepository } from '../domain/alerts.ports';

@Injectable()
export class PrismaLeaveAlertRepository implements LeaveAlertRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, input: LeaveAlertInput, idempotencyKey: string): Promise<LeaveAlert> {
    try {
      return await this.createRow(userId, input, idempotencyKey);
    } catch (error) {
      if (typeof error === 'object' && error !== null && (error as { code?: unknown }).code === 'P2002') {
        throw new ConflictException({ code: 'ALERT_ALREADY_SCHEDULED', message: 'Ya existe un aviso pendiente para este plan o rutina.', details: { resource: 'leave-alert' } });
      }
      throw error;
    }
  }

  private async createRow(userId: string, input: LeaveAlertInput, idempotencyKey: string): Promise<LeaveAlert> {
    const item = await this.prisma.leaveAlert.create({ data: { userId, ...(input.commuteProfileId === undefined ? {} : { commuteProfileId: input.commuteProfileId }), ...(input.journeyPlanId === undefined ? {} : { journeyPlanId: input.journeyPlanId }), scheduledFor: new Date(input.scheduledFor), idempotencyKey } });
    return toAlert(item);
  }

  /** Plans are created anonymously by POST /journeys/plan (user_id NULL); owned plans also qualify. */
  async journeyPlanBelongsToUser(userId: string, id: string): Promise<boolean> {
    const plan = await this.prisma.journeyPlan.findFirst({
      where: { id, OR: [{ userId }, { userId: null }], AND: [{ OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }] }] },
    });
    return plan !== null;
  }

  async claim(id: string, now: Date): Promise<boolean> {
    const result = await this.prisma.leaveAlert.updateMany({ where: { id, status: 'SCHEDULED' }, data: { status: 'TRIGGERED', triggeredAt: now } });
    return result.count === 1;
  }

  async markExpired(id: string): Promise<void> {
    await this.prisma.leaveAlert.updateMany({ where: { id, status: 'SCHEDULED' }, data: { status: 'EXPIRED' } });
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
