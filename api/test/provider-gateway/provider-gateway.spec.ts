import { DemoTransitProvider } from '../../src/provider-gateway/adapters/demo-transit.provider';
import { TransitGatewayService } from '../../src/provider-gateway/application/transit-gateway.service';
import { ProviderGatewayError } from '../../src/provider-gateway/domain/provider.errors';
import { TransitPlannerProvider } from '../../src/provider-gateway/domain/provider.ports';
import { JourneyPlanRequest } from '../../src/provider-gateway/domain/provider.types';

const request: JourneyPlanRequest = {
  origin: { lat: -2.17, lon: -79.9 },
  destination: { lat: -2.14, lon: -79.89 },
  timeMode: 'ARRIVE_BY',
  time: '2026-10-02T08:00:00-05:00',
};

describe('provider gateway', () => {
  it('rejects the demo provider in production', () => {
    expect(() => new DemoTransitProvider('production')).toThrow(ProviderGatewayError);
  });

  it('maps demo data to degraded, non-live canonical data', async () => {
    const gateway = new TransitGatewayService([new DemoTransitProvider('test')]);
    const plan = await gateway.plan(request);

    expect(plan.dataState).toBe('DEGRADED');
    expect(plan.options[0]?.dataQuality).toMatchObject({
      dataState: 'DEGRADED',
      liveVehicle: false,
      providerDisplayName: null,
      observedAt: null,
    });
  });

  it('falls back to the next provider after a failure', async () => {
    const failing: TransitPlannerProvider = {
      providerKey: 'failing-provider',
      isDemo: false,
      plan: async () => {
        throw new ProviderGatewayError('PROVIDER_TIMEOUT', 'timed out');
      },
    };
    const gateway = new TransitGatewayService([failing, new DemoTransitProvider('test')]);

    await expect(gateway.plan(request)).resolves.toMatchObject({ dataState: 'DEGRADED' });
  });

  it('returns timeout when the provider exceeds the deadline', async () => {
    const slow: TransitPlannerProvider = {
      providerKey: 'slow-provider',
      isDemo: false,
      plan: () => new Promise(() => undefined),
    };

    await expect(new TransitGatewayService([slow]).plan(request, 1)).rejects.toMatchObject({
      code: 'PROVIDER_TIMEOUT',
    });
  });
});
