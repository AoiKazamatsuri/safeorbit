import { distanceMeters, distanceToPolylineMeters, GeoPoint, SafeZone } from '../care-api/public';
import { DEMO_TRIP_PARAMS, Fix, isAcceptableFix, TripParams } from './trip-recognition';

// Risk rules (engineering architecture section 8, steps 3 and 4). Pure: the same fixes give the same
// observations and risk transitions, timed by each fix's sample time so a replay matches a live run.
//
// Definitions used throughout:
// - A fix is "abnormal" for a kind when that kind's condition holds at the fix. Nothing is abnormal while
//   the fix is inside any safe zone (home included): a safe zone is a familiar place, not a fence.
//   * Wandering: over the 5-minute window ending at the fix (and covering at least windowMinSpanSeconds of
//     it), the walked path is longer than 150 m while the net displacement from the window's first fix to
//     this fix is under 35 m.
//   * Deviation: the fix has been more than 80 m from the nearest reference route for at least 5 minutes
//     without a break. Never judged when there is no reference route.
// - An anomaly (episode) starts at the first abnormal fix of a run. Its start time is the time the behaviour
//   began, not when it was recognised: for wandering, the first fix of the first qualifying window; for
//   deviation, the first fix more than 80 m off route. Durations ("Wandering for 7 minutes") count from it.
// - An anomaly ends at its last abnormal fix, once fixes have been normal for anomalyEndGraceSeconds, or at
//   once when she enters a safe zone, or when the data has a gap longer than freshSeconds (interrupted data
//   breaks continuity; it neither raises nor resolves risk). Each episode is one behaviour observation.
// - Risk: an ongoing episode (abnormal at its latest fix, not in its end grace) not yet tied to a risk opens a
//   low risk (warning) once it has lasted 7 minutes from its start. While any anomaly is still ongoing, the
//   risk becomes high 15 minutes after the triggering anomaly's start. High never goes back to low; low stays until resolved. Every episode open while a risk is active is
//   tied to it and can never open another risk.
// - Resolution: back inside home (radius minus margin) and staying normal there for 180 s, or the caregiver's
//   "We've Met" (applyMet). Answering a call or reading a notification resolves nothing.
export const RULE_VERSION = 'demo-1';

export interface RiskParams {
  windowSeconds: number;
  windowMinSpanSeconds: number;      // a shorter window is not judged yet
  wanderMinPathMeters: number;
  wanderMaxNetMeters: number;
  deviationMeters: number;
  deviationSeconds: number;
  anomalyEndGraceSeconds: number;
  lowAfterSeconds: number;
  highAfterSeconds: number;
  homeMarginMeters: number;
  homeSettleSeconds: number;
  freshSeconds: number;              // the clock advances only while the newest fix is this recent; longer gaps break runs
}

export const DEMO_RISK_PARAMS: RiskParams = {
  windowSeconds: 300, windowMinSpanSeconds: 270, wanderMinPathMeters: 150, wanderMaxNetMeters: 35,
  deviationMeters: 80, deviationSeconds: 300, anomalyEndGraceSeconds: 60,
  lowAfterSeconds: 420, highAfterSeconds: 900, homeMarginMeters: 20, homeSettleSeconds: 180, freshSeconds: 300,
};

export type AnomalyKind = 'wandering' | 'deviation';
export type RiskLevel = 'warning' | 'high';
const KINDS: AnomalyKind[] = ['wandering', 'deviation'];

export interface Episode {
  key: string; kind: AnomalyKind; startedAt: number; lastAbnormalAt: number; normalSince: number | null;
  features: Record<string, number>; riskKey: string | null;
}
export interface ActiveRisk {
  key: string; level: RiskLevel; anomaly: AnomalyKind; anomalyStartedAt: number; openedAt: number; homeSince: number | null;
}
export interface RiskState {
  lastFix: Fix | null;
  window: Fix[];                     // accepted fixes of the last windowSeconds
  offRouteSince: number | null;
  episodes: Partial<Record<AnomalyKind, Episode>>;
  risk: ActiveRisk | null;
  lastAt: number | null;             // latest decision time, keeps transition times in order
}
export interface RiskContext { zones: SafeZone[]; routes: GeoPoint[][]; tripStartedAt: number | null }

