import { StoredFix, SafeZone } from './care-store';
import { bearingDegrees, distanceMeters, GeoPoint } from './geo';

// Shape decoded by the App as ElderLocationSnapshot; extra keys are ignored by the App.
export interface LocationSnapshot {
  coordinate: GeoPoint; recordedAt: string; heading: number | null; status: string;
  batteryPercent: number | null; address: null; trail: GeoPoint[];
  safeZones: Array<{ id: string; name: string; isHome: boolean; center: GeoPoint; radiusMeters: number }>;
  phase: string; tripName: string | null;
}

const MIN_HEADING_MOVE_M = 3;
export const tripName = (stops: string[]) => stops.join('–');

// latest is newest first. The bubble text only says where she is; risk wording arrives with T38.
export function buildSnapshot(input: {
  latest: StoredFix[]; phase: string; tripStops: string[] | null; trail: StoredFix[];
  zones: SafeZone[]; batteryPercent: number | null;
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
  };
}
