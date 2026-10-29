import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { test } from 'node:test';
import { CareEvents, DEFAULT_CAREGIVER_SETTINGS, distanceMeters, distanceToPolylineMeters, GeoPoint, RiskEventRecord, SafeZone, StoredFix, TrackerRecord } from '../src/care-api/public';
import { EvaluationWrite } from '../src/care-api/risk-records';
import { CareAgentRunner } from '../src/care-agent/care-agent.service';
import { navigationReissue, planActions } from '../src/care-agent/risk-actions';
import {
  applyMet, DEMO_RISK_PARAMS, walkedPathMeters, initialRiskState, RiskContext, RiskOutput, RiskState, riskStep, riskTick,
} from '../src/care-agent/risk-rules';
import { Fix } from '../src/care-agent/trip-recognition';

// Local frame in metres around home; the market is 600 m due south, the reference route runs straight between.
const ORIGIN: GeoPoint = { latitude: 32.06, longitude: 118.7665 };
const P = (east: number, north: number): GeoPoint => ({
  latitude: ORIGIN.latitude + north / 111_320,
  longitude: ORIGIN.longitude + east / (111_320 * Math.cos((ORIGIN.latitude * Math.PI) / 180)),
});
const HOME: SafeZone = { id: 'h', name: 'Home', isHome: true, center: P(0, 0), radiusMeters: 100 };
const MARKET: SafeZone = { id: 'm', name: 'Market', isHome: false, center: P(0, -600), radiusMeters: 100 };
const ROUTE = [P(0, 0), P(0, -600)];
const CTX: RiskContext = { zones: [HOME, MARKET], routes: [ROUTE], tripStartedAt: null };
const T0 = Date.UTC(2026, 9, 27, 1, 0, 0);
const STEP = 5;

// A track builder: walks at 1.2 m/s, loops on a 12 m circle at 1 m/s, or dwells; one fix every 5 s.
class Track {
  fixes: Fix[] = [];
  at: GeoPoint;
  s = 0;
  constructor(start: GeoPoint) { this.at = start; }
  private emit(p: GeoPoint) { this.s += STEP; this.fixes.push({ t: T0 + this.s * 1000, accuracy: 8, latitude: p.latitude, longitude: p.longitude }); }
  walk(to: GeoPoint, speed = 1.2): this {
    const from = this.at;
    const steps = Math.max(1, Math.ceil(distanceMeters(from, to) / (speed * STEP)));
    for (let i = 1; i <= steps; i++) {
      const f = i / steps;
      this.emit({ latitude: from.latitude + (to.latitude - from.latitude) * f, longitude: from.longitude + (to.longitude - from.longitude) * f });
    }
    this.at = to;
    return this;
  }
  loop(seconds: number, radius = 12): this {
    const c = this.at;
    const kx = 111_320 * Math.cos((c.latitude * Math.PI) / 180);
    for (let s = STEP; s <= seconds; s += STEP) {
      const a = (s * 1.0) / radius;  // 1 m/s along the circle
      this.emit({ latitude: c.latitude + (radius * Math.sin(a)) / 111_320, longitude: c.longitude + (radius * (Math.cos(a) - 1)) / kx });
    }
    return this;
  }
  dwell(seconds: number): this { for (let s = STEP; s <= seconds; s += STEP) this.emit(this.at); return this; }
  gap(seconds: number): this { this.s += seconds; return this; }
  get now(): number { return T0 + this.s * 1000; }
}

function run(fixes: Fix[], ctx: RiskContext = CTX, state: RiskState = initialRiskState()): { state: RiskState; outputs: RiskOutput[] } {
  const outputs: RiskOutput[] = [];
  for (const fix of fixes) { const r = riskStep(state, fix, ctx); state = r.state; outputs.push(...r.outputs); }
  return { state, outputs };
}
const transitions = (outputs: RiskOutput[]) => outputs.filter(o => o.type !== 'observation');
const observations = (outputs: RiskOutput[]) => outputs.filter(o => o.type === 'observation') as Extract<RiskOutput, { type: 'observation' }>[];
const ofType = <T extends RiskOutput['type']>(outputs: RiskOutput[], type: T) => outputs.filter(o => o.type === type) as Extract<RiskOutput, { type: T }>[];

