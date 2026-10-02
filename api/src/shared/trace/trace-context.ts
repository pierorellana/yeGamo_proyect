import { randomUUID } from 'node:crypto';
import type { Request } from 'express';

export const TRACE_ID_HEADER = 'X-Trace-Id';
export const TRACE_ID_REQUEST_PROPERTY = 'traceId';

export type TraceableRequest = Request & {
  traceId?: string;
};

export function createTraceId(): string {
  return randomUUID();
}

export function resolveTraceId(value: string | string[] | undefined): string {
  const candidate = Array.isArray(value) ? value[0] : value;

  if (candidate !== undefined && /^[A-Za-z0-9._:-]{1,128}$/.test(candidate)) {
    return candidate;
  }

  return createTraceId();
}
