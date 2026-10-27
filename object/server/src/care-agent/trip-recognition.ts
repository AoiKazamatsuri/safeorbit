import { distanceMeters, GeoPoint, SafeZone } from '../care-api/public';

// Trip recognition rules (engineering architecture section 8). Pure: same fixes in, same trips out,
// timed by each fix's sample time so a replayed history gives the live result.
export interface TripParams {
  homeMarginMeters: number;          // hysteresis around the home radius
  leaveMinFixes: number;             // consecutive valid fixes outside home
  leaveMinSeconds: number;
  leaveMinDisplacementMeters: number; // from the first fix outside home
  arriveSettleSeconds: number;       // settled at home before the trip ends
  maxAccuracyMeters: number;         // data quality: coarser fixes are dropped
  maxSpeedMps: number;               // data quality: faster jumps are dropped
  timerFreshSeconds: number;         // the clock may end a trip only while fixes are recent
}

export const DEMO_TRIP_PARAMS: TripParams = {
  homeMarginMeters: 20, leaveMinFixes: 3, leaveMinSeconds: 60, leaveMinDisplacementMeters: 50,
  arriveSettleSeconds: 180, maxAccuracyMeters: 100, maxSpeedMps: 15, timerFreshSeconds: 900,
};

export const UNKNOWN_START = 'Unknown';
export const UNREGISTERED_PLACE = 'Out';

export interface Fix extends GeoPoint { t: number; accuracy: number | null }
export type Phase = 'unknown' | 'home' | 'leaving' | 'trip' | 'arriving';
export interface TrackerState {
  phase: Phase;
  lastFix: Fix | null;
  leaving: { first: Fix; count: number } | null;
  trip: { startedAt: number; startKnown: boolean; stops: string[] } | null;
  arrivingSince: number | null;
}
export type TripEvent =
  | { type: 'started'; startedAt: number; startKnown: boolean; stops: string[] }
  | { type: 'stops'; stops: string[] }
  | { type: 'ended'; endedAt: number; stops: string[] };

export const initialState = (): TrackerState => ({ phase: 'unknown', lastFix: null, leaving: null, trip: null, arrivingSince: null });

export function acceptsFix(state: TrackerState, fix: Fix, params: TripParams): boolean {
  return isAcceptableFix(state.lastFix, fix, params);
}

// Data quality (section 8 step 1), shared with the risk rules so both see the same fixes.
export function isAcceptableFix(last: Fix | null, fix: Fix, params: TripParams): boolean {
  if (fix.accuracy !== null && fix.accuracy > params.maxAccuracyMeters) return false;
  if (!last) return true;
  if (fix.t <= last.t) return false;
  return distanceMeters(last, fix) / ((fix.t - last.t) / 1000) <= params.maxSpeedMps;
}

export function step(state: TrackerState, fix: Fix, zones: SafeZone[], params: TripParams = DEMO_TRIP_PARAMS):
  { state: TrackerState; events: TripEvent[] } {
  const home = zones.find(z => z.isHome);
  if (!home || !acceptsFix(state, fix, params)) return { state, events: [] };
  const fromHome = distanceMeters(home.center, fix);
  const outside = fromHome > home.radiusMeters + params.homeMarginMeters;
  const inside = fromHome <= home.radiusMeters - params.homeMarginMeters;
  const next: TrackerState = { ...state, lastFix: fix };
  const events: TripEvent[] = [];

  const start = (startedAt: number, startKnown: boolean, first: string) => {
    next.trip = { startedAt, startKnown, stops: [first] };
    next.phase = 'trip'; next.leaving = null;
    events.push({ type: 'started', startedAt, startKnown, stops: [first] });
  };
  const end = (endedAt: number) => {
    events.push({ type: 'ended', endedAt, stops: finalStops(next.trip!.stops, home.name) });
    Object.assign(next, { phase: 'home', trip: null, arrivingSince: null });
  };

  switch (state.phase) {
    case 'unknown':
      // First enabled while already out: the start is unknown, never invented (product design 3.1).
      if (fromHome > home.radiusMeters) start(fix.t, false, UNKNOWN_START);
      else next.phase = 'home';
      break;
    case 'home':
      if (outside) { next.phase = 'leaving'; next.leaving = { first: fix, count: 1 }; }
      break;
    case 'leaving': {
      const leaving = state.leaving!;
      if (!outside) { next.phase = 'home'; next.leaving = null; break; }
      next.leaving = { first: leaving.first, count: leaving.count + 1 };
      if (next.leaving.count >= params.leaveMinFixes
        && fix.t - leaving.first.t >= params.leaveMinSeconds * 1000
        && distanceMeters(leaving.first, fix) >= params.leaveMinDisplacementMeters) {
        start(leaving.first.t, true, home.name);
      }
      break;
    }
    case 'trip':
      if (inside) { next.phase = 'arriving'; next.arrivingSince = fix.t; }
      break;
    case 'arriving':
      if (outside) { next.phase = 'trip'; next.arrivingSince = null; }
      else if (fix.t - state.arrivingSince! >= params.arriveSettleSeconds * 1000) end(state.arrivingSince!);
      break;
  }

  // Name the trip after the registered places it passes through.
  if (next.trip && (next.phase === 'trip' || next.phase === 'arriving')) {
    const zone = zones.find(z => !z.isHome && distanceMeters(z.center, fix) <= z.radiusMeters);
    const stops = next.trip.stops;
    if (zone && stops[stops.length - 1] !== zone.name) {
      next.trip = { ...next.trip, stops: [...stops, zone.name] };
      const started = events.find(e => e.type === 'started');
      if (started) started.stops = next.trip.stops;
      else events.push({ type: 'stops', stops: next.trip.stops });
    }
  }
  return { state: next, events };
}

// A trip that passed no registered place is named via "Out", e.g. Home–Out–Home.
function finalStops(stops: string[], homeName: string): string[] {
  return [...stops, ...(stops.length === 1 ? [UNREGISTERED_PLACE] : []), homeName];
}

// Clock check: ends a settled arrival when the phone stops reporting at home.
export function tick(state: TrackerState, now: number, zones: SafeZone[], params: TripParams = DEMO_TRIP_PARAMS):
  { state: TrackerState; events: TripEvent[] } {
  const home = zones.find(z => z.isHome);
  if (!home || state.phase !== 'arriving' || state.arrivingSince === null || !state.trip || !state.lastFix) return { state, events: [] };
  if (now - state.arrivingSince < params.arriveSettleSeconds * 1000) return { state, events: [] };
  if (now - state.lastFix.t > params.timerFreshSeconds * 1000) return { state, events: [] };
  return {
    state: { ...state, phase: 'home', trip: null, arrivingSince: null },
    events: [{ type: 'ended', endedAt: state.arrivingSince, stops: finalStops(state.trip.stops, home.name) }],
  };
}