// Home, walk 300 m toward the market, wander in a small loop, walk home, settle.
function wanderTrip(loopSeconds: number): { track: Track; loopStart: number; homeAt: number } {
  const track = new Track(HOME.center).dwell(60).walk(P(0, -300));
  const loopStart = track.now;
  track.loop(loopSeconds).walk(P(0, 0));
  const homeAt = track.fixes.find(f => f.t > loopStart && distanceMeters(HOME.center, f) <= 80)!.t;
  track.dwell(240);
  return { track, loopStart, homeAt };
}

// Deterministic noise (mulberry32 + Box-Muller), so jitter tests never flake.
function noise(seed: number): () => number {
  let a = seed >>> 0;
  const uniform = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return () => Math.sqrt(-2 * Math.log(1 - uniform())) * Math.cos(2 * Math.PI * uniform());
}
// One fix a second like a real iPhone: `at(s)` is the true position (east, north metres from home), plus
// Gaussian noise of `sd` metres per axis and a reported accuracy between 5 and 10 m.
function noisyFixes(seconds: number, at: (s: number) => [number, number], sd: number, seed: number): Fix[] {
  const gauss = noise(seed);
  return Array.from({ length: seconds }, (_, i) => {
    const [e, n] = at(i);
    const p = P(e + gauss() * sd, n + gauss() * sd);
    const accuracy = Math.min(10, Math.max(5, Math.round((7.5 + gauss() * 1.5) * 10) / 10));
    return { t: T0 + (i + 1) * 1000, accuracy, ...p };
  });
}

test('point-to-route distance is perpendicular inside a segment and to the end beyond it', () => {
  assert.ok(Math.abs(distanceToPolylineMeters(P(50, -300), ROUTE) - 50) < 0.5);
  assert.ok(Math.abs(distanceToPolylineMeters(P(0, -700), ROUTE) - 100) < 0.5);
});

test('wandering opens low risk 7 minutes and high risk 15 minutes after it started, and settling home resolves it', () => {
  const { track, loopStart, homeAt } = wanderTrip(17 * 60);
  const { state, outputs } = run(track.fixes);
  const [opened] = ofType(outputs, 'opened');
  const [escalated] = ofType(outputs, 'escalated');
  const [resolved] = ofType(outputs, 'resolved');
  assert.deepEqual(transitions(outputs).map(o => o.type), ['opened', 'escalated', 'resolved']);
  assert.equal(opened.anomaly, 'wandering');
  // The anomaly start is when the behaviour began (first fix of the first qualifying window), close to the loop start.
  assert.ok(opened.anomalyStartedAt >= loopStart - 30_000 && opened.anomalyStartedAt <= loopStart + 5_000, 'start near loop start');
  assert.ok(opened.at - opened.anomalyStartedAt >= 420_000 && opened.at - opened.anomalyStartedAt < 425_000);
  assert.equal(opened.minutes, 7);
  assert.ok(escalated.at - opened.anomalyStartedAt >= 900_000 && escalated.at - opened.anomalyStartedAt < 905_000);
  assert.equal(escalated.minutes, 15);
  assert.equal(resolved.resolution, 'home');
  assert.equal(resolved.level, 'high');
  assert.equal(resolved.at - homeAt, 180_000);
  assert.equal(state.risk, null);
  // One behaviour observation, tied to the risk, opened and later closed when she walked on.
  const obs = observations(outputs);
  assert.ok(obs.every(o => o.key === opened.key));
  assert.equal(obs.at(-1)!.riskKey, opened.key);
  assert.ok(obs.at(-1)!.endedAt! > opened.at && obs.at(-1)!.endedAt! <= loopStart + 17 * 60_000 + 60_000);
  assert.ok(obs[0].features.pathMeters > 150 && obs[0].features.netMeters < 35);
});

