import { DemoTransitProvider } from '../../src/provider-gateway/adapters/demo-transit.provider';
import { GeocodingGatewayService } from '../../src/provider-gateway/application/geocoding-gateway.service';
import { ProviderHealthService } from '../../src/provider-gateway/application/provider-health.service';
import { TransitGatewayService } from '../../src/provider-gateway/application/transit-gateway.service';
import { ProviderGatewayError } from '../../src/provider-gateway/domain/provider.errors';
import { GeocodingProvider, TransitPlannerProvider } from '../../src/provider-gateway/domain/provider.ports';
import { JourneyPlanRequest } from '../../src/provider-gateway/domain/provider.types';
import { createTransitProviders } from '../../src/provider-gateway/provider-gateway.module';
import { DEFAULT_GEOCODING_TIMEOUT_MS } from '../../src/provider-gateway/application/geocoding-gateway.service';
import { CanonicalHttpExceptionFilter } from '../../src/shared/errors/canonical-http-exception.filter';
import { TransitStopDiscoveryGatewayService } from '../../src/provider-gateway/application/transit-stop-discovery-gateway.service';
import { TransitStopDiscoveryProvider } from '../../src/provider-gateway/domain/provider.ports';

const request: JourneyPlanRequest = {
  origin: { lat: -2.17, lon: -79.9 },
  destination: { lat: -2.14, lon: -79.89 },
  timeMode: 'ARRIVE_BY',
  time: '2026-10-02T08:00:00-05:00',
};

