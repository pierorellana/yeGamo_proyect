import { Module } from '@nestjs/common';

import { DatabaseModule } from '../shared/database/database.module';
import { IDEMPOTENCY_STORE } from '../shared/idempotency/idempotency.ports';
import { IdempotencyService } from '../shared/idempotency/idempotency.service';
import { PrismaIdempotencyStore } from '../shared/idempotency/prisma-idempotency.store';
import { IdentityOperationsService } from './application/identity-operations.service';
import { IdentityService } from './application/identity.service';
import { OidcPrincipalVerifier } from './application/oidc-principal.verifier';
import { PRINCIPAL_VERIFIER, USER_REPOSITORY } from './domain/identity.ports';
import { PrincipalAuthGuard } from './http/auth.guard';
import { IdentityController } from './http/identity.controller';
import { PrismaUserRepository } from './infrastructure/prisma-user.repository';

@Module({
  imports: [DatabaseModule],
  controllers: [IdentityController],
  providers: [
    OidcPrincipalVerifier,
    { provide: PRINCIPAL_VERIFIER, useExisting: OidcPrincipalVerifier },
    PrismaUserRepository,
    { provide: USER_REPOSITORY, useExisting: PrismaUserRepository },
    PrismaIdempotencyStore,
    { provide: IDEMPOTENCY_STORE, useExisting: PrismaIdempotencyStore },
    IdempotencyService,
    IdentityService,
    IdentityOperationsService,
    PrincipalAuthGuard,
  ],
  exports: [IdentityService, PrincipalAuthGuard, IdempotencyService, IDEMPOTENCY_STORE, USER_REPOSITORY],
})
export class IdentityModule {}
