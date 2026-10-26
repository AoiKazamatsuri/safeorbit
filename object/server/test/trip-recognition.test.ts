import assert from 'node:assert/strict';
import { test } from 'node:test';
import { distanceMeters, GeoPoint, SafeZone } from '../src/care-api/public';
import { Fix, initialState, step, tick, TrackerState, TripEvent } from '../src/care-agent/trip-recognition';

const HOME: SafeZone = { id: 'h', name: 'Home', isHome: true, center: { latitude: 32.06, longitude: 118.7665 }, radiusMeters: 100 };
const MARKET: SafeZone = { id: 'm', name: 'Market', isHome: false, center: { latitude: 32.056, longitude: 118.77 }, radiusMeters: 100 };
const PARK: GeoPoint = { latitude: 32.0635, longitude: 118.7700 };
const ZONES = [HOME, MARKET];
const T0 = Date.UTC(2026, 9, 26, 1, 0, 0);
const STEP_S = 5;

// Walks between points at 1.2 m/s, one fix every 5 s; dwell holds still.
function walk(from: GeoPoint, to: GeoPoint, startS: number): Fix[] {
  const seconds = Math.ceil(distanceMeters(from, to) / 1.2);
  const fixes: Fix[] = [];
  for (let s = STEP_S; s <= seconds; s += STEP_S) {
    const f = s / seconds;
    fixes.push({ t: T0 + (startS + s) * 1000, accuracy: 10,
      latitude: from.latitude + (to.latitude - from.latitude) * f, longitude: from.longitude + (to.longitude - from.longitude) * f });
  }
  return fixes;
}
function dwell(at: GeoPoint, startS: number, seconds: number): Fix[] {
  return Array.from({ length: Math.floor(seconds / STEP_S) }, (_, i) =>
    ({ t: T0 + (startS + (i + 1) * STEP_S) * 1000, accuracy: 10, latitude: at.latitude, longitude: at.longitude }));
}
function chain(start: GeoPoint, legs: Array<['walk', GeoPoint] | ['dwell', number]>): Fix[] {
  let at = start; let s = 0; const all: Fix[] = [];
  for (const [kind, arg] of legs) {
    const part = kind === 'walk' ? walk(at, arg, s) : dwell(at, s, arg);
    if (kind === 'walk') at = arg;
    all.push(...part);
    s = (all[all.length - 1].t - T0) / 1000;
  }
  return all;
}
function run(fixes: Fix[], state: TrackerState = initialState()): { state: TrackerState; events: TripEvent[] } {
  const events: TripEvent[] = [];
  for (const fix of fixes) { const r = step(state, fix, ZONES); state = r.state; events.push(...r.events); }
  return { state, events };
}
const ended = (events: TripEvent[]) => events.filter(e => e.type === 'ended') as Extract<TripEvent, { type: 'ended' }>[];

test('a walk from home to the market and back is one trip named Home–Market–Home', () => {
  const fixes = chain(HOME.center, [['dwell', 120], ['walk', MARKET.center], ['dwell', 300], ['walk', HOME.center], ['dwell', 240]]);
  const { state, events } = run(fixes);
  const started = events.filter(e => e.type === 'started');
  assert.equal(started.length, 1);
  assert.deepEqual(ended(events).map(e => e.stops), [['Home', 'Market', 'Home']]);
  assert.equal(state.phase, 'home');
  // The trip starts at the first fix beyond the home margin and ends at the first fix well inside.
  const firstOut = fixes.find(f => distanceMeters(HOME.center, f) > 120)!;
  assert.equal((started[0] as { startedAt: number }).startedAt, firstOut.t);
  const back = fixes.filter(f => f.t > firstOut.t + 600_000).find(f => distanceMeters(HOME.center, f) <= 80)!;
  assert.equal(ended(events)[0].endedAt, back.t);
});

test('a short step outside the home zone does not start a trip', () => {
  const edge = { latitude: 32.0612, longitude: 118.7665 };  // about 133 m north, just past the margin
  const fixes = chain(HOME.center, [['dwell', 60], ['walk', edge], ['walk', HOME.center], ['dwell', 60]]);
  assert.deepEqual(run(fixes).events, []);
});