test('rules are timed by sample time: batching and wall-clock time do not change the result', () => {
  const { track } = wanderTrip(17 * 60);
  const whole = run(track.fixes).outputs;
  let state = initialRiskState();
  const split: RiskOutput[] = [];
  for (let i = 0; i < track.fixes.length; i += 7) {
    // Persisted between batches as JSON, as the runner does.
    const r = run(track.fixes.slice(i, i + 7), CTX, JSON.parse(JSON.stringify(state)));
    state = r.state; split.push(...r.outputs);
  }
  assert.deepEqual(split, whole);
  const DAY = 86_400_000;
  const shifted = run(track.fixes.map(f => ({ ...f, t: f.t + DAY }))).outputs;
  assert.deepEqual(transitions(shifted).map(o => (o as { at: number }).at - DAY), transitions(whole).map(o => (o as { at: number }).at));
});

test('wandering that stops before 7 minutes is an observation only, with no risk', () => {
  const short = new Track(HOME.center).dwell(60).walk(P(0, -300)).loop(5.5 * 60).walk(P(0, 0)).dwell(240);
  const { outputs } = run(short.fixes);
  assert.deepEqual(transitions(outputs), []);
  const obs = observations(outputs);
  assert.equal(obs.length, 2);  // opened, then closed
  assert.equal(obs[0].endedAt, null);
  assert.ok(obs[1].endedAt !== null && obs[1].riskKey === null);
  assert.ok(obs[1].features.durationSeconds < 420);
});

test('walking in circles inside a safe zone is never an anomaly', () => {
  const inMarket = new Track(HOME.center).dwell(60).walk(P(0, -600)).loop(25 * 60, 15).walk(P(0, 0)).dwell(240);
  assert.deepEqual(run(inMarket.fixes).outputs, []);
  const atHome = new Track(P(10, 10)).loop(25 * 60, 15);
  assert.deepEqual(run(atHome.fixes).outputs, []);
});

test('deviation: more than 80 m off the reference route for 5 minutes, low risk 7 minutes after leaving it', () => {
  const track = new Track(HOME.center).dwell(60).walk(P(0, -150)).walk(P(200, -150)).walk(P(200, -450)).walk(P(0, -150)).walk(P(0, 0)).dwell(240);
  const firstOff = track.fixes.find(f => distanceToPolylineMeters(f, ROUTE) > 80)!.t;
  const { outputs } = run(track.fixes);
  assert.deepEqual(transitions(outputs).map(o => o.type), ['opened', 'resolved']);
  const [opened] = ofType(outputs, 'opened');
  assert.equal(opened.anomaly, 'deviation');
  assert.equal(opened.anomalyStartedAt, firstOff);
  assert.ok(opened.at - firstOff >= 420_000 && opened.at - firstOff < 425_000);
  assert.ok(observations(outputs).every(o => o.kind === 'deviation'));
  // Without a reference route deviation is never judged.
  assert.deepEqual(run(track.fixes, { ...CTX, routes: [] }).outputs, []);
});

test('the clock check opens and escalates without new fixes, only while the newest fix is at most 5 minutes old', () => {
  const six = new Track(HOME.center).dwell(60).walk(P(0, -300)).loop(6 * 60);
  const { state, outputs } = run(six.fixes);
  assert.equal(observations(outputs).length, 1);
  const start = observations(outputs)[0].startedAt;
  const last = six.fixes.at(-1)!.t;
  assert.deepEqual(riskTick(state, start + 400_000, CTX).outputs, []);       // not yet 7 minutes
  const low = riskTick(state, start + 421_000, CTX);
  assert.deepEqual(transitions(low.outputs).map(o => o.type), ['opened']);
  assert.equal((low.outputs.find(o => o.type === 'opened') as { at: number }).at, start + 421_000);
  // A silent phone: newest fix more than 5 minutes old, the clock changes nothing.
  assert.deepEqual(riskTick(state, last + 301_000, CTX).outputs, []);

  const eleven = new Track(HOME.center).dwell(60).walk(P(0, -300)).loop(11 * 60);
  const r = run(eleven.fixes);
  const s = observations(r.outputs)[0].startedAt;
  const high = riskTick(r.state, s + 900_000, CTX);
  assert.deepEqual(transitions(high.outputs).map(o => o.type), ['escalated']);
  assert.equal(high.state.risk!.level, 'high');
  assert.deepEqual(riskTick(r.state, eleven.fixes.at(-1)!.t + 301_000, CTX).outputs, []);
});

