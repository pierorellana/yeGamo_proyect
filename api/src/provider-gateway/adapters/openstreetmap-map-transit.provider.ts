import { ProviderGatewayError } from '../domain/provider.errors';
import {
  ProviderResult,
  TransitStopCandidate,
  TransitStopDiscoveryInput,
  TransitStopDiscoveryProvider,
} from '../domain/provider.ports';

const PROVIDER_KEY = 'openstreetmap-map';
const DEFAULT_BASE_URL = 'https://api.openstreetmap.org/api/0.6/map';
const DEFAULT_USER_AGENT = 'yeGamo-local-dev/1.0';
const DEFAULT_TIMEOUT_MS = 20_000;
const MAX_RADIUS_M = 1_000;

interface Bounds {
  south: number;
  west: number;
  north: number;
  east: number;
}

export interface OpenStreetMapMapTransitProviderOptions {
  baseUrl?: string;
  userAgent?: string;
  timeoutMs?: number;
  fetcher?: typeof fetch;
  now?: () => Date;
}

/**
 * Low-volume development fallback for periods when public Overpass instances
 * are saturated. The OSM map API is limited to the small request bbox and is
 * kept behind the gateway; it is not a production tile/transport feed.
 */
export class OpenStreetMapMapTransitProvider
  implements TransitStopDiscoveryProvider
{
  readonly providerKey = PROVIDER_KEY;
  readonly isDemo = false;

  private readonly baseUrl: string;
  private readonly userAgent: string;
  private readonly timeoutMs: number;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;

  constructor(options: OpenStreetMapMapTransitProviderOptions = {}) {
    this.baseUrl = (options.baseUrl ?? DEFAULT_BASE_URL).replace(/\/$/, '');
    this.userAgent = options.userAgent ?? DEFAULT_USER_AGENT;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    this.fetcher = options.fetcher ?? globalThis.fetch.bind(globalThis);
    this.now = options.now ?? (() => new Date());
  }

  async discoverStops(
    input: TransitStopDiscoveryInput,
  ): Promise<ProviderResult<TransitStopCandidate[]>> {
    const bounds = boundsFor(input);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const url = new URL(this.baseUrl);
      url.searchParams.set(
        'bbox',
        [bounds.west, bounds.south, bounds.east, bounds.north].join(','),
      );
      const response = await this.fetcher(url.toString(), {
        headers: {
          Accept: 'application/xml',
          'User-Agent': this.userAgent,
        },
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new ProviderGatewayError(
          response.status >= 500 || response.status === 429
            ? 'PROVIDER_UNAVAILABLE'
            : 'PROVIDER_INVALID_RESPONSE',
          'OpenStreetMap respondió con ' + response.status,
          response.status >= 500 || response.status === 429,
          { capability: 'transit', providerKey: PROVIDER_KEY },
        );
      }
      const xml = await response.text();
      return {
        providerKey: PROVIDER_KEY,
        isDemo: false,
        sourceAuthorized: true,
        observedAt: this.now().toISOString(),
        data: parseStops(xml),
      };
    } catch (error) {
      if (error instanceof ProviderGatewayError) throw error;
      throw new ProviderGatewayError(
        'PROVIDER_UNAVAILABLE',
        'OpenStreetMap no está disponible',
        true,
        { capability: 'transit', providerKey: PROVIDER_KEY },
      );
    } finally {
      clearTimeout(timer);
    }
  }
}

function boundsFor(input: TransitStopDiscoveryInput): Bounds {
  const radius = Math.max(50, Math.min(MAX_RADIUS_M, input.radiusM));
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

function parseStops(xml: string): TransitStopCandidate[] {
  if (!xml.includes('<osm')) throw invalidResponse();
  const nodePattern = /<node\b([^>]*?)(?:\/\s*>|>([\s\S]*?)<\/node>)/g;
  const candidates: TransitStopCandidate[] = [];
  const seen = new Set<string>();
  for (const match of xml.matchAll(nodePattern)) {
    const attributes = attributesFrom(match[1] ?? '');
    const id = attributes.id;
    const lat = number(attributes.lat);
    const lon = number(attributes.lon);
    if (
      id === null ||
      lat === null ||
      lat < -90 ||
      lat > 90 ||
      lon === null
    ) {
      continue;
    }
    const tags = tagsFrom(match[2] ?? '');
    if (!isTransitStop(tags)) continue;
    const externalId = 'node:' + id;
    if (seen.has(externalId)) continue;
    seen.add(externalId);
    candidates.push({
      externalId,
      name: tags.name ?? tags.local_ref ?? 'Parada sin nombre',
      location: { lat, lon },
    });
  }
  return candidates;
}

function attributesFrom(value: string): Record<string, string> {
  const attributes: Record<string, string> = {};
  const pattern = /([\w:.-]+)\s*=\s*"([^"]*)"/g;
  for (const match of value.matchAll(pattern)) {
    const key = match[1];
    if (key !== undefined) attributes[key] = decodeXml(match[2] ?? '');
  }
  return attributes;
}

function tagsFrom(value: string): Record<string, string> {
  const tags: Record<string, string> = {};
  const pattern = /<tag\b([^>]*?)\/\s*>/g;
  for (const match of value.matchAll(pattern)) {
    const attributes = attributesFrom(match[1] ?? '');
    const key = attributes.k;
    const tagValue = attributes.v;
    if (key !== undefined && tagValue !== undefined) tags[key] = tagValue;
  }
  return tags;
}

function isTransitStop(tags: Record<string, string>): boolean {
  return (
    tags.highway === 'bus_stop' ||
    tags.public_transport === 'platform' ||
    tags.public_transport === 'stop_position'
  );
}

function number(value: string | undefined): number | null {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= -180 && parsed <= 180
    ? parsed
    : null;
}

function decodeXml(value: string): string {
  return value
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');
}

function invalidResponse(): ProviderGatewayError {
  return new ProviderGatewayError(
    'PROVIDER_INVALID_RESPONSE',
    'OpenStreetMap devolvió una respuesta inválida',
    false,
    { capability: 'transit', providerKey: PROVIDER_KEY },
  );
}
