import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import type { Request } from 'express';

import { IdentityService } from '../application/identity.service';
import type { AuthPrincipal } from '../domain/identity.ports';

export type AuthenticatedRequest = Request & { principal?: AuthPrincipal };

@Injectable()
export class PrincipalAuthGuard implements CanActivate {
  constructor(private readonly identity: IdentityService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    request.principal = await this.identity.authenticate(request.header('authorization'));
    return true;
  }
}

export function principalOf(request: AuthenticatedRequest): AuthPrincipal {
  if (request.principal === undefined) throw new Error('Authenticated request has no principal');
  return request.principal;
}
