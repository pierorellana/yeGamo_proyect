import { readFile, readdir } from 'node:fs/promises';
import { join, resolve } from 'node:path';

type HttpMethod = 'get' | 'post' | 'put' | 'patch' | 'delete';

interface Operation {
  method: HttpMethod;
  path: string;
  block: string;
}

const methods: HttpMethod[] = ['get', 'post', 'put', 'patch', 'delete'];
const postMvpOperations = new Set([
  'post /reports',
  'get /reports/nearby',
  'post /reports/{id}/confirm',
  'post /reports/{id}/resolve',
]);

describe('canonical OpenAPI contract', () => {
  let contract: string;
  let controllerSources: string[];

  beforeAll(async () => {
    contract = await readFile(resolve(__dirname, '../../contracts/openapi.yaml'), 'utf8');
    controllerSources = await readControllerSources(resolve(__dirname, '../../src'));
  });

  it('matches every runtime controller operation and records post-MVP exceptions', () => {
    const operations = parseOperations(contract);
    const runtimeOperations = controllerSources.flatMap(parseControllerRoutes);
    const contractKeys = new Set(operations.map((operation) => `${operation.method} ${operation.path}`));
    const runtimeKeys = new Set(runtimeOperations.map((operation) => `${operation.method} ${operation.path}`));

    for (const key of runtimeKeys) {
      expect(contractKeys).toContain(key);
    }

    for (const operation of operations) {
      const key = `${operation.method} ${operation.path}`;
      if (postMvpOperations.has(key)) {
        expect(operation.block).toContain('x-implementation-status: post-mvp');
      } else {
        expect(runtimeKeys).toContain(key);
      }
    }

    expect(operations).toHaveLength(41);
    expect(postMvpOperations.size).toBe(4);
    expect(runtimeOperations).toHaveLength(37);
  });

  it('publishes operation ids, response statuses, and parameter references', () => {
    for (const operation of parseOperations(contract)) {
      expect(operation.block).toMatch(/operationId:\s*[A-Za-z][A-Za-z0-9]+/);
      expect(operation.block).toContain('responses:');

      const statuses = [...operation.block.matchAll(/^        '(\d{3})':/gm)].map(
        (match) => Number(match[1]),
      );
      expect(statuses.length).toBeGreaterThan(0);
      for (const status of statuses) {
        expect(status).toBeGreaterThanOrEqual(200);
        expect(status).toBeLessThan(600);
      }

      for (const parameter of operation.path.matchAll(/\{([^}]+)\}/g)) {
        const rawParameter = parameter[1]!;
        const parameterName = rawParameter === 'id'
          ? 'ResourceId'
          : `${rawParameter[0]!.toUpperCase()}${rawParameter.slice(1)}`;
        expect(operation.block).toContain(`#/components/parameters/${parameterName}`);
      }
    }
  });

  it('keeps canonical errors, trace headers, and idempotency headers aligned', () => {
    const responseNames = [
      'BadRequest',
      'Unauthorized',
      'Forbidden',
      'NotFound',
      'Conflict',
      'ValidationError',
      'RateLimited',
      'ProviderUnavailable',
    ];
    for (const name of responseNames) {
      const block = componentBlock('responses', name);
      expect(block).toContain("$ref: '#/components/schemas/Error'");
      expect(block).toContain('X-Trace-Id:');
    }

    expect(contract).toContain('IdempotencyKeyRequired:');
    expect(contract).toContain('IdempotencyKeyOptional:');
    expect(contract).toContain('X-Trace-Id:');
    expect(contract).toContain('dataState: UNAVAILABLE');
    expect(contract).not.toContain('providerSpecific');
  });

  it('declares fields and examples for the published canonical models', async () => {
    for (const schema of [
      'GeoPoint',
      'Place',
      'TransitStop',
      'JourneyPlanRequest',
      'JourneyPlanResponse',
      'ActiveJourney',
      'CommuteProfile',
      'Notification',
      'User',
      'Error',
    ]) {
      const block = componentBlock('schemas', schema);
      expect(block).toContain('properties:');
    }

    const error = JSON.parse(
      await readFile(resolve(__dirname, '../../contracts/examples/error.json'), 'utf8'),
    ) as Record<string, unknown>;
    expect(error).toEqual(
      expect.objectContaining({
        code: 'PROVIDER_UNAVAILABLE',
        message: expect.any(String),
        details: expect.objectContaining({ dataState: 'UNAVAILABLE' }),
        traceId: expect.any(String),
      }),
    );

    const request = JSON.parse(
      await readFile(resolve(__dirname, '../../contracts/examples/journey-plan-request.json'), 'utf8'),
    ) as Record<string, unknown>;
    expect(request).toEqual(
      expect.objectContaining({
        origin: expect.any(Object),
        destination: expect.any(Object),
        timeMode: expect.any(String),
      }),
    );

    const response = JSON.parse(
      await readFile(resolve(__dirname, '../../contracts/examples/journey-plan-response.json'), 'utf8'),
    ) as Record<string, unknown>;
    expect(response).toEqual(
      expect.objectContaining({
        planId: expect.any(String),
        dataState: expect.any(String),
        options: expect.any(Array),
      }),
    );
  });

  it('keeps explicit providerless semantics on dependent operations', () => {
    for (const path of ['/places/search', '/places/reverse', '/transit/stops/nearby', '/journeys/plan']) {
      const block = operationBlock(path, path === '/journeys/plan' ? 'post' : 'get');
      expect(block).toContain("'503': { $ref: '#/components/responses/ProviderUnavailable' }");
    }
    expect(operationBlock('/transit/stops/{stopId}/departures', 'get')).toContain(
      "'503': { $ref: '#/components/responses/ProviderUnavailable' }",
    );
  });

  function operationBlock(path: string, method: HttpMethod): string {
    const operation = parseOperations(contract).find(
      (candidate) => candidate.path === path && candidate.method === method,
    );
    expect(operation).toBeDefined();
    return operation?.block ?? '';
  }

  function componentBlock(section: string, name: string): string {
    const sectionStart = contract.indexOf(`  ${section}:`);
    expect(sectionStart).toBeGreaterThanOrEqual(0);
    const start = contract.indexOf(`    ${name}:`, sectionStart);
    expect(start).toBeGreaterThanOrEqual(0);
    const remainder = contract.slice(start + 5);
    const nextOffset = remainder.search(/\n    \S/);
    const end = nextOffset === -1 ? contract.length : start + 5 + nextOffset;
    return contract.slice(start, end);
  }

  it('defines one canonical active-journey progress protocol', () => {
    const operations = parseOperations(contract);
    const start = operations.find((o) => o.method === 'post' && o.path === '/journeys/{planId}/options/{optionId}/start');
    const progress = operations.find((o) => o.method === 'patch' && o.path === '/active-journeys/{id}/progress');
    expect(start?.block).toContain("'201'");
    expect(start?.block).toContain('IdempotencyKeyRequired');
    expect(progress?.block).toContain('JourneyProgressRequest');

    const request = schemaBlock(contract, 'JourneyProgressRequest');
    expect(request).toContain('additionalProperties: false');
    expect(request).toContain('currentLegIndex');
    expect(request).not.toMatch(/stepIndex|sequence|status:/);

    const journey = schemaBlock(contract, 'ActiveJourney');
    expect(journey).toContain('required: [id, planId, optionId, status, dataState, currentLegIndex, legs]');
    expect(journey).not.toMatch(/stepIndex|currentStep|totalSteps/);
    // The active journey can never claim an ETA without an authorized source.
    expect(journey).toContain('Siempre null');
  });
});

