import { ConflictException, Inject, Injectable, UnprocessableEntityException } from '@nestjs/common';
import { createHash } from 'node:crypto';

import { IDEMPOTENCY_STORE, IdempotencyStore, StoredOperation } from './idempotency.ports';

@Injectable()
export class IdempotencyService {
  constructor(@Inject(IDEMPOTENCY_STORE) private readonly store: IdempotencyStore) {}

  async execute<T>(
    principalId: string,
    key: string | undefined,
    input: unknown,
    operation: () => Promise<T>,
    responseStatus = 200,
  ): Promise<T> {
    const normalizedKey = validateIdempotencyKey(key);
    const requestHash = hashRequest(input);
    const previous = await this.store.get(principalId, normalizedKey);

    if (previous !== null) {
      if (previous.requestHash !== requestHash) {
        throw new ConflictException({
          code: 'IDEMPOTENCY_KEY_REUSED',
          message: 'La clave de idempotencia ya fue usada con otra solicitud.',
          details: { idempotencyKey: normalizedKey },
        });
      }
      return previous.responseBody as T;
    }

    const result = await operation();
    const createdAt = new Date();
    await this.store.put({
      principalId,
      key: normalizedKey,
      requestHash,
      responseStatus,
      responseBody: result,
      createdAt,
      expiresAt: new Date(createdAt.getTime() + 24 * 60 * 60 * 1000),
    });
    return result;
  }
}

export function validateIdempotencyKey(key: string | undefined): string {
  if (key === undefined || !/^[\x21-\x7e]{8,128}$/.test(key)) {
    throw new UnprocessableEntityException({
      code: 'VALIDATION_ERROR',
      message: 'Idempotency-Key debe tener entre 8 y 128 caracteres imprimibles.',
      details: { field: 'Idempotency-Key' },
    });
  }
  return key;
}

export function hashRequest(value: unknown): string {
  return createHash('sha256').update(stableJson(value)).digest('hex');
}

function stableJson(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  const record = value as Record<string, unknown>;
  return `{${Object.keys(record)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${stableJson(record[key])}`)
    .join(',')}}`;
}

export class InMemoryIdempotencyStore implements IdempotencyStore {
  private readonly records = new Map<string, StoredOperation>();

  async get(principalId: string, key: string): Promise<StoredOperation | null> {
    const record = this.records.get(`${principalId}:${key}`);
    if (record === undefined) return null;
    if (record.expiresAt.getTime() <= Date.now()) {
      this.records.delete(`${principalId}:${key}`);
      return null;
    }
    return record;
  }

  async put(operation: StoredOperation): Promise<void> {
    this.records.set(`${operation.principalId}:${operation.key}`, operation);
  }
}
