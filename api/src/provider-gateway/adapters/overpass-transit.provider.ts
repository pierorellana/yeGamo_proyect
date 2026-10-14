import { ProviderGatewayError } from '../domain/provider.errors';
import {
  ProviderResult,
  TransitStopCandidate,
  TransitStopDiscoveryInput,
  TransitStopDiscoveryProvider,
} from '../domain/provider.ports';

const PROVIDER_KEY = 'openstreetmap-overpass';
const DEFAULT_BASE_URL = 'https://overpass-api.de/api/interpreter';
const DEFAULT_USER_AGENT = 'yeGamo-local-dev/1.0';
const DEFAULT_CACHE_TTL_MS = 15 * 60 * 1000;
const DEFAULT_TIMEOUT_MS = 20_000;
const DEFAULT_MIN_REQUEST_INTERVAL_MS = 1_000;
const DEFAULT_RETRY_COUNT = 1;

interface RawOverpassElement {
  type: string;
  id: number | string;
  lat?: number;
  lon?: number;
  center?: { lat?: number; lon?: number };
  tags?: Record<string, unknown>;
}

interface OverpassResponse {
  elements?: unknown;
}

interface CacheEntry {
  expiresAt: number;
  value: TransitStopCandidate[];
}

export interface OpenStreetMapTransitProviderOptions {
  baseUrl?: string;
  baseUrls?: string[];
  userAgent?: string;
  timeoutMs?: number;
  cacheTtlMs?: number;
  minRequestIntervalMs?: number;
  retryCount?: number;
  fetcher?: typeof fetch;
  now?: () => Date;
}

export class OpenStreetMapTransitProvider
  implements TransitStopDiscoveryProvider
{
  readonly providerKey = PROVIDER_KEY;
  readonly isDemo = false;

  private readonly baseUrls: string[];
  private readonly userAgent: string;
  private readonly timeoutMs: number;
  private readonly cacheTtlMs: number;
  private readonly minRequestIntervalMs: number;
  private readonly retryCount: number;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly cache = new Map<string, CacheEntry>();
  private requestChain: Promise<void> = Promise.resolve();
  private lastRequestAt = 0;

  constructor(options: OpenStreetMapTransitProviderOptions = {}) {
    this.baseUrls = normalizeBaseUrls(
      options.baseUrls ?? [options.baseUrl ?? DEFAULT_BASE_URL],
    );
    this.userAgent = options.userAgent ?? DEFAULT_USER_AGENT;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    this.cacheTtlMs = options.cacheTtlMs ?? DEFAULT_CACHE_TTL_MS;
    this.minRequestIntervalMs =
      options.minRequestIntervalMs ?? DEFAULT_MIN_REQUEST_INTERVAL_MS;
    this.retryCount = Math.max(0, options.retryCount ?? DEFAULT_RETRY_COUNT);
    this.fetcher = options.fetcher ?? globalThis.fetch.bind(globalThis);
    this.now = options.now ?? (() => new Date());
  }

  async discoverStops(
    input: TransitStopDiscoveryInput,
  ): Promise<ProviderResult<TransitStopCandidate[]>> {
    const bounds = boundsFor(input);
    const cacheKey = cacheKeyFor(input, bounds);
    const cached = this.fromCache(cacheKey);
    if (cached !== undefined) return this.result(cached);

    const candidates = await this.serializedRequest(async () => {
      const insideCache = this.fromCache(cacheKey);
      if (insideCache !== undefined) return insideCache;

      const raw = await this.request(queryFor(bounds));
      const parsed = parseCandidates(raw);
      this.toCache(cacheKey, parsed);
      return parsed;
    });

    return this.result(candidates);
  }

  private async serializedRequest<T>(operation: () => Promise<T>): Promise<T> {
    let release!: () => void;
    const next = new Promise<void>((resolve) => {
      release = resolve;
    });
    const previous = this.requestChain;
    this.requestChain = previous.then(() => next);
    await previous;

    try {
      const elapsed = this.now().getTime() - this.lastRequestAt;
      const remaining = this.minRequestIntervalMs - elapsed;
      if (remaining > 0) await delay(remaining);
      this.lastRequestAt = this.now().getTime();
      return await operation();
    } finally {
      release();
    }
  }

  private async request(query: string): Promise<unknown> {
    let lastError: ProviderGatewayError | undefined;
    for (const baseUrl of this.baseUrls) {
      for (let attempt = 0; attempt <= this.retryCount; attempt++) {
        try {
          return await this.requestEndpoint(baseUrl, query);
        } catch (error) {
          const providerError = error instanceof ProviderGatewayError
            ? error
            : new ProviderGatewayError(
                'PROVIDER_UNAVAILABLE',
                'Overpass no está disponible',
                true,
                { capability: 'transit', providerKey: PROVIDER_KEY },
              );
          lastError = providerError;
          if (!providerError.retryable || attempt === this.retryCount) break;
          await delay(250 * (attempt + 1));
        }
      }
    }
    throw (
      lastError ??
      new ProviderGatewayError(
        'PROVIDER_UNAVAILABLE',
        'Overpass no está disponible',
        true,
        { capability: 'transit', providerKey: PROVIDER_KEY },
      )
    );
  }

  private async requestEndpoint(baseUrl: string, query: string): Promise<unknown> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const response = await this.fetcher(baseUrl, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': this.userAgent,
        },
        body: 'data=' + encodeURIComponent(query),
        signal: controller.signal,
      });

      if (!response.ok) {
        throw new ProviderGatewayError(
          response.status === 429 || response.status >= 500
            ? 'PROVIDER_UNAVAILABLE'
            : 'PROVIDER_INVALID_RESPONSE',
          'Overpass respondió con ' + response.status,
          response.status === 429 || response.status >= 500,
          { capability: 'transit', providerKey: PROVIDER_KEY },
        );
      }

      try {
        return await response.json();
      } catch {
        throw invalidResponse();
      }
    } catch (error) {
      if (error instanceof ProviderGatewayError) throw error;
      throw new ProviderGatewayError(
        'PROVIDER_UNAVAILABLE',
        'Overpass no está disponible',
        true,
        { capability: 'transit', providerKey: PROVIDER_KEY },
      );
    } finally {
      clearTimeout(timer);
    }
  }

  private result(data: TransitStopCandidate[]): ProviderResult<TransitStopCandidate[]> {
    return {
      providerKey: PROVIDER_KEY,
      isDemo: false,
      sourceAuthorized: true,
      observedAt: this.now().toISOString(),
      data,
    };
  }

  private fromCache(key: string): TransitStopCandidate[] | undefined {
    const entry = this.cache.get(key);
    if (entry === undefined) return undefined;
    if (entry.expiresAt <= this.now().getTime()) {
      this.cache.delete(key);
      return undefined;
    }
    return entry.value;
  }

  private toCache(key: string, value: TransitStopCandidate[]): void {
    this.cache.set(key, {
      expiresAt: this.now().getTime() + this.cacheTtlMs,
      value,
    });
  }
}