test('fixes hovering around the home radius do not flap', () => {
  const near = (m: number) => ({ latitude: 32.06 + m / 111_320, longitude: 118.7665 });
  const fixes = [90, 110, 95, 115, 105, 85, 112].map((m, i) => ({ t: T0 + i * 30_000, accuracy: 10, ...near(m) }));
  const { state, events } = run(fixes);
  assert.deepEqual(events, []);
  assert.equal(state.phase, 'home');
});

test('first enabled while already out: the start is unknown and the trip is named after it', () => {
  const fixes = chain(PARK, [['dwell', 30], ['walk', HOME.center], ['dwell', 240]]);
  const { events } = run(fixes);
  assert.deepEqual(events[0], { type: 'started', startedAt: fixes[0].t, startKnown: false, stops: ['Unknown'] });
  assert.deepEqual(ended(events).map(e => e.stops), [['Unknown', 'Out', 'Home']]);
});

test('a trip through no registered place is named Home–Out–Home', () => {
  const fixes = chain(HOME.center, [['dwell', 60], ['walk', PARK], ['dwell', 120], ['walk', HOME.center], ['dwell', 240]]);
  assert.deepEqual(ended(run(fixes).events).map(e => e.stops), [['Home', 'Out', 'Home']]);
});

test('turning back before settling at home keeps the same trip', () => {
  // 70 m from home toward the market: inside the home zone, but she turns back after 30 s.
  const f = 70 / distanceMeters(HOME.center, MARKET.center);
  const doorstep = { latitude: HOME.center.latitude + (MARKET.center.latitude - HOME.center.latitude) * f,
    longitude: HOME.center.longitude + (MARKET.center.longitude - HOME.center.longitude) * f };
  const fixes = chain(HOME.center, [
    ['dwell', 60], ['walk', MARKET.center], ['walk', doorstep], ['dwell', 30], ['walk', MARKET.center], ['walk', HOME.center], ['dwell', 240],
  ]);
  const { events } = run(fixes);
  assert.equal(events.filter(e => e.type === 'started').length, 1);
  assert.deepEqual(ended(events).map(e => e.stops), [['Home', 'Market', 'Home']]);
});

test('coarse, jumping and out-of-order fixes are ignored', () => {
  const home = chain(HOME.center, [['dwell', 60]]);
  const last = home[home.length - 1];
  const far = { latitude: MARKET.center.latitude, longitude: MARKET.center.longitude };
  const noisy: Fix[] = [
    { ...far, t: last.t + 5_000, accuracy: 500 },        // too coarse
    { ...far, t: last.t + 10_000, accuracy: 10 },        // ~550 m in 10 s
    { ...HOME.center, t: last.t - 5_000, accuracy: 10 }, // older than the last fix
  ];
  const { state, events } = run([...home, ...noisy]);
  assert.deepEqual(events, []);
  assert.equal(state.phase, 'home');
  assert.equal(state.lastFix!.t, last.t);
});

test('the clock ends a settled arrival only while fixes are recent', () => {
  const fixes = chain(HOME.center, [['dwell', 60], ['walk', PARK], ['walk', HOME.center], ['dwell', 20]]);
  const { state } = run(fixes);
  assert.equal(state.phase, 'arriving');
  const settled = state.arrivingSince! + 181_000;
  assert.deepEqual(tick(state, state.arrivingSince! + 60_000, ZONES).events, []);
  const result = tick(state, settled, ZONES);
  assert.deepEqual(result.events, [{ type: 'ended', endedAt: state.arrivingSince!, stops: ['Home', 'Out', 'Home'] }]);
  assert.equal(result.state.phase, 'home');
  // A replayed history is far in the past: the clock leaves it to later fixes.
  assert.deepEqual(tick(state, settled + 3_600_000, ZONES).events, []);
});

test('the same fixes always give the same trips', () => {
  const fixes = chain(HOME.center, [['dwell', 60], ['walk', MARKET.center], ['dwell', 60], ['walk', HOME.center], ['dwell', 240]]);
  assert.deepEqual(run(fixes).events, run(fixes).events);
});