describe('provider gateway', () => {
  it('allows the public geocoder enough time for the development tunnel', () => {
    expect(DEFAULT_GEOCODING_TIMEOUT_MS).toBe(5000);
  });

  it('returns canonical unavailable semantics when transit has no provider', async () => {
    await expect(new TransitGatewayService([]).plan(request)).rejects.toMatchObject({
      code: 'PROVIDER_UNAVAILABLE',
      capability: 'transit',
      dataState: 'UNAVAILABLE',
      retryable: true,
    });
  });

  it('rejects the demo provider in production', () => {
    expect(() => new DemoTransitProvider('production')).toThrow(ProviderGatewayError);
  });

  it('does not inject demo transit without an explicit non-production flag', () => {
    expect(createTransitProviders('production', true)).toEqual([]);
    expect(createTransitProviders('development', false)).toEqual([]);
    expect(createTransitProviders('development', true)[0]).toBeInstanceOf(DemoTransitProvider);
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
      sourceAuthorized: false,
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

  it('falls back to the next stop provider when the first has no stops', async () => {
    const empty: TransitStopDiscoveryProvider = {
      providerKey: 'empty-stops',
      isDemo: false,
      discoverStops: async () => ({
        providerKey: 'empty-stops',
        isDemo: false,
        sourceAuthorized: true,
        observedAt: new Date().toISOString(),
        data: [],
      }),
    };
    const fallback: TransitStopDiscoveryProvider = {
      providerKey: 'fallback-stops',
      isDemo: false,
      discoverStops: async () => ({
        providerKey: 'fallback-stops',
        isDemo: false,
        sourceAuthorized: true,
        observedAt: new Date().toISOString(),
        data: [
          {
            externalId: 'node:1',
            name: 'Parada real',
            location: { lat: -2.17, lon: -79.9 },
          },
        ],
      }),
    };

    await expect(
      new TransitStopDiscoveryGatewayService([empty, fallback]).discover({
        lat: -2.17,
        lon: -79.9,
        radiusM: 800,
      }),
    ).resolves.toMatchObject({ providerKey: 'fallback-stops', stops: [{ name: 'Parada real' }] });
  });

  it('returns timeout when the provider exceeds the deadline', async () => {
    const slow: TransitPlannerProvider = {
      providerKey: 'slow-provider',
      isDemo: false,
      plan: () => new Promise(() => undefined),
    };

    await expect(new TransitGatewayService([slow]).plan(request, 1)).rejects.toMatchObject({
      code: 'PROVIDER_TIMEOUT',
      capability: 'transit',
      dataState: 'UNAVAILABLE',
    });
  });

  it('rejects an invalid provider payload before it reaches the canonical model', async () => {
    const invalid: TransitPlannerProvider = {
      providerKey: 'invalid-provider',
      isDemo: false,
      plan: async () => ({
        providerKey: 'invalid-provider',
        isDemo: false,
        sourceAuthorized: true,
        observedAt: new Date().toISOString(),
        plan: { providerSpecific: true },
      }),
    };

    await expect(new TransitGatewayService([invalid]).plan(request)).rejects.toMatchObject({
      code: 'PROVIDER_INVALID_RESPONSE',
      capability: 'transit',
      dataState: 'UNAVAILABLE',
      retryable: false,
    });
  });

  it('maps a configured authorized provider with a recent observation', async () => {
    const observedAt = new Date().toISOString();
    const authorized: TransitPlannerProvider = {
      providerKey: 'authorized-transit',
      isDemo: false,
      plan: async () => ({
        providerKey: 'authorized-transit',
        isDemo: false,
        sourceAuthorized: true,
        observedAt,
        plan: {
          planId: 'plan-1',
          options: [
            {
              id: 'option-1',
              durationMin: 20,
              walkMin: 5,
              transfers: 0,
              liveVehicle: true,
              observedAt,
              dataState: 'CURRENT',
              reliability: { score: 90, level: 'HIGH', sampleSize: 10 },
              legs: [
                {
                  mode: 'TRANSIT',
                  from: request.origin,
                  to: request.destination,
                  durationMin: 20,
                  departureAt: null,
                  arrivalAt: null,
                  instructions: ['Toma la ruta autorizada.'],
                  routeId: 'route-1',
                  fromStopId: null,
                  toStopId: null,
                },
              ],
            },
          ],
        },
      }),
    };

    const plan = await new TransitGatewayService([authorized]).plan(request);

    expect(plan).toMatchObject({ dataState: 'CURRENT' });
    expect(plan.options[0]?.dataQuality).toMatchObject({
      freshness: 'CURRENT',
      dataState: 'CURRENT',
      liveVehicle: true,
      observedAt,
      providerDisplayName: 'authorized-transit',
      sourceAuthorized: true,
    });
  });

  it('returns unavailable semantics when geocoding has no provider', async () => {
    await expect(new GeocodingGatewayService([]).search('Centro')).rejects.toMatchObject({
      code: 'PROVIDER_UNAVAILABLE',
      capability: 'geocoding',
      dataState: 'UNAVAILABLE',
      retryable: true,
    });
  });

  it('maps geocoding results without exposing an unauthorized provider source', async () => {
    const provider: GeocodingProvider = {
      providerKey: 'demo-geocoder',
      isDemo: true,
      search: async () => ({
        providerKey: 'demo-geocoder',
        isDemo: true,
        observedAt: null,
        data: [
          {
            id: 'place-1',
            label: 'Centro de Guayaquil',
            location: request.origin,
            source: 'private-provider-dto',
          },
        ],
      }),
      reverse: async () => ({
        providerKey: 'demo-geocoder',
        isDemo: true,
        observedAt: null,
        data: {
          id: 'place-1',
          label: 'Centro de Guayaquil',
          location: request.origin,
        },
      }),
    };

    await expect(new GeocodingGatewayService([provider]).search('Centro')).resolves.toEqual([
      {
        id: 'place-1',
        label: 'Centro de Guayaquil',
        location: request.origin,
        source: null,
        dataState: 'DEGRADED',
      },
    ]);
  });

  it('reports health for configured and unavailable capabilities', () => {
    const health = new ProviderHealthService({
      transit: [{ providerKey: 'authorized-transit', isDemo: false }],
      geocoding: [{ providerKey: 'demo-geocoder', isDemo: true }],
    });

    expect(health.getAvailability()).toEqual([
      { capability: 'transit', status: 'HEALTHY', provider: 'authorized-transit' },
      { capability: 'geocoding', status: 'DEGRADED', provider: 'demo-geocoder' },
      { capability: 'vehicle-position', status: 'UNAVAILABLE', provider: null },
      { capability: 'incidents', status: 'UNAVAILABLE', provider: null },
    ]);
    expect(health.getSnapshots(new Date('2026-10-12T12:00:00.000Z'))[0]).toMatchObject({
      checkedAt: '2026-10-12T12:00:00.000Z',
      latencyMs: null,
    });
  });

  it('preserves provider error details and trace id in the canonical filter', () => {
    const response = {
      header: jest.fn().mockReturnThis(),
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
    const host = {
      switchToHttp: () => ({
        getResponse: () => response,
        getRequest: () => ({ traceId: 'trace-provider' }),
      }),
    };

    new CanonicalHttpExceptionFilter().catch(
      new ProviderGatewayError(
        'PROVIDER_TIMEOUT',
        'Provider timed out',
        true,
        { capability: 'geocoding' },
      ),
      host as never,
    );

    expect(response.status).toHaveBeenCalledWith(503);
    expect(response.header).toHaveBeenCalledWith('X-Trace-Id', 'trace-provider');
    expect(response.json).toHaveBeenCalledWith({
      code: 'PROVIDER_TIMEOUT',
      message: 'Provider timed out',
      details: {
        capability: 'geocoding',
        dataState: 'UNAVAILABLE',
        retryable: true,
      },
      traceId: 'trace-provider',
    });
  });
});
