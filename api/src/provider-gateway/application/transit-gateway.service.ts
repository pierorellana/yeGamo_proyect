import { Inject, Injectable } from '@nestjs/common';

import { ProviderGatewayError } from '../domain/provider.errors';
import { TransitPlannerProvider } from '../domain/provider.ports';
import { JourneyPlanRequest, TransitPlan } from '../domain/provider.types';
import { mapProviderPlan } from '../mappers/transit-plan.mapper';

export const TRANSIT_PLANNER_PROVIDERS = Symbol('TRANSIT_PLANNER_PROVIDERS');

@Injectable()
export class TransitGatewayService {
  constructor(
    @Inject(TRANSIT_PLANNER_PROVIDERS)
    private readonly providers: TransitPlannerProvider[],
  ) {}

  async plan(request: JourneyPlanRequest, timeoutMs = 2500): Promise<TransitPlan> {
    if (this.providers.length === 0) {
      throw new ProviderGatewayError(
        'PROVIDER_UNAVAILABLE',
        'No transit provider is configured',
      );
    }

    let lastError: ProviderGatewayError | undefined;
    for (const provider of this.providers) {
      try {
        const result = await withTimeout(provider.plan(request), timeoutMs);
        return mapProviderPlan(result.plan, result.providerKey, result.isDemo, result.observedAt);
      } catch (error) {
        lastError =
          error instanceof ProviderGatewayError
            ? error
            : new ProviderGatewayError(
                'PROVIDER_UNAVAILABLE',
                `Provider ${provider.providerKey} failed`,
              );
      }
    }

    throw lastError ?? new ProviderGatewayError('PROVIDER_UNAVAILABLE', 'No provider returned a plan');
  }
}

async function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () => reject(new ProviderGatewayError('PROVIDER_TIMEOUT', 'Transit provider timed out')),
      timeoutMs,
    );
  });

  try {
    return await Promise.race([promise, timeout]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}