test('high risk never steps down; low risk stays until resolved', () => {
  // High, then standing still outside any zone for 20 minutes: still high, not resolved.
  const high = new Track(HOME.center).dwell(60).walk(P(0, -300)).loop(16 * 60).walk(P(60, -300)).dwell(20 * 60);
  const h = run(high.fixes);
  assert.equal(h.state.risk!.level, 'high');
  assert.deepEqual(transitions(h.outputs).map(o => o.type), ['opened', 'escalated']);
  // Low, then the wandering stops: no escalation without an ongoing anomaly, and no resolution away from home.
  const low = new Track(HOME.center).dwell(60).walk(P(0, -300)).loop(8 * 60).walk(P(60, -300)).dwell(20 * 60);
  const l = run(low.fixes);
  assert.equal(l.state.risk!.level, 'warning');
  assert.deepEqual(transitions(l.outputs).map(o => o.type), ['opened']);
  assert.deepEqual(riskTick(l.state, low.fixes.at(-1)!.t + 60_000, CTX).outputs, []);
});

test('home resolves only after 180 s settled inside; stepping out restarts the count', () => {
  const t = new Track(HOME.center).dwell(60).walk(P(0, -300)).loop(8 * 60).walk(P(0, -60)).dwell(100).walk(P(0, -130));
  const out = t.fixes.length;
  t.walk(P(0, -60));
  const reentry = t.fixes.slice(out).find(f => distanceMeters(HOME.center, f) <= 80)!.t;
  t.dwell(240);
  const { state, outputs } = run(t.fixes);
  assert.deepEqual(transitions(outputs).map(o => o.type), ['opened', 'resolved']);
  const [resolved] = ofType(outputs, 'resolved');
  assert.equal(resolved.resolution, 'home');
  assert.equal(resolved.at, reentry + 180_000);
  assert.equal(state.risk, null);
  // The clock resolves a settled return while her phone still reports recently.
  const quiet = new Track(HOME.center).dwell(60).walk(P(0, -300)).loop(8 * 60).walk(P(0, 0)).dwell(30);
  const q = run(quiet.fixes);
  const since = q.state.risk!.homeSince!;
  assert.deepEqual(riskTick(q.state, since + 170_000, CTX).outputs, []);
  assert.deepEqual(ofType(riskTick(q.state, since + 180_000, CTX).outputs, 'resolved').map(o => o.resolution), ['home']);
});

test("We've Met resolves at once without fixes; the same anomaly never reopens a risk", () => {
  const t = new Track(HOME.center).dwell(60).walk(P(0, -300)).loop(16 * 60);
  const r = run(t.fixes);
  const met = applyMet(r.state, t.now + 3_600_000);  // phone silent for an hour: still resolves
  assert.deepEqual(met.outputs.map(o => o.type === 'resolved' && o.resolution), ['met']);
  assert.equal(met.state.risk, null);
  assert.deepEqual(applyMet(met.state, t.now).outputs, []);
  // She keeps wandering after they met: the consumed episode raises nothing.
  const more = new Track(t.at); more.s = t.s; more.loop(10 * 60);
  assert.deepEqual(transitions(run(more.fixes, CTX, met.state).outputs), []);
});

test('a gap of more than 5 minutes in the data breaks the anomaly; the clock of the next one restarts', () => {
  const t = new Track(HOME.center).dwell(60).walk(P(0, -300)).loop(6 * 60).gap(6 * 60);
  const afterGap = t.now;
  t.loop(10 * 60);
  const { outputs } = run(t.fixes);
  const obs = observations(outputs);
  const keys = [...new Set(obs.map(o => o.key))];
  assert.equal(keys.length, 2);
  const [opened] = ofType(outputs, 'opened');
  assert.ok(opened.anomalyStartedAt >= afterGap, 'the risk counts from the anomaly after the gap');
  assert.ok(obs.find(o => o.key === keys[0] && o.endedAt !== null), 'the first run ends at the gap');
});

