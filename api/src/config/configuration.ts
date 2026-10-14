export interface AppConfiguration {
  nodeEnv: string;
  port: number;
  appVersion: string;
  overpassEnabled: boolean;
  overpassBaseUrl: string;
  overpassBaseUrls: string[];
  overpassTimeoutMs: number;
  overpassCacheTtlMs: number;
  databaseUrl?: string;
  oidcIssuerUrl?: string;
  oidcAudience?: string;
  oidcJwksUrl?: string;
}

export function configuration(): AppConfiguration {
  const port = Number.parseInt(process.env.PORT ?? '3000', 10);

  return {
    nodeEnv: process.env.NODE_ENV ?? 'development',
    port: Number.isFinite(port) ? port : 3000,
    appVersion: process.env.APP_VERSION ?? '1.1.1',
    overpassEnabled: process.env.OVERPASS_ENABLED === 'true',
    overpassBaseUrl:
      process.env.OVERPASS_BASE_URL ??
      'https://overpass-api.de/api/interpreter',
    overpassBaseUrls: parseList(
      process.env.OVERPASS_BASE_URLS ?? process.env.OVERPASS_BASE_URL,
      'https://overpass-api.de/api/interpreter',
    ),
    overpassTimeoutMs: parsePositiveInt(
      process.env.OVERPASS_TIMEOUT_MS,
      20000,
    ),
    overpassCacheTtlMs: parsePositiveInt(
      process.env.OVERPASS_CACHE_TTL_MS,
      900000,
    ),
    ...(process.env.DATABASE_URL === undefined
      ? {}
      : { databaseUrl: process.env.DATABASE_URL }),
    ...(process.env.OIDC_ISSUER_URL === undefined
      ? {}
      : { oidcIssuerUrl: process.env.OIDC_ISSUER_URL }),
    ...(process.env.OIDC_AUDIENCE === undefined
      ? {}
      : { oidcAudience: process.env.OIDC_AUDIENCE }),
    ...(process.env.OIDC_JWKS_URL === undefined
      ? {}
      : { oidcJwksUrl: process.env.OIDC_JWKS_URL }),
  };
}

function parsePositiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function parseList(value: string | undefined, fallback: string): string[] {
  const values = (value ?? fallback)
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
  return values.length > 0 ? values : [fallback];
}
