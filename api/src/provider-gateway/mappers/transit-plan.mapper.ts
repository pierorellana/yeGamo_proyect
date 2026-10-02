import { ProviderGatewayError } from '../domain/provider.errors';
import {
  DataQuality,
  JourneyLeg,
  JourneyOption,
  TransitPlan,
} from '../domain/provider.types';

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
): TransitPlan {
  if (!isRawPlan(raw)) {
    throw new ProviderGatewayError(
      'PROVIDER_INVALID_RESPONSE',
      `Provider ${providerKey} returned an invalid plan`,
      false,
    );
  }

  const options = raw.options.map((option) => {
    const dataQuality: DataQuality = {
      freshness: isDemo ? 'UNKNOWN' : option.dataState === 'STALE' ? 'STALE' : 'CURRENT',
      dataState: isDemo ? 'DEGRADED' : option.dataState ?? raw.dataState ?? 'CURRENT',
      liveVehicle: isDemo ? false : option.liveVehicle ?? false,
      observedAt: isDemo ? null : option.observedAt ?? observedAt,
      providerDisplayName: isDemo ? null : option.providerDisplayName ?? providerKey,
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
    dataState: isDemo ? 'DEGRADED' : raw.dataState ?? 'CURRENT',
    options,
  };
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
        typeof item.durationMin === 'number' &&
        typeof item.walkMin === 'number' &&
        typeof item.transfers === 'number' &&
        Array.isArray(item.legs)
      );
    })
  );
}
