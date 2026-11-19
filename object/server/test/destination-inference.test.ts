import assert from 'node:assert/strict';
import { test } from 'node:test';
import { DEFAULT_CAREGIVER_SETTINGS, GeoPoint, SafeZone, StoredFix } from '../src/care-api/public';
import { inferDestination, recentDestinationFixes } from '../src/care-agent/destination-inference';
import { planActions } from '../src/care-agent/risk-actions';
import { initialRiskState, RiskOutput, riskStep } from '../src/care-agent/risk-rules';
import { Fix } from '../src/care-agent/trip-recognition';

const origin = Date.UTC(2026, 10, 19);
const point = (x: number, y = 0): GeoPoint => ({ latitude: 32 + y / 111195, longitude: 118 + x / (111195 * Math.cos(32 * Math.PI / 180)) });
const zone = (id: string, x: number, y: number): SafeZone => ({ id, name: id, center: point(x, y), isHome: id === 'home', radiusMeters: 50 });
const zones = [zone('home', 0, 0), zone('market', 800, 0), zone('park', 350, 500)];
const routes = [
  { zoneId: 'market', points: [point(0), point(350), point(800)] },
  { zoneId: 'park', points: [point(0), point(350), point(350, 500)] },
];
const walk = (points: GeoPoint[], every = 10): Fix[] => points.map((p, i) => ({ ...p, accuracy: 5, t: origin + i * every * 1000 }));
const along = (...xs: number[]) => xs.map(x => point(x));
const stored = (f: Fix): StoredFix => ({ ...f, sampledAt: new Date(f.t), speed: null, course: null });
function read(fixes: Fix[], references = routes, now = fixes.at(-1)!.t) {
  return inferDestination(recentDestinationFixes(fixes.map(stored), fixes, now), zones, references, now);
}

test('shared road and first branch fixes stay unknown, then sustained progress selects the branch', () => {
  const shared = along(210, 233, 255, 280, 300, 325, 348);
  assert.equal(read(walk(shared)), undefined);
  const branch = [...shared, ...along(362, 376)];
  assert.equal(read(walk(branch)), undefined);
  assert.equal(read(walk([...branch, ...along(392, 408, 424)]))?.zoneId, 'market');
  assert.equal(read(walk([...shared, ...[12, 28, 44, 60, 76].map(y => point(350, y))]))?.zoneId, 'park');
  // Two almost parallel references offer no substantial advantage to either destination.
  const parallel = [{ zoneId: 'park', points: [point(0), point(350, 8), point(500, 8), point(350, 500)] }, routes[0]];
  assert.equal(read(walk(along(370, 390, 410, 430, 450)), parallel), undefined);
});

test('turning back immediately withdraws the old hint, then shows home and re-evaluates a new branch', () => {
  const outward = along(390, 406, 422, 438, 454);
  assert.equal(read(walk(outward))?.zoneId, 'market');
  assert.equal(read(walk([...outward, point(437)])), undefined);
  const returning = [...outward, ...along(437, 421, 405, 389, 373)];
  assert.equal(read(walk(returning))?.zoneId, 'home');
  const turning = [...returning, point(350), point(350, 17)];
  assert.equal(read(walk(turning)), undefined);
  assert.equal(read(walk([...turning, ...[34, 51, 68, 85].map(y => point(350, y))]))?.zoneId, 'park');
  assert.equal(read(walk(along(325, 307, 289, 271, 253, 235)))?.zoneId, 'home');
});

test('a brief stop retains evidence only until its sample-time deadline; repeated reads never renew it', () => {
  const fixes = walk(along(400, 416, 432, 448, 464));
  const t = fixes.at(-1)!.t;
  const expected = { zoneId: 'market', expiresAt: new Date(t + 45_000).toISOString() };
  assert.deepEqual(read(fixes), expected);
  assert.deepEqual(read(fixes, routes, t + 40_000), expected);
  assert.equal(read(fixes, routes, t + 45_000), undefined);
  const stopped = walk(along(400, 416, 432, 448, 464, 464, 466, 464, 467));
  assert.deepEqual(read(stopped), { zoneId: 'market', expiresAt: new Date(t + 60_000).toISOString() });
  assert.equal(read(stopped, routes, t + 60_000), undefined);
});

