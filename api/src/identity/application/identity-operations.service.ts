import { ConflictException, Injectable, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import { PrismaService } from '../../shared/database/prisma.service';
import { IdempotencyService } from '../../shared/idempotency/idempotency.service';
import { hashRequest } from '../../shared/idempotency/idempotency.service';
import type { AuthPrincipal } from '../domain/identity.ports';
import type { DeviceInstallationDto, GuestMigrationDto } from '../http/identity.dto';
import { MAX_MIGRATION_ITEMS, MigrationItemResult, SUPPORTED_CLIENT_DATA_VERSION, migrateItem } from './guest-migration';

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

  /**
   * Imports a guest package into the account. Atomic: every item is processed in
   * one transaction together with its audit row. Items are validated one by one,
   * so a bad item is REJECTED with a canonical reason and nothing is silently
   * dropped; duplicates are reported (never re-created) and a replay of the same
   * package returns the original counts.
   */
  async migrateGuest(principal: AuthPrincipal, input: GuestMigrationDto, key: string | undefined): Promise<Record<string, unknown>> {
    return this.idempotency.execute(principal.userId, key, input, async () => {
      if (input.clientDataVersion !== SUPPORTED_CLIENT_DATA_VERSION) {
        throw new UnprocessableEntityException({ code: 'VALIDATION_ERROR', message: `clientDataVersion no soportada; usa "${SUPPORTED_CLIENT_DATA_VERSION}".`, details: { field: 'clientDataVersion' } });
      }
      if (input.items.length > MAX_MIGRATION_ITEMS) {
        throw new UnprocessableEntityException({ code: 'VALIDATION_ERROR', message: `Máximo ${MAX_MIGRATION_ITEMS} elementos por migración.`, details: { field: 'items' } });
      }
      const requestHash = hashRequest(input);
      const existing = await this.prisma.guestMigrationAudit.findFirst({ where: { userId: principal.userId, requestHash, status: 'COMPLETED' }, orderBy: { createdAt: 'desc' } });
      if (existing !== null) return { ...summaryOf(existing.importedCounts), migrationId: existing.id, idempotentReplay: true };

      return this.prisma.$transaction(async (tx) => {
        const results: MigrationItemResult[] = [];
        for (const [index, item] of input.items.entries()) {
          results.push(await migrateItem(tx, principal.userId, index, item));
        }
        const summary = {
          importedCount: results.filter((r) => r.status === 'IMPORTED').length,
          skippedCount: results.filter((r) => r.status === 'DUPLICATE').length,
          rejectedCount: results.filter((r) => r.status === 'REJECTED').length,
          results,
        };
        const audit = await tx.guestMigrationAudit.create({
          data: {
            userId: principal.userId,
            idempotencyKey: key ?? 'validated-by-service',
            requestHash,
            status: 'COMPLETED',
            importedCounts: JSON.parse(JSON.stringify(summary)),
            completedAt: new Date(),
          },
        });
        return { ...summary, migrationId: audit.id, idempotentReplay: false };
      });
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

function summaryOf(stored: unknown): { importedCount: number; skippedCount: number; rejectedCount: number; results: unknown[] } {
  const value = typeof stored === 'object' && stored !== null ? (stored as Record<string, unknown>) : {};
  return {
    importedCount: typeof value.importedCount === 'number' ? value.importedCount : 0,
    skippedCount: typeof value.skippedCount === 'number' ? value.skippedCount : 0,
    rejectedCount: typeof value.rejectedCount === 'number' ? value.rejectedCount : 0,
    results: Array.isArray(value.results) ? value.results : [],
  };
}
