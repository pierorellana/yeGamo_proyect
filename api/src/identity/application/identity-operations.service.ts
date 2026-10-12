import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/database/prisma.service';
import { IdempotencyService } from '../../shared/idempotency/idempotency.service';
import { hashRequest } from '../../shared/idempotency/idempotency.service';
import type { AuthPrincipal } from '../domain/identity.ports';
import type { DeviceInstallationDto, GuestMigrationDto } from '../http/identity.dto';

@Injectable()
export class IdentityOperationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
  ) {}

  async registerDevice(principal: AuthPrincipal, input: DeviceInstallationDto, key: string | undefined): Promise<Record<string, unknown>> {
    return this.idempotency.execute(principal.userId, key, input, async () => {
      const device = await this.prisma.deviceInstallation.upsert({
        where: { userId_installationKey: { userId: principal.userId, installationKey: input.installationId } },
        create: {
          userId: principal.userId,
          installationKey: input.installationId,
          platform: input.platform,
          pushToken: input.pushToken,
          ...(input.appVersion === undefined ? {} : { appVersion: input.appVersion }),
          enabled: true,
          lastSeenAt: new Date(),
        },
        update: { platform: input.platform, pushToken: input.pushToken, ...(input.appVersion === undefined ? {} : { appVersion: input.appVersion }), enabled: true, lastSeenAt: new Date() },
      });
      return {
        id: device.id,
        installationId: device.installationKey,
        platform: device.platform,
        appVersion: device.appVersion,
        active: device.enabled,
        lastSeenAt: device.lastSeenAt?.toISOString() ?? null,
      };
    }, 201);
  }

  async revokeDevice(principal: AuthPrincipal, id: string): Promise<void> {
    const result = await this.prisma.deviceInstallation.updateMany({ where: { id, userId: principal.userId, enabled: true }, data: { enabled: false, updatedAt: new Date() } });
    if (result.count === 0) throw new NotFoundException({ code: 'NOT_FOUND', message: 'La instalación no existe.', details: { resource: 'device-installation', id } });
  }

  deleteAccount(principal: AuthPrincipal, key: string | undefined): Promise<{ accepted: true }> {
    return this.idempotency.execute(principal.userId, key, { operation: 'delete-account' }, async () => {
      await this.prisma.user.update({ where: { id: principal.userId }, data: { deletedAt: new Date() } });
      return { accepted: true };
    }, 202);
  }

  async migrateGuest(principal: AuthPrincipal, input: GuestMigrationDto, key: string | undefined): Promise<Record<string, unknown>> {
    return this.idempotency.execute(principal.userId, key, input, async () => {
      const requestHash = hashRequest(input);
      const existing = await this.prisma.guestMigrationAudit.findFirst({ where: { userId: principal.userId, requestHash }, orderBy: { createdAt: 'desc' } });
      if (existing !== null) return { migrationId: existing.id, importedCount: 0, skippedCount: input.items.length, idempotentReplay: true };
      const audit = await this.prisma.guestMigrationAudit.create({
        data: {
          userId: principal.userId,
          idempotencyKey: key ?? 'validated-by-service',
          requestHash,
          status: 'COMPLETED',
          importedCounts: { items: 0 },
          completedAt: new Date(),
        },
      });
      return { migrationId: audit.id, importedCount: 0, skippedCount: input.items.length, idempotentReplay: false };
    });
  }

  async requestExport(principal: AuthPrincipal, key: string | undefined): Promise<Record<string, unknown>> {
    return this.idempotency.execute(principal.userId, key, { operation: 'data-export' }, async () => {
      const active = await this.prisma.dataExportRequest.findFirst({ where: { userId: principal.userId, status: { in: ['REQUESTED', 'PROCESSING', 'READY'] } }, orderBy: { requestedAt: 'desc' } });
      if (active !== null) throw new ConflictException({ code: 'EXPORT_ALREADY_REQUESTED', message: 'Ya existe una exportación activa.', details: { resource: 'data-export' } });
      const requestedAt = new Date();
      const exportRequest = await this.prisma.dataExportRequest.create({ data: { userId: principal.userId, status: 'REQUESTED', format: 'JSON', requestedAt, expiresAt: new Date(requestedAt.getTime() + 7 * 24 * 60 * 60 * 1000) } });
      return { id: exportRequest.id, status: 'QUEUED', requestedAt: exportRequest.requestedAt.toISOString(), expiresAt: exportRequest.expiresAt?.toISOString() ?? null };
    }, 202);
  }
}
