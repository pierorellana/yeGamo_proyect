import { ProviderGatewayError } from '../domain/provider.errors';
import {
  DataQuality,
  JourneyLeg,
  JourneyOption,
  TransitPlan,
} from '../domain/provider.types';

const RECENT_PROVIDER_WINDOW_MS = 5 * 60 * 1000;

interface RawPlan {
  planId: string;
  recommendedLeaveAt?: string | null;
  arrivalWindow?: { from: string; to: string } | null;
  dataState?: TransitPlan['dataState'];
  options: RawOption[];
}

interface RawOption {
  id: string;
  durationMin: number;
  walkMin: number;
  transfers: number;
  reliability?: JourneyOption['reliability'];
  liveVehicle?: boolean;
  observedAt?: string | null;
  dataState?: TransitPlan['dataState'];
  providerDisplayName?: string | null;
  legs: JourneyLeg[];
}

export function mapProviderPlan(
  raw: unknown,
  providerKey: string,
  isDemo: boolean,
  observedAt: string | null,
  sourceAuthorized = !isDemo,
  now = new Date(),
): TransitPlan {
  if (!isRawPlan(raw)) {
    throw new ProviderGatewayError(
      'PROVIDER_INVALID_RESPONSE',
      `Provider ${providerKey} returned an invalid plan`,
      false,
    );
  }

  const options = raw.options.map((option) => {
    const optionObservedAt = isDemo ? null : option.observedAt ?? observedAt;
    const isRecent = sourceAuthorized && isRecentTimestamp(optionObservedAt, now);
    const providerDataState = option.dataState ?? raw.dataState;
    const dataQuality: DataQuality = {
      freshness: isDemo
        ? 'UNKNOWN'
        : providerDataState === 'STALE' || (optionObservedAt !== null && !isRecent)
          ? 'STALE'
          : isRecent
            ? 'CURRENT'
            : 'UNKNOWN',
      dataState: isDemo
        ? 'DEGRADED'
        : !sourceAuthorized
          ? 'DEGRADED'
          : normalizeDataState(providerDataState, isRecent, optionObservedAt !== null),
      liveVehicle: !isDemo && sourceAuthorized && isRecent && option.liveVehicle === true,
      observedAt: optionObservedAt,
      providerDisplayName: !isDemo && sourceAuthorized ? providerKey : null,
      sourceAuthorized: !isDemo && sourceAuthorized,
    };

    return {
      id: option.id,
      durationMin: option.durationMin,
      walkMin: option.walkMin,
      transfers: option.transfers,
      reliability: option.reliability ?? { score: null, level: null, sampleSize: null },
      dataQuality,
      legs: option.legs,
    } satisfies JourneyOption;
  });

  return {
    planId: raw.planId,
    recommendedLeaveAt: raw.recommendedLeaveAt ?? null,
    arrivalWindow: raw.arrivalWindow ?? null,
    dataState: isDemo
      ? 'DEGRADED'
      : !sourceAuthorized
        ? 'DEGRADED'
        : normalizeDataState(
            raw.dataState,
            isRecentTimestamp(observedAt, now),
            observedAt !== null,
          ),
    options,
  };
}

function normalizeDataState(
  value: TransitPlan['dataState'] | undefined,
  isRecent: boolean,
  hasObservation: boolean,
): TransitPlan['dataState'] {
  if (value === 'CURRENT' && !isRecent) return hasObservation ? 'STALE' : 'DEGRADED';
  return value ?? (isRecent ? 'CURRENT' : hasObservation ? 'STALE' : 'DEGRADED');
}

function isRecentTimestamp(value: string | null, now: Date): boolean {
  if (value === null) return false;
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) return false;
  const ageMs = now.getTime() - timestamp;
  return ageMs >= 0 && ageMs <= RECENT_PROVIDER_WINDOW_MS;
}

