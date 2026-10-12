export interface StoredOperation {
  readonly principalId: string;
  readonly key: string;
  readonly requestHash: string;
  readonly responseStatus: number;
  readonly responseBody: unknown;
  readonly createdAt: Date;
  readonly expiresAt: Date;
}

export interface IdempotencyStore {
  get(principalId: string, key: string): Promise<StoredOperation | null>;
  put(operation: StoredOperation): Promise<void>;
}

export const IDEMPOTENCY_STORE = Symbol('IDEMPOTENCY_STORE');