test('walking at one metre per second works with small steps; jitter, short runs and transverse crossings do not', () => {
  assert.equal(read(walk(Array.from({ length: 65 }, (_, i) => point(400 + i)), 1))?.zoneId, 'market');
  for (const samples of [along(400, 406, 398, 402, 405), along(400, 406, 415, 425),
    along(400, 420, 440), [-30, -15, 0, 15, 30].map(y => point(425, y)),
    [point(395, -24), point(409, -10), point(423, 4), point(437, 18)]]) {
    assert.equal(read(walk(samples), [routes[0]]), undefined);
  }
  assert.equal(read(walk([...along(400, 416, 432, 448), point(448, 19)]), [routes[0]]), undefined);
});

test('missing, degenerate, wrongly linked and moved reference endpoints leave the destination absent', () => {
  const fixes = walk(along(400, 416, 432, 448, 464));
  assert.equal(read(fixes, []), undefined);
  for (const points of [[], [point(450), point(450)], [point(100), point(800)], [point(0), point(600)],
    [point(800), point(0)], [point(0), { latitude: NaN, longitude: 118 }, point(800)]]) {
    assert.equal(read(fixes, [{ zoneId: 'market', points }]), undefined);
  }
  assert.equal(read(fixes, [{ ...routes[0], zoneId: 'deleted' }]), undefined);
});

test('only the current trip, accepted live fixes, and the latest continuous movement count', () => {
  const fixes = walk(along(400, 415, 430, 445, 460, 475, 490));
  const t = fixes.at(-1)!.t, trail = fixes.map(stored);
  assert.deepEqual(recentDestinationFixes(trail, undefined, t), []);
  assert.deepEqual(recentDestinationFixes(trail, fixes.slice(0, -1), t), []);
  assert.deepEqual(recentDestinationFixes(trail.slice(-3), fixes, t), []);
  const replay = trail.map((p, i) => ({ ...p, historyReplay: i === 3 }));
  assert.deepEqual(recentDestinationFixes(replay, fixes, t), []);
  assert.deepEqual(recentDestinationFixes(trail, fixes.map(f => ({ ...f, accuracy: 50 })), t), []);
  const interrupted = fixes.map((f, i) => ({ ...f, t: f.t + (i >= 4 ? 55_000 : 0) }));
  assert.equal(read(interrupted), undefined);
  const backfilled = [fixes[0], fixes[1], fixes[6]];
  assert.deepEqual(recentDestinationFixes(trail, backfilled, t), []);
});

test('location reads preserve wandering and deviation records, navigation and notifications on identical walks', () => {
  const walkAndDeviate = walk([...along(395, 410, 425, 440, 455),
    ...[20, 40, 60, 80, 100, 120].map(y => point(455, y)), ...Array<GeoPoint>(100).fill(point(455, 120))]);
  const walkAndWander = walk([...along(395, 410, 425, 440, 455), ...Array.from({ length: 115 }, (_, i) =>
    point(455 + 16 * Math.sin(i * 0.7), 16 * (1 - Math.cos(i * 0.7))))]);
  const compare = (samples: Fix[], readLocation: boolean) => {
    let risk = initialRiskState(), matched = false;
    const trail: StoredFix[] = [], outputs: RiskOutput[] = [];
    for (const f of samples) {
      const result = riskStep(risk, f, { zones, routes: routes.map(r => r.points), tripStartedAt: origin });
      risk = result.state;
      outputs.push(...result.outputs);
      if (readLocation) {
        trail.push(stored(f));
        const hint = inferDestination(recentDestinationFixes(trail, risk.window, f.t), zones, routes, f.t);
        if (hint) matched = true;
      }
    }
    assert.equal(matched, readLocation);
    return { outputs, actions: planActions(outputs, DEFAULT_CAREGIVER_SETTINGS), risk };
  };
  for (const [kind, samples] of [['deviation', walkAndDeviate], ['wandering', walkAndWander]] as const) {
    const baseline = compare(samples, false);
    assert.equal(baseline.risk.risk?.anomaly, kind);
    assert.deepEqual(baseline.actions.map(a => a.kind), ['startNavigation', 'notifyLow', 'notifyHigh']);
    assert.deepEqual(compare(samples, true), baseline);
  }
});
