import { Inject, Injectable } from '@nestjs/common';

import { ProviderGatewayError } from '../domain/provider.errors';
import {
  ProviderResult,
  TransitStopCandidate,
  TransitStopDiscoveryInput,
  TransitStopDiscoveryProvider,
} from '../domain/provider.ports';

export const TRANSIT_STOP_DISCOVERY_PROVIDERS = Symbol(
  'TRANSIT_STOP_DISCOVERY_PROVIDERS',
);

export interface TransitStopDiscoveryResult {
  providerKey: string;
  sourceAuthorized: boolean;
  observedAt: string | null;
  stops: TransitStopCandidate[];
}

export interface TransitStopDiscoveryPort {
  discover(
    input: TransitStopDiscoveryInput,
    timeoutMs?: number,
  ): Promise<TransitStopDiscoveryResult>;
}

@Injectable()
export class TransitStopDiscoveryGatewayService
  implements TransitStopDiscoveryPort
{
  constructor(
    @Inject(TRANSIT_STOP_DISCOVERY_PROVIDERS)
    private readonly providers: TransitStopDiscoveryProvider[],
  ) {}

  async discover(
    input: TransitStopDiscoveryInput,
    timeoutMs = 10000,
  ): Promise<TransitStopDiscoveryResult> {
    if (this.providers.length === 0) {
      throw unavailable('No transit stop discovery provider is configured');
    }

    let lastError: ProviderGatewayError | undefined;
    let emptyResult: TransitStopDiscoveryResult | undefined;
    for (const provider of this.providers) {
      try {
        const result = await withTimeout(
          provider.discoverStops(input),
          timeoutMs,
        );
        if (!isProviderResult(result) || !isCandidateList(result.data)) {
          throw new ProviderGatewayError(
            'PROVIDER_INVALID_RESPONSE',
            'Provider ' + provider.providerKey + ' returned an invalid stop payload',
            false,
            { capability: 'transit', providerKey: provider.providerKey },
          );
        }

        const resultValue = {
          providerKey: result.providerKey,
          sourceAuthorized: result.sourceAuthorized === true,
          observedAt: result.observedAt,
          stops: result.data,
        };
        if (resultValue.stops.length > 0) return resultValue;
        emptyResult ??= resultValue;
      } catch (error) {
        lastError =
          error instanceof ProviderGatewayError
            ? error.forCapability('transit', provider.providerKey)
            : unavailable(
                'Provider ' + provider.providerKey + ' failed',
                provider.providerKey,
              );
      }
    }

    if (emptyResult !== undefined) return emptyResult;
    throw (
      lastError ??
      unavailable('No transit stop discovery provider returned data')
    );
  }
}

function isProviderResult(
  value: unknown,
): value is ProviderResult<unknown> {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Partial<ProviderResult<unknown>>;
  return (
    typeof candidate.providerKey === 'string' &&
    typeof candidate.isDemo === 'boolean' &&
    (candidate.sourceAuthorized === undefined ||
      typeof candidate.sourceAuthorized === 'boolean') &&
    (candidate.observedAt === null || typeof candidate.observedAt === 'string') &&
    'data' in candidate
  );
}

function isCandidateList(value: unknown): value is TransitStopCandidate[] {
  return (
    Array.isArray(value) &&
    value.every((candidate) => {
      if (typeof candidate !== 'object' || candidate === null) return false;
      const value = candidate as Partial<TransitStopCandidate>;
      return (
        typeof value.externalId === 'string' &&
        value.externalId.length > 0 &&
        typeof value.name === 'string' &&
        value.name.length > 0 &&
        isGeoPoint(value.location)
      );
    })
  );
}

function isGeoPoint(value: unknown): value is { lat: number; lon: number } {
  if (typeof value !== 'object' || value === null) return false;
  const point = value as { lat?: unknown; lon?: unknown };
  return (
    typeof point.lat === 'number' &&
    Number.isFinite(point.lat) &&
    point.lat >= -90 &&
    point.lat <= 90 &&
    typeof point.lon === 'number' &&
    Number.isFinite(point.lon) &&
    point.lon >= -180 &&
    point.lon <= 180
  );
}

function unavailable(message: string, providerKey?: string): ProviderGatewayError {
  return new ProviderGatewayError(
    'PROVIDER_UNAVAILABLE',
    message,
    true,
    {
      capability: 'transit',
      ...(providerKey === undefined ? {} : { providerKey }),
    },
  );
}

async function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () =>
        reject(
          new ProviderGatewayError(
            'PROVIDER_TIMEOUT',
            'Transit stop discovery timed out',
            true,
            { capability: 'transit' },
          ),
        ),
      Math.max(1, timeoutMs),
    );
  });

  try {
    return await Promise.race([promise, timeout]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}
