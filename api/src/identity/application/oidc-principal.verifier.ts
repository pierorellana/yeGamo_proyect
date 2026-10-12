import { createPublicKey, createVerify, type JsonWebKey } from 'node:crypto';
import { UnauthorizedException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { ExternalPrincipal, PrincipalVerifier } from '../domain/identity.ports';

type OidcJwk = JsonWebKey & { kid?: string };
interface JsonWebKeySet { keys?: readonly OidcJwk[] }
interface JwtHeader { alg?: unknown; kid?: unknown }
interface JwtClaims { iss?: unknown; sub?: unknown; aud?: unknown; exp?: unknown; nbf?: unknown; email?: unknown; name?: unknown; scope?: unknown }

@Injectable()
export class OidcPrincipalVerifier implements PrincipalVerifier {
  private cachedKeys: { expiresAt: number; keys: readonly OidcJwk[] } | null = null;

  constructor(private readonly config: ConfigService) {}

  async verify(token: string | undefined): Promise<ExternalPrincipal> {
    const issuer = this.config.get<string>('oidcIssuerUrl');
    const audience = this.config.get<string>('oidcAudience');
    const jwksUrl = this.config.get<string>('oidcJwksUrl');
    if (issuer === undefined || audience === undefined || jwksUrl === undefined) {
      throw this.unauthorized('OIDC no está configurado para este ambiente.', 'UNAVAILABLE');
    }
    if (token === undefined) throw this.unauthorized('Token ausente.', 'INVALID_TOKEN');

    const parsed = parseJwt(token);
    if (parsed === null || parsed.header.alg !== 'RS256' || typeof parsed.header.kid !== 'string') {
      throw this.unauthorized('El token JWT no tiene un formato admitido.', 'INVALID_TOKEN');
    }
    const keys = await this.getKeys(jwksUrl);
    const jwk = keys.find((key) => key.kid === parsed.header.kid && key.kty === 'RSA');
    if (jwk === undefined) throw this.unauthorized('No se encontró la clave OIDC del token.', 'INVALID_TOKEN');

    let validSignature = false;
    try {
      const publicKey = createPublicKey({ key: jwk, format: 'jwk' });
      const verifier = createVerify('RSA-SHA256');
      verifier.update(parsed.signingInput);
      verifier.end();
      validSignature = verifier.verify(publicKey, parsed.signature);
    } catch {
      validSignature = false;
    }
    if (!validSignature) throw this.unauthorized('La firma del token no es válida.', 'INVALID_TOKEN');

    const claims = parsed.claims;
    const now = Math.floor(Date.now() / 1000);
    const tokenAudience = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
    if (
      claims.iss !== issuer ||
      !tokenAudience.includes(audience) ||
      typeof claims.sub !== 'string' ||
      typeof claims.exp !== 'number' ||
      claims.exp <= now ||
      (typeof claims.nbf === 'number' && claims.nbf > now)
    ) {
      throw this.unauthorized('Los claims del token no son válidos.', 'INVALID_TOKEN');
    }

    return {
      issuer,
      subject: claims.sub,
      email: typeof claims.email === 'string' ? claims.email : null,
      displayName: typeof claims.name === 'string' ? claims.name : null,
      scopes: typeof claims.scope === 'string' ? claims.scope.split(' ').filter(Boolean) : [],
    };
  }

  private async getKeys(jwksUrl: string): Promise<readonly OidcJwk[]> {
    if (this.cachedKeys !== null && this.cachedKeys.expiresAt > Date.now()) return this.cachedKeys.keys;
    const response = await fetch(jwksUrl, { signal: AbortSignal.timeout(3000) });
    if (!response.ok) throw this.unauthorized('No se pudo consultar el JWKS OIDC.', 'IDENTITY_UNAVAILABLE');
    const body = (await response.json()) as JsonWebKeySet;
    if (!Array.isArray(body.keys)) throw this.unauthorized('El JWKS OIDC no es válido.', 'IDENTITY_UNAVAILABLE');
    this.cachedKeys = { keys: body.keys, expiresAt: Date.now() + 5 * 60 * 1000 };
    return body.keys;
  }

  private unauthorized(message: string, reason: string): UnauthorizedException {
    return new UnauthorizedException({ code: 'UNAUTHORIZED', message, details: { identity: reason } });
  }
}

function parseJwt(token: string): { header: JwtHeader; claims: JwtClaims; signingInput: string; signature: Buffer } | null {
  const parts = token.split('.');
  if (parts.length !== 3 || parts[0] === undefined || parts[1] === undefined || parts[2] === undefined) return null;
  try {
    const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8')) as JwtHeader;
    const claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8')) as JwtClaims;
    return {
      header,
      claims,
      signingInput: `${parts[0]}.${parts[1]}`,
      signature: Buffer.from(parts[2], 'base64url'),
    };
  } catch {
    return null;
  }
}
