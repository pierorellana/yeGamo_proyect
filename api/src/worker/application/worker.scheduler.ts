import { Injectable, Logger, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { PrismaService } from '../../shared/database/prisma.service';
import { WorkerService } from './worker.service';

interface Job {
  readonly name: string;
  readonly everyMs: number;
  readonly run: () => Promise<unknown>;
}

/**
 * In-process scheduler for the modular monolith (no extra infrastructure). It only
 * runs when WORKERS_ENABLED=true. Each tick takes a PostgreSQL advisory lock, so with
 * several API instances only one executes a job at a time, and a job never overlaps
 * itself.
 */
@Injectable()
export class WorkerScheduler implements OnApplicationBootstrap, OnApplicationShutdown {
  private readonly logger = new Logger(WorkerScheduler.name);
  private readonly timers: ReturnType<typeof setInterval>[] = [];
  private readonly running = new Set<string>();

  constructor(
    private readonly workers: WorkerService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  onApplicationBootstrap(): void {
    if (!this.workers.isEnabled()) return;
    const jobs: Job[] = [
      { name: 'alerts', everyMs: this.interval('WORKER_ALERTS_INTERVAL_MS', 30_000), run: () => this.workers.runAlerts() },
      { name: 'delivery', everyMs: this.interval('WORKER_DELIVERY_INTERVAL_MS', 60_000), run: () => this.workers.runDelivery() },
      { name: 'provider-health', everyMs: this.interval('WORKER_HEALTH_INTERVAL_MS', 300_000), run: () => this.workers.runProviderHealth() },
      { name: 'retention', everyMs: this.interval('WORKER_RETENTION_INTERVAL_MS', 3_600_000), run: () => this.workers.runRetention() },
    ];
    for (const job of jobs) {
      const timer = setInterval(() => void this.tick(job), job.everyMs);
      timer.unref();
      this.timers.push(timer);
    }
    this.logger.log(`Workers enabled: ${jobs.map((job) => `${job.name}/${job.everyMs}ms`).join(', ')}`);
  }

  onApplicationShutdown(): void {
    for (const timer of this.timers) clearInterval(timer);
  }

  /**
   * Runs one job under a transaction-scoped advisory lock (released on commit, so it
   * is safe with pooled connections). Returns false when skipped or failed.
   */
  async tick(job: Job): Promise<boolean> {
    if (this.running.has(job.name)) return false;
    this.running.add(job.name);
    try {
      return await this.prisma.$transaction(
        async (tx) => {
          const locked = await tx.$queryRaw<Array<{ locked: boolean }>>`SELECT pg_try_advisory_xact_lock(hashtext(${`yegamo:worker:${job.name}`})) AS locked`;
          if (locked[0]?.locked !== true) return false;
          await job.run();
          return true;
        },
        { maxWait: 5_000, timeout: 120_000 },
      );
    } catch (error) {
      this.logger.error(`Worker ${job.name} failed: ${error instanceof Error ? error.message : String(error)}`);
      return false;
    } finally {
      this.running.delete(job.name);
    }
  }

  private interval(key: string, fallback: number): number {
    const parsed = Number.parseInt(this.config.get<string>(key, '') ?? '', 10);
    return Number.isInteger(parsed) && parsed >= 1000 ? parsed : fallback;
  }
}
