import { Injectable } from '@nestjs/common';

import { PrismaService } from '../database/prisma.service';
import { IdempotencyStore, StoredOperation } from './idempotency.ports';

@Injectable()
export class PrismaIdempotencyStore implements IdempotencyStore {
  constructor(private readonly prisma: PrismaService) {}

  async get(principalId: string, key: string): Promise<StoredOperation | null> {
    const record = await this.prisma.idempotencyOperation.findUnique({
      where: { principalId_operationKey: { principalId, operationKey: key } },
    });
    if (record === null || record.expiresAt.getTime() <= Date.now()) return null;
    return {
      principalId: record.principalId,
      key: record.operationKey,
      requestHash: record.requestHash,
      responseStatus: record.responseStatus,
      responseBody: record.responseBody,
      createdAt: record.createdAt,
      expiresAt: record.expiresAt,
    };
  }

  async put(operation: StoredOperation): Promise<void> {
    await this.prisma.idempotencyOperation.create({
      data: {
        principalId: operation.principalId,
        operationKey: operation.key,
        requestHash: operation.requestHash,
        responseStatus: operation.responseStatus,
        responseBody: operation.responseBody as object,
        createdAt: operation.createdAt,
        expiresAt: operation.expiresAt,
      },
    });
  }
}