function queryFor(bounds: Bounds): string {
  const { south, west, north, east } = bounds;
  return [
    '[out:json][timeout:20];',
    '(',
    'nwr["highway"="bus_stop"](' +
      south +
      ',' +
      west +
      ',' +
      north +
      ',' +
      east +
      ');',
    'nwr["public_transport"="platform"](' +
      south +
      ',' +
      west +
      ',' +
      north +
      ',' +
      east +
      ');',
    'nwr["public_transport"="stop_position"](' +
      south +
      ',' +
      west +
      ',' +
      north +
      ',' +
      east +
      ');',
    ');',
    'out center tags;',
  ].join('\n');
}

interface Bounds {
  south: number;
  west: number;
  north: number;
  east: number;
}

function boundsFor(input: TransitStopDiscoveryInput): Bounds {
  const radius = Math.max(50, Math.min(3000, input.radiusM));
  const latitudeDelta = radius / 111_320;
  const longitudeDelta =
    radius / (111_320 * Math.max(Math.cos((input.lat * Math.PI) / 180), 0.1));

  return {
    south: Math.max(-90, input.lat - latitudeDelta),
    west: Math.max(-180, input.lon - longitudeDelta),
    north: Math.min(90, input.lat + latitudeDelta),
    east: Math.min(180, input.lon + longitudeDelta),
  };
}

function cacheKeyFor(input: TransitStopDiscoveryInput, bounds: Bounds): string {
  return [
    Math.round((bounds.south + bounds.north) * 500) / 1000,
    Math.round((bounds.west + bounds.east) * 500) / 1000,
    Math.round(input.radiusM),
  ].join(':');
}

function parseCandidates(payload: unknown): TransitStopCandidate[] {
  if (typeof payload !== 'object' || payload === null) {
    throw invalidResponse();
  }
  const elements = (payload as OverpassResponse).elements;
  if (!Array.isArray(elements)) throw invalidResponse();

  const seen = new Set<string>();
  const candidates: TransitStopCandidate[] = [];
  for (const element of elements) {
    const parsed = parseElement(element);
    if (parsed === null) continue;
    const externalId = parsed.externalId;
    if (seen.has(externalId)) continue;
    seen.add(externalId);
    const tags = parsed.tags;
    const name =
      stringTag(tags.name) ??
      stringTag(tags.local_ref) ??
      'Parada sin nombre';
    candidates.push({
      externalId,
      name,
      location: parsed.location,
    });
  }
  return candidates;
}

function parseElement(value: unknown): {
  externalId: string;
  location: { lat: number; lon: number };
  tags: Record<string, unknown>;
} | null {
  if (typeof value !== 'object' || value === null) return null;
  const candidate = value as Partial<RawOverpassElement>;
  if (
    typeof candidate.type !== 'string' ||
    (typeof candidate.id !== 'number' && typeof candidate.id !== 'string')
  ) {
    return null;
  }
  const lat = candidate.type === 'node'
    ? candidate.lat
    : candidate.center?.lat;
  const lon = candidate.type === 'node'
    ? candidate.lon
    : candidate.center?.lon;
  if (
    !Number.isFinite(Number(lat)) ||
    Number(lat) < -90 ||
    Number(lat) > 90 ||
    !Number.isFinite(Number(lon)) ||
    Number(lon) < -180 ||
    Number(lon) > 180
  ) {
    return null;
  }
  return {
    externalId: candidate.type + ':' + candidate.id,
    location: { lat: Number(lat), lon: Number(lon) },
    tags: candidate.tags ?? {},
  };
}

function normalizeBaseUrls(values: string[]): string[] {
  return values
    .map((value) => value.trim().replace(/\/$/, ''))
    .filter((value, index, all) => value.length > 0 && all.indexOf(value) === index);
}

function stringTag(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : null;
}

function invalidResponse(): ProviderGatewayError {
  return new ProviderGatewayError(
    'PROVIDER_INVALID_RESPONSE',
    'Overpass devolvió una respuesta inválida',
    false,
    { capability: 'transit', providerKey: PROVIDER_KEY },
  );
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
