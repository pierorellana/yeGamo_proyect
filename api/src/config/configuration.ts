export interface AppConfiguration {
  nodeEnv: string;
  port: number;
  appVersion: string;
  databaseUrl?: string;
  oidcIssuerUrl?: string;
  oidcAudience?: string;
}

export function configuration(): AppConfiguration {
  const port = Number.parseInt(process.env.PORT ?? '3000', 10);

  return {
    nodeEnv: process.env.NODE_ENV ?? 'development',
    port: Number.isFinite(port) ? port : 3000,
    appVersion: process.env.APP_VERSION ?? '1.1.1',
    ...(process.env.DATABASE_URL === undefined
      ? {}
      : { databaseUrl: process.env.DATABASE_URL }),
    ...(process.env.OIDC_ISSUER_URL === undefined
      ? {}
      : { oidcIssuerUrl: process.env.OIDC_ISSUER_URL }),
    ...(process.env.OIDC_AUDIENCE === undefined
      ? {}
      : { oidcAudience: process.env.OIDC_AUDIENCE }),
  };
}
