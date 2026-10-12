import { ConfigService } from '@nestjs/config';
import { INestApplication } from '@nestjs/common';
import { Test as NestTest } from '@nestjs/testing';
import request from 'supertest';

import { IdentityService } from '../../src/identity/application/identity.service';
import { OidcPrincipalVerifier } from '../../src/identity/application/oidc-principal.verifier';
import type { ExternalPrincipal, UserRepository } from '../../src/identity/domain/identity.ports';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/app.bootstrap';

describe('identity boundary', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await NestTest.createTestingModule({ imports: [AppModule] }).compile();
    app = configureApp(moduleRef.createNestApplication());
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('protects identity routes with canonical 401 when no OIDC bearer is present', async () => {
    await request(app.getHttpServer())
      .get('/v1/me')
      .set('X-Trace-Id', 'identity-no-token')
      .expect(401)
      .expect('X-Trace-Id', 'identity-no-token')
      .expect(({ body }) => {
        expect(body).toMatchObject({ code: 'UNAUTHORIZED', traceId: 'identity-no-token' });
      });
  });

  it('rejects authentication when OIDC issuer, audience, or JWKS is not configured', async () => {
    const verifier = new OidcPrincipalVerifier(new ConfigService());
    await expect(verifier.verify('not-a-token')).rejects.toMatchObject({
      response: expect.objectContaining({
        code: 'UNAUTHORIZED',
        details: { identity: 'UNAVAILABLE' },
      }),
    });
  });

  it('does not create a local identity from a missing bearer token', async () => {
    const users = fakeUsers();
    const identity = new IdentityService(
      { verify: async (): Promise<ExternalPrincipal> => ({ issuer: 'issuer', subject: 'sub', email: null, displayName: null, scopes: [] }) },
      users,
    );
    await expect(identity.authenticate(undefined)).rejects.toMatchObject({ status: 401 });
  });

  it('blocks precise location persistence without explicit consent', async () => {
    const identity = new IdentityService(
      { verify: async (): Promise<ExternalPrincipal> => ({ issuer: 'issuer', subject: 'sub', email: null, displayName: null, scopes: [] }) },
      fakeUsers(false),
    );
    await expect(identity.requireLocationConsent('user-1')).rejects.toMatchObject({ status: 403 });
  });
});

function fakeUsers(consent = true): UserRepository {
  return {
    upsertPrincipal: async () => ({ id: 'user-1', issuer: 'issuer', subject: 'sub', email: null, displayName: null, createdAt: new Date() }),
    getById: async () => null,
    getPreferences: async () => ({ language: 'es', defaultPreference: 'BALANCED', maxWalkMin: 15, extraSafetyMarginMin: 0, locationConsent: consent }),
    updatePreferences: async (_id, input) => ({ language: input.language ?? 'es', defaultPreference: input.defaultPreference ?? 'BALANCED', maxWalkMin: input.maxWalkMin ?? 15, extraSafetyMarginMin: input.extraSafetyMarginMin ?? 0, locationConsent: input.locationConsent ?? consent }),
    hasLocationConsent: async () => consent,
    deleteAccount: async () => undefined,
  };
}
