import { Inject, Injectable } from '@nestjs/common';

import { ProviderGatewayError } from '../domain/provider.errors';
import { GeocodingProvider, ProviderResult } from '../domain/provider.ports';
import { GeoPoint, Place } from '../domain/provider.types';

export const GEOCODING_PROVIDERS = Symbol('GEOCODING_PROVIDERS');

const DEFAULT_GEOCODING_TIMEOUT_MS = 2000;

@Injectable()
export class GeocodingGatewayService {
  constructor(
    @Inject(GEOCODING_PROVIDERS)
    private readonly providers: GeocodingProvider[],
  ) {}

  async search(
    query: string,
    near?: GeoPoint,
    timeoutMs = DEFAULT_GEOCODING_TIMEOUT_MS,
  ): Promise<Place[]> {
    if (this.providers.length === 0) {
      throw unavailable('No geocoding provider is configured');
    }

    let lastError: ProviderGatewayError | undefined;
    for (const provider of this.providers) {
      try {
        const result = await withTimeout(provider.search(query, near), timeoutMs);
        return mapPlaces(result, provider.providerKey);
      } catch (error) {
        lastError = normalizeError(error, provider.providerKey);
      }
    }

    throw lastError ?? unavailable('No geocoding provider returned places');
  }

  async reverse(
    point: GeoPoint,
    timeoutMs = DEFAULT_GEOCODING_TIMEOUT_MS,
  ): Promise<Place> {
    if (this.providers.length === 0) {
      throw unavailable('No geocoding provider is configured');
    }

    let lastError: ProviderGatewayError | undefined;
    for (const provider of this.providers) {
      try {
        const result = await withTimeout(provider.reverse(point), timeoutMs);
        const places = mapPlaces(result, provider.providerKey);
        const place = places[0];
        if (place === undefined) {
          throw new ProviderGatewayError(
            'PROVIDER_UNAVAILABLE',
            `Provider ${provider.providerKey} returned no place`,
            true,
            { capability: 'geocoding', providerKey: provider.providerKey },
          );
        }
        return place;
      } catch (error) {
        lastError = normalizeError(error, provider.providerKey);
      }
    }

    throw lastError ?? unavailable('No geocoding provider returned a place');
  }
}

function mapPlaces(result: ProviderResult<unknown>, providerKey: string): Place[] {
  if (!isProviderResult(result)) {
    throw invalidResponse(providerKey);
  }

  const values = Array.isArray(result.data) ? result.data : [result.data];
  if (values.length === 1 && values[0] === null) return [];

  return values.map((value) => {
    if (!isRawPlace(value)) {
      throw invalidResponse(providerKey);
    }

    return {
      id: value.id,
      label: value.label,
      location: {
        lat: value.location.lat,
        lon: value.location.lon,
      },
      source:
        !result.isDemo && result.sourceAuthorized === true
          ? result.providerKey
          : null,
    };
  });
}

function isProviderResult(value: unknown): value is ProviderResult<unknown> {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Partial<ProviderResult<unknown>>;
  return (
    typeof candidate.providerKey === 'string' &&
    typeof candidate.isDemo === 'boolean' &&
    (candidate.sourceAuthorized === undefined || typeof candidate.sourceAuthorized === 'boolean') &&
    (candidate.observedAt === null || typeof candidate.observedAt === 'string') &&
    'data' in candidate
  );
}

function isRawPlace(value: unknown): value is {
  id: string;
  label: string;
  location: GeoPoint;
  source?: string | null;
} {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Partial<{
    id: unknown;
    label: unknown;
    location: unknown;
    source?: unknown;
  }>;
  const location = candidate.location as Partial<GeoPoint> | null | undefined;
  return (
    typeof candidate.id === 'string' &&
    candidate.id.length > 0 &&
    typeof candidate.label === 'string' &&
    candidate.label.length > 0 &&
    typeof location === 'object' &&
    location !== null &&
    typeof location.lat === 'number' &&
    Number.isFinite(location.lat) &&
    location.lat >= -90 &&
    location.lat <= 90 &&
    typeof location.lon === 'number' &&
    Number.isFinite(location.lon) &&
    location.lon >= -180 &&
    location.lon <= 180 &&
    (candidate.source === undefined || candidate.source === null || typeof candidate.source === 'string')
  );
}

function unavailable(message: string): ProviderGatewayError {
  return new ProviderGatewayError('PROVIDER_UNAVAILABLE', message, true, {
    capability: 'geocoding',
  });
}

function invalidResponse(providerKey: string): ProviderGatewayError {
  return new ProviderGatewayError(
    'PROVIDER_INVALID_RESPONSE',
    `Provider ${providerKey} returned an invalid place payload`,
    false,
    { capability: 'geocoding', providerKey },
  );
}

function normalizeError(error: unknown, providerKey: string): ProviderGatewayError {
  if (error instanceof ProviderGatewayError) {
    return error.forCapability('geocoding', providerKey);
  }

  return new ProviderGatewayError(
    'PROVIDER_UNAVAILABLE',
    `Provider ${providerKey} failed`,
    true,
    { capability: 'geocoding', providerKey },
  );
}

async function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () =>
        reject(
          new ProviderGatewayError('PROVIDER_TIMEOUT', 'Geocoding provider timed out', true, {
            capability: 'geocoding',
          }),
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