test('each risk transition acts once; switches off suppress navigation and notifications but not the high alert', () => {
  const { track } = wanderTrip(17 * 60);
  const { outputs } = run(track.fixes);
  const on = planActions(outputs, DEFAULT_CAREGIVER_SETTINGS);
  assert.deepEqual(on.map(a => [a.kind, a.status]), [
    ['startNavigation', 'pending'], ['notifyLow', 'pending'], ['notifyHigh', 'pending'], ['notifyResolved', 'pending'],
  ]);
  assert.equal(new Set(on.map(a => a.idempotencyKey)).size, on.length);
  assert.deepEqual(planActions(outputs, DEFAULT_CAREGIVER_SETTINGS).map(a => a.idempotencyKey), on.map(a => a.idempotencyKey));
  assert.equal(on[0].expiresInSeconds, 120);
  assert.equal(on[1].details.navigation, true);
  const off = planActions(outputs, { autoNavigation: false, lowRiskNotifications: false, recoveryNotifications: false, limitedMonitoringNotifications: false });
  assert.deepEqual(off.map(a => [a.kind, a.status, a.reason]), [
    ['startNavigation', 'skipped', 'autoNavigationOff'], ['notifyLow', 'skipped', 'lowRiskNotificationsOff'],
    ['notifyHigh', 'pending', null], ['notifyResolved', 'skipped', 'recoveryNotificationsOff'],
  ]);
  assert.equal(off[1].details.navigation, false);
  const historical = planActions(outputs, DEFAULT_CAREGIVER_SETTINGS, true);
  assert.deepEqual(historical.map(a => [a.kind, a.status, a.reason, a.expiresInSeconds]), [
    ['startNavigation', 'skipped', 'historyReplay', null], ['notifyLow', 'skipped', 'historyReplay', null],
    ['notifyHigh', 'skipped', 'historyReplay', null], ['notifyResolved', 'skipped', 'historyReplay', null],
  ]);
  assert.deepEqual(historical.map(a => a.decidedAt), on.map(a => a.decidedAt));
});

function runnerHarness(points: StoredFix[]) {
  let tracker: TrackerRecord | null = null;
  let followUps = 0;
  const evaluations: EvaluationWrite[] = [];
  const store = {
    safeZones: async () => [HOME, MARKET],
    tracker: async () => tracker,
    trackedElderIds: async () => [1],
    pointsAfter: async (_id: number, after: Date | null, limit: number) => points.filter(p => !after || p.sampledAt > after).slice(0, limit),
  };
  const risks = {
    referenceRoutes: async () => [ROUTE], settings: async () => DEFAULT_CAREGIVER_SETTINGS,
    activeRiskEvent: async () => { followUps++; return null; },
    recordEvaluation: async (_id: number, input: EvaluationWrite) => {
      evaluations.push(input);
      if (input.tracking) tracker = { ...input.tracking.next, activeTripId: null,
        state: structuredClone(input.tracking.next.state), riskState: structuredClone(input.riskState) };
      return { touched: [] };
    },
  };
  const events = new CareEvents();
  return { runner: new CareAgentRunner(store as any, risks as any, events), events, evaluations,
    tracker: () => tracker, followUps: () => followUps };
}
const stored = (fixes: Fix[], historyReplay: boolean, shift = 0): StoredFix[] => fixes.map(f => ({
  sampledAt: new Date(f.t + shift), latitude: f.latitude, longitude: f.longitude, accuracy: f.accuracy,
  speed: null, course: null, historyReplay,
}));

