import { OpenStreetMapMapTransitProvider } from '../../src/provider-gateway/adapters/openstreetmap-map-transit.provider';

describe('OpenStreetMapMapTransitProvider', () => {
  it('maps tagged OSM bus-stop nodes and ignores unrelated nodes', async () => {
    const fetcher = jest.fn(async () =>
      new Response(
        `<?xml version="1.0"?>
        <osm>
          <node id="10" lat="-2.17" lon="-79.9">
            <tag k="highway" v="bus_stop"/>
            <tag k="name" v="Terminal &amp; Centro"/>
          </node>
          <node id="11" lat="-2.171" lon="-79.901">
            <tag k="amenity" v="bench"/>
          </node>
          <node id="12" lat="-2.172" lon="-79.902">
            <tag k="public_transport" v="platform"/>
            <tag k="local_ref" v="P-12"/>
          </node>
        </osm>`,
        { status: 200 },
      ),
    ) as unknown as typeof fetch;
    const provider = new OpenStreetMapMapTransitProvider({
      baseUrl: 'https://openstreetmap.test/api/0.6/map',
      fetcher,
      now: () => new Date('2026-10-14T12:00:00.000Z'),
    });

    await expect(
      provider.discoverStops({ lat: -2.17, lon: -79.9, radiusM: 800 }),
    ).resolves.toMatchObject({
      providerKey: 'openstreetmap-map',
      sourceAuthorized: true,
      data: [
        {
          externalId: 'node:10',
          name: 'Terminal & Centro',
          location: { lat: -2.17, lon: -79.9 },
        },
        {
          externalId: 'node:12',
          name: 'P-12',
        },
      ],
    });

    expect(fetcher).toHaveBeenCalledWith(
      expect.stringContaining('bbox='),
      expect.objectContaining({
        headers: expect.objectContaining({
          'User-Agent': 'yeGamo-local-dev/1.0',
        }),
      }),
    );
  });
});
