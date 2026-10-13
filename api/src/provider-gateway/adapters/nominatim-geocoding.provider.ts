import { ProviderGatewayError } from '../domain/provider.errors';
import {
  GeocodingProvider,
  ProviderResult,
} from '../domain/provider.ports';
import type { GeoPoint } from '../domain/provider.types';

const PROVIDER_KEY = 'openstreetmap-nominatim';
const DEFAULT_BASE_URL = 'https://nominatim.openstreetmap.org';
const DEFAULT_USER_AGENT = 'yeGamo-local-dev/1.0';
const MIN_REQUEST_INTERVAL_MS = 1000;
const CACHE_TTL_MS = 30_000;

interface RawNominatimPlace {
  place_id: number | string;
  display_name: string;
  lat: string | number;
  lon: string | number;
}

interface RawPlace {
  id: string;
  label: string;
  location: GeoPoint;
}

interface NominatimOptions {
  baseUrl?: string;
  userAgent?: string;
  fetcher?: typeof fetch;
  now?: () => Date;
}

interface CacheEntry {
  expiresAt: number;
  value: unknown;
}

export class NominatimGeocodingProvider implements GeocodingProvider {
  readonly providerKey = PROVIDER_KEY;
  readonly isDemo = false;

  private readonly baseUrl: string;
  private readonly userAgent: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly cache = new Map<string, CacheEntry>();
  private lastRequestAt = 0;

  constructor(options: NominatimOptions = {}) {
    this.baseUrl = (options.baseUrl ?? DEFAULT_BASE_URL).replace(/\/$/, '');
    this.userAgent = options.userAgent ?? DEFAULT_USER_AGENT;
    this.fetcher = options.fetcher ?? globalThis.fetch.bind(globalThis);
    this.now = options.now ?? (() => new Date());
  }

  async search(
    query: string,
    near?: GeoPoint,
  ): Promise<ProviderResult<RawPlace[]>> {
    const normalized = query.trim();
    const cacheKey = `search:${normalized.toLowerCase()}:${near?.lat ?? ''}:${near?.lon ?? ''}`;
    const cached = this.fromCache<RawPlace[]>(cacheKey);
    if (cached !== undefined) return this.result(cached);

    const params = new URLSearchParams({
      q: normalized,
      format: 'jsonv2',
      limit: '8',
      addressdetails: '0',
      'accept-language': 'es',
      countrycodes: 'ec',
    });
    if (near !== undefined) {
      params.set('viewbox', viewboxAround(near));
    }
    const raw = await this.request(`/search?${params.toString()}`);
    if (!Array.isArray(raw)) throw invalidResponse();

    const places = raw.map((value) => toRawPlace(value)).filter(isRawPlace);
    if (places.length !== raw.length) throw invalidResponse();
    this.toCache(cacheKey, places);
    return this.result(places);
  }

  async reverse(point: GeoPoint): Promise<ProviderResult<RawPlace | null>> {
    const cacheKey = `reverse:${point.lat}:${point.lon}`;
    const cached = this.fromCache<RawPlace | null>(cacheKey);
    if (cached !== undefined) return this.result(cached);

    const params = new URLSearchParams({
      lat: point.lat.toString(),
      lon: point.lon.toString(),
      format: 'jsonv2',
      zoom: '18',
      addressdetails: '0',
      'accept-language': 'es',
    });
    const raw = await this.request(`/reverse?${params.toString()}`);
    const place = raw === null ? null : toRawPlace(raw);
    this.toCache(cacheKey, place);
    return this.result(place);
  }

  private async request(path: string): Promise<unknown> {
    const now = this.now().getTime();
    if (now - this.lastRequestAt < MIN_REQUEST_INTERVAL_MS) {
      throw new ProviderGatewayError(
        'PROVIDER_UNAVAILABLE',
        'Nominatim está limitado a una solicitud por segundo',
        true,
        { capability: 'geocoding', providerKey: PROVIDER_KEY },
      );
    }
    this.lastRequestAt = now;

    let response: Response;
    try {
      response = await this.fetcher(`${this.baseUrl}${path}`, {
        headers: {
          Accept: 'application/json',
          'User-Agent': this.userAgent,
        },
      });
    } catch {
      throw new ProviderGatewayError(
        'PROVIDER_UNAVAILABLE',
        'Nominatim no está disponible',
        true,
        { capability: 'geocoding', providerKey: PROVIDER_KEY },
      );
    }

    if (!response.ok) {
      throw new ProviderGatewayError(
        response.status === 429 ? 'PROVIDER_UNAVAILABLE' : 'PROVIDER_INVALID_RESPONSE',
        `Nominatim respondió con ${response.status}`,
        response.status === 429 || response.status >= 500,
        { capability: 'geocoding', providerKey: PROVIDER_KEY },
      );
    }

    try {
      return await response.json();
    } catch {
      throw invalidResponse();
    }
  }

  private result<T>(data: T): ProviderResult<T> {
    return {
      providerKey: PROVIDER_KEY,
      isDemo: false,
      sourceAuthorized: true,
      observedAt: this.now().toISOString(),
      data,
    };
  }

  private fromCache<T>(key: string): T | undefined {
    const entry = this.cache.get(key);
    if (entry === undefined) return undefined;
    if (entry.expiresAt <= this.now().getTime()) {
      this.cache.delete(key);
      return undefined;
    }
    return entry.value as T;
  }

  private toCache(key: string, value: unknown): void {
    this.cache.set(key, {
      expiresAt: this.now().getTime() + CACHE_TTL_MS,
      value,
    });
  }
}

function toRawPlace(value: unknown): RawPlace | null {
  if (typeof value !== 'object' || value === null) return null;
  const candidate = value as Partial<RawNominatimPlace>;
  const lat = numberValue(candidate.lat);
  const lon = numberValue(candidate.lon);
  if (
    (typeof candidate.place_id !== 'number' && typeof candidate.place_id !== 'string') ||
    typeof candidate.display_name !== 'string' ||
    candidate.display_name.trim().length === 0 ||
    lat === null ||
    lon === null ||
    lat < -90 ||
    lat > 90 ||
    lon < -180 ||
    lon > 180
  ) {
    return null;
  }

  return {
    id: `nominatim:${candidate.place_id}`,
    label: candidate.display_name,
    location: { lat, lon },
  };
}

function numberValue(value: unknown): number | null {
  const number = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(number) ? number : null;
}

function isRawPlace(value: RawPlace | null): value is RawPlace {
  return value !== null;
}

function invalidResponse(): ProviderGatewayError {
  return new ProviderGatewayError(
    'PROVIDER_INVALID_RESPONSE',
    `Provider ${PROVIDER_KEY} returned an invalid place payload`,
    false,
    { capability: 'geocoding', providerKey: PROVIDER_KEY },
  );
}

function viewboxAround(point: GeoPoint): string {
  const radius = 0.5;
  const lonMin = Math.max(-180, point.lon - radius);
  const latMax = Math.min(90, point.lat + radius);
  const lonMax = Math.min(180, point.lon + radius);
  const latMin = Math.max(-90, point.lat - radius);
  return `${lonMin},${latMax},${lonMax},${latMin}`;
}