function parseOperations(contract: string): Operation[] {
  const pathMatches = [...contract.matchAll(/^  (\/[^:]+):\s*$/gm)];
  return pathMatches.flatMap((pathMatch, index) => {
    const path = pathMatch[1]!;
    const start = pathMatch.index ?? 0;
    const end = pathMatches[index + 1]?.index ?? contract.length;
    const pathBlock = contract.slice(start, end);
    return methods.flatMap((method) => {
      const methodIndex = pathBlock.search(new RegExp(`^    ${method}:\\s*$`, 'm'));
      if (methodIndex < 0) return [];
      const nextMethod = methods
        .map((candidate) => pathBlock.search(new RegExp(`^    ${candidate}:\\s*$`, 'm')))
        .filter((candidateIndex) => candidateIndex > methodIndex)
        .sort((a, b) => a - b)[0];
      const blockEnd = nextMethod === undefined ? end : start + nextMethod;
      return [{ method, path, block: contract.slice(start + methodIndex, blockEnd) }];
    });
  });
}

function parseControllerRoutes(source: string): Operation[] {
  const controller = source.match(/@Controller(?:\('([^']*)'\))?/);
  const prefix = controller?.[1] ?? '';
  return [...source.matchAll(/@(Get|Post|Put|Patch|Delete)\s*(?:\(\s*'([^']*)'\s*\))?/g)].map(
    (match) => ({
      method: match[1]!.toLowerCase() as HttpMethod,
      path: normalizeRoute(prefix, match[2] ?? ''),
      block: '',
    }),
  );
}

function normalizeRoute(prefix: string, path: string): string {
  const joined = [prefix, path].filter((value) => value.length > 0).join('/');
  const normalized = joined
    .replace(/^\/+|\/+$/g, '')
    .replace(/:([A-Za-z0-9_]+)/g, '{$1}');
  return normalized.length === 0 ? '/' : `/${normalized}`;
}

async function readControllerSources(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map(async (entry) => {
      const path = join(directory, entry.name);
      if (entry.isDirectory()) return readControllerSources(path);
      if (entry.isFile() && entry.name.endsWith('.controller.ts')) {
        return [await readFile(path, 'utf8')];
      }
      return [];
    }),
  );
  return files.flat();
}

function schemaBlock(contract: string, name: string): string {
  const start = contract.indexOf(`\n    ${name}:\n`);
  expect(start).toBeGreaterThan(-1);
  const rest = contract.slice(start + 1);
  const next = rest.slice(1).search(/\n    [A-Za-z]+:\n/);
  return next === -1 ? rest : rest.slice(0, next + 1);
}