test('runner replays two trips in one batch using each trip start, preserves sample times and never schedules live follow-up', async () => {
  const first = wanderTrip(17 * 60).track, second = wanderTrip(8 * 60).track;
  const points = [...stored(first.fixes, true), ...stored(second.fixes, true, 86_400_000)];
  const h = runnerHarness(points);
  await h.runner.processFixes(1);
  assert.equal(h.evaluations.length, 1, 'both trips fit in a single stored-point chunk');
  const input = h.evaluations[0];
  const starts = input.tracking!.changes.filter(c => c.type === 'started');
  const opened = input.writes.filter(w => w.type === 'opened');
  assert.equal(starts.length, 2);
  assert.deepEqual(opened.map(w => w.tripStartedAt), starts.map(c => c.startedAt));
  assert.equal(input.writes.filter(w => w.type === 'resolved').length, 2);
  assert.equal(input.writes.filter(w => w.type === 'escalated').length, 1);
  assert.ok(input.actions.every(a => a.status === 'skipped' && a.reason === 'historyReplay'));
  assert.ok(input.actions.every(a => a.decidedAt <= points.at(-1)!.sampledAt));
  assert.equal(h.tracker()!.historyReplay, true);
  await h.runner.processFixes(1); // duplicate upload after a persisted cursor produces nothing new
  await h.runner.checkClock(points.at(-1)!.sampledAt.getTime() + 60_000);
  assert.equal(h.evaluations.length, 1);
  assert.equal(h.followUps(), 0);
});

test('runner persists replay suppression even for a fresh active risk, then separates historical and live points in one read', async () => {
  const active = new Track(HOME.center).dwell(60).walk(P(0, -300)).loop(8 * 60);
  const history = runnerHarness(stored(active.fixes, true));
  await history.runner.processFixes(1);
  assert.ok(history.evaluations[0].writes.some(w => w.type === 'opened'));
  await history.runner.checkClock(active.now + 120_000);
  assert.equal(history.evaluations.length, 1, 'clock must not advance or resend historical actions');
  assert.equal(history.followUps(), 0);

  const completed = wanderTrip(8 * 60).track;
  const mixed = runnerHarness([...stored(completed.fixes, true), ...stored(active.fixes, false, 86_400_000)]);
  await mixed.runner.processFixes(1);
  assert.deepEqual(mixed.evaluations.map(e => e.historyReplay), [true, false]);
  assert.ok(mixed.evaluations[0].actions.every(a => a.status === 'skipped'));
  assert.ok(mixed.evaluations[1].actions.some(a => a.kind === 'startNavigation' && a.status === 'pending'));
  assert.equal(mixed.tracker()!.historyReplay, false);
  assert.equal(mixed.followUps(), 1);
  mixed.runner.onModuleInit();
  try {
    await mixed.events.publishLocationsStored({ elderId: 1, replay: true });
    assert.equal(mixed.evaluations.length, 2);
    assert.equal(mixed.followUps(), 1, 'repeating historical data after a live run must not renew live navigation');
  } finally { mixed.runner.onModuleDestroy(); }
});

test('historical explanations describe recorded risk without claiming alerts or navigation, including later live follow-up', async () => {
  const at = (minutes: number) => new Date(T0 + minutes * 60_000);
  for (const anomaly of ['wandering', 'deviation'] as const) {
    const event: RiskEventRecord = {
      id: '7', key: `${anomaly}:1`, tripId: '3', level: 'high', status: 'resolved', anomaly,
      anomalyStartedAt: at(0), openedAt: at(7), escalatedAt: at(15), resolvedAt: at(20), resolution: 'home',
      falseAlarm: false, explanation: null, version: 3, changedAt: at(20), historyReplay: true,
    };
    let saved = '';
    const store = {
      safeZones: async () => [HOME, MARKET], tracker: async () => null, pointsAfter: async () => [],
      household: async () => ({ elder: { callName: 'Grandma' } }),
    };
    const risks = {
      referenceRoutes: async () => [ROUTE], settings: async () => DEFAULT_CAREGIVER_SETTINGS,
      activeRiskEvent: async () => event, latestNavigation: async () => ({ id: '1', seq: 1, status: 'skipped', expiresAt: null }),
      riskEvent: async () => event, saveExplanation: async (_id: string, text: string) => { saved = text; },
      activity: async () => { assert.fail('the historical explanation does not call the live-event template'); },
    };
    const runner = new CareAgentRunner(store as any, risks as any, new CareEvents());
    // The durable event marker must protect explanations even when the current run is live.
    await runner.processFixes(1);
    assert.match(saved, /From the recorded locations, I detected (wandering|route deviation) for Grandma/);
    assert.match(saved, /low risk after 7 minutes/);
    assert.match(saved, /high risk after 15 minutes/);
    assert.match(saved, /recorded return home resolved the risk/);
    assert.match(saved, /No notifications were sent and no navigation was started/);
    assert.doesNotMatch(saved, /sent you an urgent alert|notified you|Navigation home started|I am still watching/);

    event.status = 'active'; event.resolvedAt = null; event.resolution = null;
    await runner.processFixes(1);
    assert.match(saved, /recorded risk remains unresolved/);
    assert.doesNotMatch(saved, /resolved the risk/);
  }
});