export type RiskOutput =
  | { type: 'observation'; key: string; kind: AnomalyKind; startedAt: number; endedAt: number | null;
      features: Record<string, number>; riskKey: string | null }
  | { type: 'opened'; key: string; anomaly: AnomalyKind; anomalyStartedAt: number; at: number; minutes: number; tripStartedAt: number | null }
  | { type: 'escalated'; key: string; anomaly: AnomalyKind; anomalyStartedAt: number; at: number; minutes: number }
  | { type: 'resolved'; key: string; anomaly: AnomalyKind; level: RiskLevel; at: number; resolution: 'home' | 'met' };

export const initialRiskState = (): RiskState =>
  ({ lastFix: null, window: [], offRouteSince: null, episodes: {}, risk: null, lastAt: null });

const clone = (s: RiskState): RiskState => ({
  ...s, window: [...s.window], risk: s.risk && { ...s.risk },
  episodes: Object.fromEntries(Object.entries(s.episodes).map(([k, e]) => [k, { ...e!, features: { ...e!.features } }])),
});
const minutesBetween = (from: number, to: number) => Math.floor((to - from) / 60_000);
const observation = (e: Episode, endedAt: number | null): RiskOutput =>
  ({ type: 'observation', key: e.key, kind: e.kind, startedAt: e.startedAt, endedAt, features: { ...e.features }, riskKey: e.riskKey });

function closeEpisode(s: RiskState, kind: AnomalyKind, out: RiskOutput[]): void {
  const e = s.episodes[kind];
  if (!e) return;
  e.features.durationSeconds = Math.round((e.lastAbnormalAt - e.startedAt) / 1000);
  out.push(observation(e, e.lastAbnormalAt));
  delete s.episodes[kind];
}

interface Detection { start: number; features: Record<string, number> }

function wandering(s: RiskState, fix: Fix, p: RiskParams): Detection | null {
  const w = s.window;
  if (fix.t - w[0].t < p.windowMinSpanSeconds * 1000) return null;
  let path = 0;
  for (let i = 1; i < w.length; i++) path += distanceMeters(w[i - 1], w[i]);
  const net = distanceMeters(w[0], fix);
  if (path <= p.wanderMinPathMeters || net >= p.wanderMaxNetMeters) return null;
  return { start: w[0].t, features: { pathMeters: Math.round(path), netMeters: Math.round(net), windowSeconds: Math.round((fix.t - w[0].t) / 1000) } };
}

function advance(s: RiskState, kind: AnomalyKind, found: Detection | null, t: number, inZone: boolean, p: RiskParams, out: RiskOutput[]): void {
  const e = s.episodes[kind];
  if (found) {
    if (!e) {
      const opened: Episode = { key: `${kind}:${found.start}`, kind, startedAt: found.start, lastAbnormalAt: t, normalSince: null,
        features: { ...found.features }, riskKey: s.risk?.key ?? null };
      s.episodes[kind] = opened;
      out.push(observation(opened, null));
    } else {
      e.lastAbnormalAt = t; e.normalSince = null;
      if (kind === 'wandering') e.features.peakPathMeters = Math.max(e.features.peakPathMeters ?? 0, found.features.pathMeters);
      else e.features.maxDistanceMeters = Math.max(e.features.maxDistanceMeters ?? 0, found.features.distanceMeters);
    }
  } else if (e) {
    e.normalSince ??= t;
    if (inZone || t - e.normalSince >= p.anomalyEndGraceSeconds * 1000) closeEpisode(s, kind, out);
  }
}

// Opens, escalates and resolves the risk at decision time `at` (a fix's sample time or the clock).
function assess(s: RiskState, now: number, ctx: RiskContext, p: RiskParams, out: RiskOutput[]): void {
  const at = Math.max(now, s.lastAt ?? now);
  const open = KINDS.map(k => s.episodes[k]).filter((e): e is Episode => !!e);
  const ongoing = open.filter(e => e.normalSince === null);
  if (!s.risk) {
    const trigger = ongoing.filter(e => !e.riskKey && at - e.startedAt >= p.lowAfterSeconds * 1000)
      .sort((a, b) => a.startedAt - b.startedAt)[0];
    if (trigger) {
      s.risk = { key: trigger.key, level: 'warning', anomaly: trigger.kind, anomalyStartedAt: trigger.startedAt, openedAt: at, homeSince: null };
      out.push({ type: 'opened', key: trigger.key, anomaly: trigger.kind, anomalyStartedAt: trigger.startedAt, at,
        minutes: minutesBetween(trigger.startedAt, at), tripStartedAt: ctx.tripStartedAt });
    }
  }
  const risk = s.risk;
  if (!risk) { s.lastAt = at; return; }
  for (const e of open) {
    if (e.riskKey) continue;
    e.riskKey = risk.key;
    out.push(observation(e, null));
  }
  if (risk.level === 'warning' && ongoing.length && at - risk.anomalyStartedAt >= p.highAfterSeconds * 1000) {
    risk.level = 'high';
    out.push({ type: 'escalated', key: risk.key, anomaly: risk.anomaly, anomalyStartedAt: risk.anomalyStartedAt, at,
      minutes: minutesBetween(risk.anomalyStartedAt, at) });
  }
  if (risk.homeSince !== null && at - risk.homeSince >= p.homeSettleSeconds * 1000) {
    out.push({ type: 'resolved', key: risk.key, anomaly: risk.anomaly, level: risk.level, at, resolution: 'home' });
    s.risk = null;
  }
  s.lastAt = at;
}

