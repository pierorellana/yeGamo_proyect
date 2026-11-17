import { CanActivate, ExecutionContext, HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Request, Response } from 'express';

interface Bucket { count: number; resetAt: number }

/**
 * Fixed-window rate limiter keyed by client IP (single-instance, in memory — enough
 * for the modular monolith; move to a shared store if the API is scaled out).
 * Planning is the costliest public route and gets a stricter budget. Health checks
 * are exempt so orchestrators are never throttled.
 */
@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly buckets = new Map<string, Bucket>();

  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const http = context.switchToHttp();
    const request = http.getRequest<Request>();
    const response = http.getResponse<Response>();
    const limit = this.limitFor(request);
    if (limit === null) return true;

    const now = Date.now();
    const key = `${request.ip ?? 'unknown'}:${limit.scope}`;
    let bucket = this.buckets.get(key);
    if (bucket === undefined || bucket.resetAt <= now) {
      bucket = { count: 0, resetAt: now + limit.windowMs };
      this.buckets.set(key, bucket);
      if (this.buckets.size > 10_000) this.evict(now);
    }
    bucket.count += 1;
    response.setHeader('X-RateLimit-Limit', String(limit.max));
    response.setHeader('X-RateLimit-Remaining', String(Math.max(0, limit.max - bucket.count)));
    if (bucket.count > limit.max) {
      const retryAfter = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
      response.setHeader('Retry-After', String(retryAfter));
      throw new HttpException(
        { code: 'RATE_LIMITED', message: 'Se superó el límite de solicitudes. Intenta de nuevo en un momento.', details: { retryAfterSeconds: retryAfter } },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    return true;
  }

  private limitFor(request: Request): { scope: string; max: number; windowMs: number } | null {
    const max = this.int('RATE_LIMIT_PER_MINUTE', 120);
    if (max === 0) return null; // 0 disables the limiter.
    const path = request.path;
    if (path.endsWith('/health') || path.endsWith('/health/ready')) return null;
    if (request.method === 'POST' && path.endsWith('/journeys/plan')) {
      return { scope: 'plan', max: this.int('RATE_LIMIT_PLAN_PER_MINUTE', 20), windowMs: 60_000 };
    }
    return { scope: 'api', max, windowMs: 60_000 };
  }

  private int(key: string, fallback: number): number {
    const parsed = Number.parseInt(this.config.get<string>(key, '') ?? '', 10);
    return Number.isInteger(parsed) && parsed >= 0 ? parsed : fallback;
  }

  private evict(now: number): void {
    for (const [key, bucket] of this.buckets) if (bucket.resetAt <= now) this.buckets.delete(key);
  }
}
