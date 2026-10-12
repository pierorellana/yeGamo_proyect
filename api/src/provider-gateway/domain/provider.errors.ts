import type { ProviderCapability } from './provider.types';

export type ProviderErrorCode =
  | 'PROVIDER_TIMEOUT'
  | 'PROVIDER_UNAVAILABLE'
  | 'PROVIDER_INVALID_RESPONSE';

export interface ProviderErrorContext {
  capability?: ProviderCapability;
  providerKey?: string;
  dataState?: 'UNAVAILABLE';
}

export class ProviderGatewayError extends Error {
  constructor(
    public readonly code: ProviderErrorCode,
    message: string,
    public readonly retryable = true,
    context: ProviderErrorContext = {},
  ) {
    super(message);
    this.name = 'ProviderGatewayError';
    this.capability = context.capability ?? 'transit';
    this.dataState = context.dataState ?? 'UNAVAILABLE';
    this.providerKey = context.providerKey ?? null;
  }

  readonly capability: ProviderCapability;
  readonly dataState: 'UNAVAILABLE';
  readonly providerKey: string | null;

  forCapability(capability: ProviderCapability, providerKey?: string): ProviderGatewayError {
    const context: ProviderErrorContext = {
      capability,
      dataState: this.dataState,
    };
    const resolvedProviderKey = providerKey ?? this.providerKey;
    if (resolvedProviderKey !== null) context.providerKey = resolvedProviderKey;

    return new ProviderGatewayError(this.code, this.message, this.retryable, context);
  }
}