// A new accepted fix. Fixes failing the shared data-quality filter change nothing.
export function riskStep(state: RiskState, fix: Fix, ctx: RiskContext, p: RiskParams = DEMO_RISK_PARAMS,
  quality: TripParams = DEMO_TRIP_PARAMS): { state: RiskState; outputs: RiskOutput[] } {
  if (!isAcceptableFix(state.lastFix, fix, quality)) return { state, outputs: [] };
  const s = clone(state);
  const out: RiskOutput[] = [];
  if (s.lastFix && fix.t - s.lastFix.t > p.freshSeconds * 1000) {
    // Interrupted data: runs and settling restart from the next fixes; an active risk stays as it is.
    for (const kind of KINDS) closeEpisode(s, kind, out);
    s.window = []; s.offRouteSince = null;
    if (s.risk) s.risk.homeSince = null;
  }
  s.lastFix = fix;
  s.window = [...s.window.filter(f => f.t >= fix.t - p.windowSeconds * 1000), fix];
  const inZone = ctx.zones.some(z => distanceMeters(z.center, fix) <= z.radiusMeters);

  const wander = inZone ? null : wandering(s, fix, p);
  let deviation: Detection | null = null;
  const routes = ctx.routes.filter(r => r.length >= 2);
  if (inZone || !routes.length) s.offRouteSince = null;
  else {
    const off = Math.min(...routes.map(r => distanceToPolylineMeters(fix, r)));
    if (off > p.deviationMeters) {
      s.offRouteSince ??= fix.t;
      if (fix.t - s.offRouteSince >= p.deviationSeconds * 1000) {
        deviation = { start: s.offRouteSince, features: { distanceMeters: Math.round(off), thresholdMeters: p.deviationMeters } };
      }
    } else s.offRouteSince = null;
  }
  advance(s, 'wandering', wander, fix.t, inZone, p, out);
  advance(s, 'deviation', deviation, fix.t, inZone, p, out);

  const home = ctx.zones.find(z => z.isHome);
  if (s.risk && home) {
    const d = distanceMeters(home.center, fix);
    if (d <= home.radiusMeters - p.homeMarginMeters) s.risk.homeSince ??= fix.t;
    else if (d > home.radiusMeters + p.homeMarginMeters) s.risk.homeSince = null;
  }
  assess(s, fix.t, ctx, p, out);
  return { state: s, outputs: out };
}

// Clock check (every 30 s): advances escalation and resolution without new fixes, but only while the newest
// fix is at most freshSeconds old, so a silent phone neither raises nor resolves risk.
export function riskTick(state: RiskState, now: number, ctx: RiskContext, p: RiskParams = DEMO_RISK_PARAMS):
  { state: RiskState; outputs: RiskOutput[] } {
  if (!state.lastFix || now - state.lastFix.t > p.freshSeconds * 1000 || now < state.lastFix.t) return { state, outputs: [] };
  const s = clone(state);
  const out: RiskOutput[] = [];
  for (const kind of KINDS) {
    const e = s.episodes[kind];
    if (e?.normalSince != null && now - e.normalSince >= p.anomalyEndGraceSeconds * 1000) closeEpisode(s, kind, out);
  }
  assess(s, now, ctx, p, out);
  return out.length ? { state: s, outputs: out } : { state, outputs: [] };
}

// The caregiver's "We've Met": resolves at once, whether or not the elder phone is reporting.
export function applyMet(state: RiskState, at: number): { state: RiskState; outputs: RiskOutput[] } {
  if (!state.risk) return { state, outputs: [] };
  const s = clone(state);
  const risk = s.risk!;
  const when = Math.max(at, s.lastAt ?? at);
  s.risk = null; s.lastAt = when;
  return { state: s, outputs: [{ type: 'resolved', key: risk.key, anomaly: risk.anomaly, level: risk.level, at: when, resolution: 'met' }] };
}
