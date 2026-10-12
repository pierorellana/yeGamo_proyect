import { ForbiddenException, Inject, Injectable, UnauthorizedException } from '@nestjs/common';

import {
  AuthPrincipal,
  ExternalPrincipal,
  PRINCIPAL_VERIFIER,
  USER_REPOSITORY,
  UserPreferencesRecord,
  UserRecord,
  UserRepository,
} from '../domain/identity.ports';

@Injectable()
export class IdentityService {
  constructor(
    @Inject(PRINCIPAL_VERIFIER) private readonly verifier: { verify(token: string | undefined): Promise<ExternalPrincipal> },
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
  ) {}

  async authenticate(authorization: string | undefined): Promise<AuthPrincipal> {
    const token = authorization?.startsWith('Bearer ') ? authorization.slice(7).trim() : undefined;
    if (token === undefined || token.length === 0) {
      throw new UnauthorizedException({
        code: 'UNAUTHORIZED',
        message: 'Falta un bearer token válido.',
        details: { identity: 'UNAVAILABLE' },
      });
    }

    const external = await this.verifier.verify(token);
    const user = await this.users.upsertPrincipal(external);
    return { ...external, userId: user.id };
  }

  getCurrentUser(userId: string): Promise<UserRecord | null> {
    return this.users.getById(userId);
  }

  getPreferences(userId: string): Promise<UserPreferencesRecord> {
    return this.users.getPreferences(userId);
  }

  updatePreferences(userId: string, input: Partial<UserPreferencesRecord>): Promise<UserPreferencesRecord> {
    return this.users.updatePreferences(userId, input);
  }

  hasLocationConsent(userId: string): Promise<boolean> {
    return this.users.hasLocationConsent(userId);
  }

  async requireLocationConsent(userId: string): Promise<void> {
    if (!(await this.hasLocationConsent(userId))) {
      throw new ForbiddenException({
        code: 'LOCATION_CONSENT_REQUIRED',
        message: 'Se requiere consentimiento explícito para guardar ubicación precisa.',
        details: { locationConsent: false },
      });
    }
  }

  deleteAccount(userId: string): Promise<void> {
    return this.users.deleteAccount(userId);
  }
}
