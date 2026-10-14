import { OpenStreetMapTransitProvider } from '../../src/provider-gateway/adapters/overpass-transit.provider';

describe('OpenStreetMapTransitProvider', () => {
  it('maps valid OSM stop nodes and ignores invalid coordinates', async () => {
    const fetcher = jest.fn(async () =>
      new Response(
        JSON.stringify({
          elements: [
            {
              type: 'node',
              id: 10,
              lat: -2.17,
              lon: -79.9,
              tags: { highway: 'bus_stop', name: 'Centro' },
            },
            {
              type: 'node',
              id: 11,
              lat: 99,
              lon: -79.9,
              tags: { public_transport: 'platform' },
            },
          ],
        }),
        { status: 200 },
      ),
    ) as unknown as typeof fetch;
    const provider = new OpenStreetMapTransitProvider({
      baseUrl: 'https://overpass.test/api/interpreter',
      fetcher,
      minRequestIntervalMs: 0,
      now: () => new Date('2026-10-14T12:00:00.000Z'),
    });

    await expect(
      provider.discoverStops({ lat: -2.17, lon: -79.9, radiusM: 800 }),
    ).resolves.toMatchObject({
      providerKey: 'openstreetmap-overpass',
      sourceAuthorized: true,
      data: [
        {
          externalId: 'node:10',
          name: 'Centro',
          location: { lat: -2.17, lon: -79.9 },
        },
      ],
    });
  });

  it('uses local_ref and then a fallback name when name is absent', async () => {
    const fetcher = jest.fn(async () =>
      new Response(
        JSON.stringify({
          elements: [
            {
              type: 'node',
              id: 10,
              lat: -2.17,
              lon: -79.9,
              tags: { public_transport: 'platform', local_ref: 'P-10' },
            },
            {
              type: 'node',
              id: 11,
              lat: -2.171,
              lon: -79.901,
              tags: { public_transport: 'stop_position' },
            },
          ],
        }),
        { status: 200 },
      ),
    ) as unknown as typeof fetch;
    const provider = new OpenStreetMapTransitProvider({
      fetcher,
      minRequestIntervalMs: 0,
    });

    await expect(
      provider.discoverStops({ lat: -2.17, lon: -79.9, radiusM: 800 }),
    ).resolves.toMatchObject({
      data: [
        { externalId: 'node:10', name: 'P-10' },
        { externalId: 'node:11', name: 'Parada sin nombre' },
      ],
    });
  });

  it('maps way centers returned for platform geometry', async () => {
    const fetcher = jest.fn(async () =>
      new Response(
        JSON.stringify({
          elements: [
            {
              type: 'way',
              id: 20,
              center: { lat: -2.17, lon: -79.9 },
              tags: { public_transport: 'platform', name: 'Andén Centro' },
            },
          ],
        }),
        { status: 200 },
      ),
    ) as unknown as typeof fetch;
    const provider = new OpenStreetMapTransitProvider({
      fetcher,
      minRequestIntervalMs: 0,
      retryCount: 0,
    });

    await expect(
      provider.discoverStops({ lat: -2.17, lon: -79.9, radiusM: 800 }),
    ).resolves.toMatchObject({
      data: [
        {
          externalId: 'way:20',
          name: 'Andén Centro',
          location: { lat: -2.17, lon: -79.9 },
        },
      ],
    });
  });

  it('serves the same cell from cache without a second HTTP request', async () => {
    const fetcher = jest.fn(async () =>
      new Response(JSON.stringify({ elements: [] }), { status: 200 }),
    ) as unknown as typeof fetch;
    const provider = new OpenStreetMapTransitProvider({
      fetcher,
      minRequestIntervalMs: 0,
      now: () => new Date('2026-10-14T12:00:00.000Z'),
    });
    const input = { lat: -2.17, lon: -79.9, radiusM: 800 };

    await provider.discoverStops(input);
    await provider.discoverStops(input);

    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('maps invalid responses to a non-retryable provider error', async () => {
    const fetcher = jest.fn(async () =>
      new Response(JSON.stringify({ invalid: true }), { status: 200 }),
    ) as unknown as typeof fetch;
    const provider = new OpenStreetMapTransitProvider({
      fetcher,
      minRequestIntervalMs: 0,
    });

    await expect(
      provider.discoverStops({ lat: -2.17, lon: -79.9, radiusM: 800 }),
    ).rejects.toMatchObject({
      code: 'PROVIDER_INVALID_RESPONSE',
      capability: 'transit',
      retryable: false,
    });
  });

  it('sends the identifying user agent and bounded POST query', async () => {
    const fetcher = jest.fn(async () =>
      new Response(JSON.stringify({ elements: [] }), { status: 200 }),
    ) as unknown as typeof fetch;
    const provider = new OpenStreetMapTransitProvider({
      baseUrl: 'https://overpass.test/api/interpreter',
      userAgent: 'yeGamo-test/1.0',
      fetcher,
      minRequestIntervalMs: 0,
    });

    await provider.discoverStops({ lat: -2.17, lon: -79.9, radiusM: 800 });

    expect(fetcher).toHaveBeenCalledWith(
      'https://overpass.test/api/interpreter',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          'User-Agent': 'yeGamo-test/1.0',
        }),
        body: expect.stringContaining('data='),
      }),
    );
    const options = (fetcher as jest.Mock).mock.calls[0]?.[1] as RequestInit;
    const query = decodeURIComponent(String(options.body).replace('data=', ''));
    expect(query).toContain('highway');
    expect(query).toContain('public_transport');
  });
});
