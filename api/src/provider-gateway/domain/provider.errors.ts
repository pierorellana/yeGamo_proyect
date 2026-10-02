export type ProviderErrorCode =
  | 'PROVIDER_TIMEOUT'
  | 'PROVIDER_UNAVAILABLE'
  | 'PROVIDER_INVALID_RESPONSE';

export class ProviderGatewayError extends Error {
  constructor(
    public readonly code: ProviderErrorCode,
    message: string,
    public readonly retryable = true,
  ) {
    super(message);
    this.name = 'ProviderGatewayError';
  }
}