test('navigation that lapsed unanswered is re-issued while the risk is active and her phone reports', () => {
  const now = T0 + 1_000_000;
  const expired = { seq: 1, status: 'delivered', expiresAt: new Date(now - 1) };
  const live = { riskActive: true, autoNavigation: true, fixFresh: true };
  assert.deepEqual(navigationReissue(expired, now, live), { expire: true, issueSeq: 2 });
  assert.deepEqual(navigationReissue({ ...expired, status: 'pending' }, now, live), { expire: true, issueSeq: 2 });
  assert.deepEqual(navigationReissue({ ...expired, expiresAt: new Date(now + 1) }, now, live), { expire: false, issueSeq: null });
  for (const status of ['started', 'failed', 'cancelled', 'skipped']) {
    assert.deepEqual(navigationReissue({ ...expired, status }, now, live), { expire: false, issueSeq: null }, status);
  }
  assert.deepEqual(navigationReissue(expired, now, { ...live, fixFresh: false }), { expire: true, issueSeq: null });
  assert.deepEqual(navigationReissue({ ...expired, status: 'expired' }, now, live), { expire: false, issueSeq: 2 });
  assert.deepEqual(navigationReissue(expired, now, { ...live, autoNavigation: false }), { expire: true, issueSeq: null });
  assert.deepEqual(navigationReissue(expired, now, { ...live, riskActive: false }), { expire: false, issueSeq: null });
  assert.deepEqual(navigationReissue(null, now, live), { expire: false, issueSeq: null });
});

test('the Demo parameters are those of engineering architecture section 8', () => {
  const p = DEMO_RISK_PARAMS;
  assert.deepEqual([p.windowSeconds, p.wanderMinPathMeters, p.wanderMaxNetMeters, p.deviationMeters, p.deviationSeconds,
    p.lowAfterSeconds, p.highAfterSeconds, p.homeSettleSeconds, p.freshSeconds], [300, 150, 35, 80, 300, 420, 900, 180, 300]);
});

test('standing still with GPS jitter is not wandering', () => {
  // 15 minutes on a bench 300 m from home, on the route (so no deviation either), one fix a second.
  for (const [sd, seed] of [[2, 1], [3.5, 7], [5, 42]] as const) {
    const fixes = noisyFixes(15 * 60, () => [0, -300], sd, seed);
    const raw = fixes.slice(-300).slice(1).reduce((sum, f, i) => sum + distanceMeters(fixes[fixes.length - 300 + i], f), 0);
    assert.ok(raw > 150, `raw jitter path over 5 minutes (${Math.round(raw)} m) would have looked like wandering`);
    assert.ok(walkedPathMeters(fixes.slice(-300), DEMO_RISK_PARAMS.pathMinStepMeters, DEMO_RISK_PARAMS.pathSmoothingSeconds) < 150);
    const { outputs, state } = run(fixes);
    assert.deepEqual(outputs, [], `sd ${sd} m`);
    assert.equal(state.risk, null);
  }
});

