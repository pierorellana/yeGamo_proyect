export type DataState =
  | 'CURRENT'
  | 'STALE'
  | 'DEGRADED'
  | 'OFFLINE_CACHE'
  | 'UNAVAILABLE';

export type Freshness = 'CURRENT' | 'STALE' | 'UNKNOWN';

export interface DataQuality {
  freshness: Freshness;
  dataState: DataState;
  liveVehicle: boolean;
  observedAt: string | null;
  providerDisplayName: string | null;
}

export interface GeoPoint {
  lat: number;
  lon: number;
}

export interface JourneyLeg {
  mode: 'WALK' | 'TRANSIT' | 'TRANSFER' | 'BIKE' | 'OTHER';
  from: GeoPoint;
  to: GeoPoint;
  durationMin: number;
  departureAt: string | null;
  arrivalAt: string | null;
  instructions: string[];
  routeId: string | null;
  fromStopId: string | null;
  toStopId: string | null;
}

export interface Reliability {
  score: number | null;
  level: 'HIGH' | 'MEDIUM' | 'LOW' | null;
  sampleSize: number | null;
}

export interface JourneyOption {
  id: string;
  durationMin: number;
  walkMin: number;
  transfers: number;
  reliability: Reliability;
  dataQuality: DataQuality;
  legs: JourneyLeg[];
}

export interface TransitPlan {
  planId: string;
  recommendedLeaveAt: string | null;
  arrivalWindow: { from: string; to: string } | null;
  dataState: DataState;
  options: JourneyOption[];
}

export interface JourneyPlanRequest {
  origin: GeoPoint;
  destination: GeoPoint;
  timeMode: 'LEAVE_NOW' | 'DEPART_AT' | 'ARRIVE_BY';
  time?: string | null;
  preference?: 'BALANCED' | 'FASTEST' | 'LESS_WALKING' | 'FEWER_TRANSFERS' | 'RELIABLE';
  maxWalkMin?: number;
  extraSafetyMarginMin?: number;
}