function isRawPlan(value: unknown): value is RawPlan {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Partial<RawPlan>;
  return (
    typeof candidate.planId === 'string' &&
    Array.isArray(candidate.options) &&
    candidate.options.every((option) => {
      if (typeof option !== 'object' || option === null) return false;
      const item = option as Partial<RawOption>;
      return (
        typeof item.id === 'string' &&
        isNonNegativeInteger(item.durationMin) &&
        isNonNegativeInteger(item.walkMin) &&
        isNonNegativeInteger(item.transfers) &&
        Array.isArray(item.legs) &&
        item.legs.every(isRawJourneyLeg) &&
        (item.reliability === undefined || isReliability(item.reliability)) &&
        (item.dataState === undefined || isDataState(item.dataState)) &&
        (item.observedAt === undefined || item.observedAt === null || isDateTime(item.observedAt)) &&
        (item.providerDisplayName === undefined ||
          item.providerDisplayName === null ||
          typeof item.providerDisplayName === 'string')
      );
    }) &&
    (candidate.recommendedLeaveAt === undefined ||
      candidate.recommendedLeaveAt === null ||
      isDateTime(candidate.recommendedLeaveAt)) &&
    (candidate.arrivalWindow === undefined ||
      candidate.arrivalWindow === null ||
      (typeof candidate.arrivalWindow === 'object' &&
        candidate.arrivalWindow !== null &&
        isDateTime(candidate.arrivalWindow.from) &&
        isDateTime(candidate.arrivalWindow.to))) &&
    (candidate.dataState === undefined || isDataState(candidate.dataState))
  );
}

function isDataState(value: unknown): value is TransitPlan['dataState'] {
  return (
    value === 'CURRENT' ||
    value === 'STALE' ||
    value === 'DEGRADED' ||
    value === 'OFFLINE_CACHE' ||
    value === 'UNAVAILABLE'
  );
}

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0;
}

function isReliability(value: unknown): boolean {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Partial<JourneyOption['reliability']>;
  return (
    (candidate.score === null ||
      (typeof candidate.score === 'number' && Number.isInteger(candidate.score) && candidate.score >= 0 && candidate.score <= 100)) &&
    (candidate.level === null ||
      candidate.level === 'HIGH' ||
      candidate.level === 'MEDIUM' ||
      candidate.level === 'LOW') &&
    (candidate.sampleSize === null ||
      (typeof candidate.sampleSize === 'number' && Number.isInteger(candidate.sampleSize) && candidate.sampleSize >= 0))
  );
}

function isRawJourneyLeg(value: unknown): value is JourneyLeg {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Partial<JourneyLeg>;
  return (
    (candidate.mode === 'WALK' ||
      candidate.mode === 'TRANSIT' ||
      candidate.mode === 'TRANSFER' ||
      candidate.mode === 'BIKE' ||
      candidate.mode === 'OTHER') &&
    isGeoPoint(candidate.from) &&
    isGeoPoint(candidate.to) &&
    isNonNegativeInteger(candidate.durationMin) &&
    (candidate.departureAt === null || isDateTime(candidate.departureAt)) &&
    (candidate.arrivalAt === null || isDateTime(candidate.arrivalAt)) &&
    Array.isArray(candidate.instructions) &&
    candidate.instructions.every((instruction) => typeof instruction === 'string') &&
    (candidate.routeId === null || typeof candidate.routeId === 'string') &&
    (candidate.fromStopId === null || typeof candidate.fromStopId === 'string') &&
    (candidate.toStopId === null || typeof candidate.toStopId === 'string')
  );
}

function isGeoPoint(value: unknown): boolean {
  if (typeof value !== 'object' || value === null) return false;
  const point = value as { lat?: unknown; lon?: unknown };
  return (
    typeof point.lat === 'number' &&
    Number.isFinite(point.lat) &&
    point.lat >= -90 &&
    point.lat <= 90 &&
    typeof point.lon === 'number' &&
    Number.isFinite(point.lon) &&
    point.lon >= -180 &&
    point.lon <= 180
  );
}

function isDateTime(value: unknown): value is string {
  return typeof value === 'string' && Number.isFinite(Date.parse(value));
}
