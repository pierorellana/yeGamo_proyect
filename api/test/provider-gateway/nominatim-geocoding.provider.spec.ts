import { NominatimGeocodingProvider } from '../../src/provider-gateway/adapters/nominatim-geocoding.provider';

describe('NominatimGeocodingProvider', () => {
  it('maps search results without leaking Nominatim fields', async () => {
    const fetcher = jest.fn(async () =>
      new Response(
        JSON.stringify([
          {
            place_id: 10,
            osm_type: 'node',
            osm_id: 20,
            display_name: 'Malecón 2000',
            lat: '-2.19',
            lon: '-79.88',
          },
        ]),
        { status: 200 },
      ),
    ) as unknown as typeof fetch;
    const provider = new NominatimGeocodingProvider({
      baseUrl: 'https://nominatim.test',
      userAgent: 'yeGamo-test/1.0',
      fetcher,
    });

    const result = await provider.search('Malecon');

    expect(result.providerKey).toBe('openstreetmap-nominatim');
    expect(result.sourceAuthorized).toBe(true);
    expect(result.data).toEqual([
      {
        id: 'nominatim:10',
        label: 'Malecón 2000',
        location: { lat: -2.19, lon: -79.88 },
      },
    ]);
    expect(fetcher).toHaveBeenCalledWith(
      expect.stringContaining('/search?'),
      expect.objectContaining({
        headers: expect.objectContaining({ 'User-Agent': 'yeGamo-test/1.0' }),
      }),
    );
  });

  it('biases explicit searches to Ecuador and the transient origin', async () => {
    let requestedUrl = '';
    const fetcher = jest.fn(async (input: string | URL) => {
      requestedUrl = input.toString();
      return new Response('[]', { status: 200 });
    }) as unknown as typeof fetch;
    const provider = new NominatimGeocodingProvider({
      baseUrl: 'https://nominatim.test',
      userAgent: 'yeGamo-test/1.0',
      fetcher,
    });

    await provider.search('terminal', { lat: -2.17, lon: -79.9 });

    const params = new URL(requestedUrl).searchParams;
    expect(params.get('countrycodes')).toBe('ec');
    expect(params.get('viewbox')).toBe('-80.4,-1.67,-79.4,-2.67');
    expect(params.get('bounded')).toBeNull();
  });

  it('limits explicit searches to one request per second', async () => {
    const fetcher = jest.fn(async () => new Response('[]', { status: 200 })) as unknown as typeof fetch;
    const provider = new NominatimGeocodingProvider({
      baseUrl: 'https://nominatim.test',
      userAgent: 'yeGamo-test/1.0',
      fetcher,
      now: () => new Date('2026-10-13T12:00:00.000Z'),
    });

    await provider.search('Centro');
    await expect(provider.search('Malecon')).rejects.toMatchObject({
      code: 'PROVIDER_UNAVAILABLE',
      retryable: true,
    });
    expect(fetcher).toHaveBeenCalledTimes(1);
  });
});
