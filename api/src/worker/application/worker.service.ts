import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';

import { AlertsService } from '../../alerts/application/alerts.service';
import { NotificationsService } from '../../notifications/application/notifications.service';
import { ProviderHealthService } from '../../provider-gateway/application/provider-health.service';
import { PrismaService } from '../../shared/database/prisma.service';
import { NOTIFICATION_DELIVERY_PORT, NotificationDeliveryPort, WorkerRunResult } from '../domain/worker.ports';

@Injectable()
export class WorkerService {
  constructor(
    private readonly config: ConfigService,
    private readonly alerts: AlertsService,
    private readonly notifications: NotificationsService,
    private readonly health: ProviderHealthService,
    private readonly prisma: PrismaService,
    @Inject(NOTIFICATION_DELIVERY_PORT) private readonly delivery: NotificationDeliveryPort,
  ) {}

  isEnabled(): boolean { return this.config.get<string>('WORKERS_ENABLED', process.env.WORKERS_ENABLED ?? 'false') === 'true'; }

  async runAlerts(now = new Date(), force = false): Promise<WorkerRunResult> {
    if (!this.isEnabled() && !force) return disabled('alerts', now);
    const due = await this.alerts.due(now);
    for (const alert of due) {
      await this.notifications.create(alert.userId, { type: 'LEAVE_ALERT', title: 'Hora de salir', body: 'Tu aviso de salida está listo.', payload: { alertId: alert.id }, deduplicationKey: `leave-alert:${alert.id}` });
      await this.alerts.markTriggered(alert.id);
    }
    return { worker: 'alerts', enabled: true, processed: due.length, ranAt: now.toISOString() };
  }

  async runDelivery(now = new Date(), force = false): Promise<WorkerRunResult> {
    if (!this.isEnabled() && !force) return disabled('delivery', now);
    const processed = await this.delivery.deliverPending(now);
    return { worker: 'delivery', enabled: true, processed, ranAt: now.toISOString() };
  }

  async runProviderHealth(now = new Date(), force = false): Promise<WorkerRunResult> {
    if (!this.isEnabled() && !force) return disabled('provider-health', now);
    const snapshots = this.health.getSnapshots(now);
    await this.prisma.providerHealthSnapshot.createMany({
      data: snapshots.map((snapshot) => ({ provider: snapshot.provider ?? 'none', capability: snapshot.capability, status: snapshot.status, latencyMs: snapshot.latencyMs, observedAt: now, metadata: { sourceAuthorized: snapshot.status === 'HEALTHY' } })),
    });
    return { worker: 'provider-health', enabled: true, processed: snapshots.length, ranAt: now.toISOString() };
  }

  async runRetention(now = new Date(), force = false): Promise<WorkerRunResult> {
    if (!this.isEnabled() && !force) return disabled('retention', now);
    const routeObservations = await this.prisma.$executeRaw(Prisma.sql`
      DELETE FROM route_observations ro USING retention_policies rp
      WHERE rp.table_name = 'route_observations' AND ro.observed_at < ${now} - rp.retention_interval`);
    const providerHealth = await this.prisma.$executeRaw(Prisma.sql`
      DELETE FROM provider_health_snapshots ph USING retention_policies rp
      WHERE rp.table_name = 'provider_health_snapshots' AND ph.observed_at < ${now} - rp.retention_interval`);
    const reports = await this.prisma.$executeRaw(Prisma.sql`
      DELETE FROM community_reports cr USING retention_policies rp
      WHERE rp.table_name = 'community_reports' AND cr.created_at < ${now} - rp.retention_interval`);
    const events = await this.prisma.$executeRaw(Prisma.sql`
      DELETE FROM journey_events je USING retention_policies rp, active_journeys aj
      LEFT JOIN user_preferences up ON up.user_id = aj.user_id
      WHERE rp.table_name = 'journey_events' AND aj.id = je.active_journey_id
        AND je.occurred_at < ${now} - rp.retention_interval
        AND COALESCE(up.recurring_trips_consent, false) = false`);
    const idempotency = await this.prisma.$executeRaw(Prisma.sql`DELETE FROM idempotency_operations WHERE expires_at <= ${now}`);
    return { worker: 'retention', enabled: true, processed: Number(routeObservations) + Number(providerHealth) + Number(reports) + Number(events) + Number(idempotency), ranAt: now.toISOString() };
  }
}

function disabled(worker: string, now: Date): WorkerRunResult { return { worker, enabled: false, processed: 0, ranAt: now.toISOString() }; }

@Injectable()
export class DisabledNotificationDelivery implements NotificationDeliveryPort {
  deliverPending(): Promise<number> { return Promise.resolve(0); }
}
