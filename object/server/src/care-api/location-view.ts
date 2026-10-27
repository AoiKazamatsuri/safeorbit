import { StoredFix, SafeZone } from './care-store';
import { bearingDegrees, distanceMeters, GeoPoint } from './geo';

// Shape decoded by the App as ElderLocationSnapshot; extra keys are ignored by the App.
export interface LocationSnapshot {
  coordinate: GeoPoint; recordedAt: string; heading: number | null; status: string;
  batteryPercent: number | null; address: null; trail: GeoPoint[];
  safeZones: Array<{ id: string; name: string; isHome: boolean; center: GeoPoint; radiusMeters: number }>;
  phase: string; tripName: string | null;
  // T38: risk as decided by the care agent, and the agent status line under her name.
  riskLevel: 'normal' | 'warning' | 'high';
  riskHeadline: string | null;            // e.g. "Wandering for 7 minutes"; null while normal
  riskAnomaly: 'wandering' | 'deviation' | null;
  riskSince: string | null;               // anomaly start of the active risk
  riskEventId: string | null;             // active risk event, else one resolved within the last 30 minutes
  riskEventStatus: 'active' | 'resolved' | null;
  agentStatus: string;                    // "Monitoring" or "Learning daily routes (n/5 trips)"
}

export interface SnapshotRisk {
  id: string; status: 'active' | 'resolved'; level: 'warning' | 'high'; anomaly: 'wandering' | 'deviation';
  anomalyStartedAt: Date; resolvedAt: Date | null;
}

export const ROUTE_LEARNING_TRIPS = 5;
export function agentStatusLine(riskFreeTrips: number): string {
  return riskFreeTrips >= ROUTE_LEARNING_TRIPS ? 'Monitoring' : `Learning daily routes (${riskFreeTrips}/${ROUTE_LEARNING_TRIPS} trips)`;
}

// Duration counts from the anomaly start, up to the resolution or now.
export function riskHeadline(anomaly: 'wandering' | 'deviation', since: Date, until: Date): string {
  const minutes = Math.max(0, Math.floor((until.getTime() - since.getTime()) / 60_000));
  const span = `${minutes} minute${minutes === 1 ? '' : 's'}`;
  return anomaly === 'wandering' ? `Wandering for ${span}` : `Off route for ${span}`;
}

const MIN_HEADING_MOVE_M = 3;
export const tripName = (stops: string[]) => stops.join('–');

// latest is newest first. status only says where she is; risk wording is in riskHeadline.
export function buildSnapshot(input: {
  latest: StoredFix[]; phase: string; tripStops: string[] | null; trail: StoredFix[];
  zones: SafeZone[]; batteryPercent: number | null;
  risk?: SnapshotRisk | null; riskFreeTrips?: number; now?: Date;
}): LocationSnapshot {
  const [now, before] = input.latest;
  const at: GeoPoint = { latitude: now.latitude, longitude: now.longitude };
  const home = input.zones.find(z => z.isHome);
  const visiting = input.zones.find(z => !z.isHome && distanceMeters(at, z.center) <= z.radiusMeters);
  const status = (input.phase === 'home' || input.phase === 'arriving') && home ? `At ${home.name}`
    : visiting ? `At ${visiting.name}` : 'Out';
  let heading: number | null = now.course;
  if (heading === null && before && distanceMeters(before, at) >= MIN_HEADING_MOVE_M) heading = bearingDegrees(before, at);
  return {
    coordinate: at, recordedAt: now.sampledAt.toISOString(), heading, status,
    batteryPercent: input.batteryPercent, address: null,
    trail: input.trail.map(p => ({ latitude: p.latitude, longitude: p.longitude })),
    safeZones: input.zones.map(z => ({ id: z.id, name: z.name, isHome: z.isHome, center: z.center, radiusMeters: z.radiusMeters })),
    phase: input.phase, tripName: input.tripStops ? tripName(input.tripStops) : null,
    ...riskFields(input.risk ?? null, input.now ?? new Date()),
    agentStatus: agentStatusLine(input.riskFreeTrips ?? 0),
  };
}

function riskFields(risk: SnapshotRisk | null, now: Date) {
  const active = risk?.status === 'active' ? risk : null;
  return {
    riskLevel: active ? active.level : 'normal' as const,
    riskHeadline: active ? riskHeadline(active.anomaly, active.anomalyStartedAt, now) : null,
    riskAnomaly: active ? active.anomaly : null,
    riskSince: active ? active.anomalyStartedAt.toISOString() : null,
    riskEventId: risk?.id ?? null,
    riskEventStatus: risk?.status ?? null,
  };
}
