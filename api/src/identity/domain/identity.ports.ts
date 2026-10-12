export interface ExternalPrincipal {
  readonly issuer: string;
  readonly subject: string;
  readonly email: string | null;
  readonly displayName: string | null;
  readonly scopes: readonly string[];
}

export interface AuthPrincipal extends ExternalPrincipal {
  readonly userId: string;
}

export interface UserRecord {
  readonly id: string;
  readonly issuer: string;
  readonly subject: string;
  readonly email: string | null;
  readonly displayName: string | null;
  readonly createdAt: Date;
}

export interface UserPreferencesRecord {
  readonly language: string;
  readonly defaultPreference: string;
  readonly maxWalkMin: number;
  readonly extraSafetyMarginMin: number;
  readonly locationConsent: boolean;
}

export interface UserRepository {
  upsertPrincipal(principal: ExternalPrincipal): Promise<UserRecord>;
  getById(userId: string): Promise<UserRecord | null>;
  getPreferences(userId: string): Promise<UserPreferencesRecord>;
  updatePreferences(userId: string, input: Partial<UserPreferencesRecord>): Promise<UserPreferencesRecord>;
  hasLocationConsent(userId: string): Promise<boolean>;
  deleteAccount(userId: string): Promise<void>;
}

export interface PrincipalVerifier {
  verify(token: string | undefined): Promise<ExternalPrincipal>;
}

export const PRINCIPAL_VERIFIER = Symbol('PRINCIPAL_VERIFIER');
export const USER_REPOSITORY = Symbol('USER_REPOSITORY');