test('a slow but genuine small loop still counts as wandering, also with jitter', () => {
  // 0.7 m/s round a 14 m circle, one noisy fix a second: low at 7 and high at 15 minutes after it began.
  const loop = (s: number): [number, number] => [14 * Math.cos((0.7 * s) / 14) - 14, -300 + 14 * Math.sin((0.7 * s) / 14)];
  const fixes = noisyFixes(16 * 60, loop, 1.5, 3);
  assert.ok(walkedPathMeters(fixes.slice(0, 300), DEMO_RISK_PARAMS.pathMinStepMeters, DEMO_RISK_PARAMS.pathSmoothingSeconds) > 150);
  const { outputs, state } = run(fixes);
  const [opened] = ofType(outputs, 'opened');
  const [escalated] = ofType(outputs, 'escalated');
  assert.equal(opened?.anomaly, 'wandering');
  assert.ok(opened.anomalyStartedAt <= fixes[0].t + 5_000);
  assert.ok(opened.at - opened.anomalyStartedAt >= 420_000 && opened.at - opened.anomalyStartedAt < 422_000);
  assert.ok(escalated.at - opened.anomalyStartedAt >= 900_000 && escalated.at - opened.anomalyStartedAt < 902_000);
  assert.equal(state.risk!.level, 'high');
});

test('the path ignores small moves and counts real steps', () => {
  // One fix every 10 s, so each fix is its own smoothing bucket.
  const at = (n: number, north: number, accuracy: number | null = 5): Fix => ({ t: T0 + n * 10_000, accuracy, ...P(0, -north) });
  const walk = (meters: number[], accuracy: number | null = 5) => walkedPathMeters(meters.map((m, i) => at(i, m, accuracy)), 10, 10);
  assert.equal(walkedPathMeters([], 10, 10), 0);
  assert.ok(Math.abs(walk([0, 4, 8, 12, 20]) - 12) < 0.1);   // the last 8 m wait for the next step
  assert.ok(Math.abs(walk([0, 12, 24]) - 24) < 0.1);
  assert.ok(Math.abs(walk([0, 12], null) - 12) < 0.1);
  assert.equal(walk([0, 12, 24], 30), 0);                      // coarse fixes cannot resolve 12 m steps
  // Ten fixes a second apart, alternating 6 m either side of one spot, average to a single point.
  const flicker = Array.from({ length: 60 }, (_, i) => ({ t: T0 + i * 1000, accuracy: 5, ...P(i % 2 ? 6 : -6, -300) }));
  assert.equal(walkedPathMeters(flicker, 10, 10), 0);
});

test('the home-wander-home demo track reaches low at 7 and high at 15 minutes and resolves at home', async () => {
  const dev = resolve(__dirname, '../../../dev');
  const importEsm = new Function('url', 'return import(url)') as (url: string) => Promise<any>;
  const { TRACKS, demoRoute } = await importEsm(pathToFileURL(resolve(dev, 'tracks.mjs')).href);
  const household = JSON.parse(readFileSync(resolve(dev, 'demo-household.json'), 'utf8'));
  const zones: SafeZone[] = household.safeZones.map((z: any, i: number) =>
    ({ id: String(i), name: z.name, isHome: z.name === 'Home', center: z.center, radiusMeters: z.radiusMeters }));
  const fixes: Fix[] = TRACKS['home-wander-home']().map((f: any) =>
    ({ t: T0 + f.offset * 1000, accuracy: f.accuracy, latitude: f.latitude, longitude: f.longitude }));
  const { outputs, state } = run(fixes, { zones, routes: [demoRoute()], tripStartedAt: null });
  assert.deepEqual(transitions(outputs).map(o => o.type), ['opened', 'escalated', 'resolved']);
  const [opened] = ofType(outputs, 'opened');
  const [escalated] = ofType(outputs, 'escalated');
  assert.equal(opened.anomaly, 'wandering');
  assert.ok(opened.at - opened.anomalyStartedAt >= 420_000 && opened.at - opened.anomalyStartedAt < 425_000);
  assert.ok(escalated.at - opened.anomalyStartedAt >= 900_000 && escalated.at - opened.anomalyStartedAt < 905_000);
  assert.equal(ofType(outputs, 'resolved')[0].resolution, 'home');
  assert.equal(state.risk, null);
});
