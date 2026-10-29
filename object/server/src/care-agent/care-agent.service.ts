import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import {
  CareEvents, CareStore, CaregiverSettings, GeoPoint, RiskEventRecord, RiskRecords, RiskWrite, SafeZone, StoredFix, TripChange,
} from '../care-api/public';
import { navigationAction, navigationReissue, planActions } from './risk-actions';
import { explainRisk } from './risk-explanation';
import {
  applyMet, DEMO_RISK_PARAMS, initialRiskState, RiskOutput, RiskState, riskStep, riskTick, RULE_VERSION,
} from './risk-rules';
import { DEMO_TRIP_PARAMS, Fix, initialState, step, tick, TrackerState, TripEvent } from './trip-recognition';

const CHUNK = 2000;
const CLOCK_CHECK_MS = 30_000;  // engineering architecture section 8: timed check every 30 s

const toFix = (p: StoredFix): Fix => ({ t: p.sampledAt.getTime(), latitude: p.latitude, longitude: p.longitude, accuracy: p.accuracy });
const toChange = (e: TripEvent): TripChange =>
  e.type === 'started' ? { type: 'started', startedAt: new Date(e.startedAt), startKnown: e.startKnown, stops: e.stops }
    : e.type === 'ended' ? { type: 'ended', endedAt: new Date(e.endedAt), stops: e.stops }
      : { type: 'stops', stops: e.stops };
const toWrite = (o: RiskOutput): RiskWrite => {
  switch (o.type) {
    case 'observation':
      return { type: 'observation', key: o.key, kind: o.kind, startedAt: new Date(o.startedAt), endedAt: o.endedAt === null ? null : new Date(o.endedAt),
        features: o.features, ruleVersion: RULE_VERSION, riskKey: o.riskKey };
    case 'opened':
      return { type: 'opened', key: o.key, anomaly: o.anomaly, anomalyStartedAt: new Date(o.anomalyStartedAt), at: new Date(o.at),
        minutes: o.minutes, tripStartedAt: o.tripStartedAt === null ? null : new Date(o.tripStartedAt) };
    case 'escalated':
      return { type: 'escalated', key: o.key, at: new Date(o.at), minutes: o.minutes };
    case 'resolved':
      return { type: 'resolved', key: o.key, at: new Date(o.at), resolution: o.resolution };
  }
};

// Historical replay records rule outcomes without performing the planned help. Describe those
// records directly rather than using the live-event template, which narrates outreach to the family.
function explainHistoricalRisk(event: RiskEventRecord, callName: string): string {
  const behavior = event.anomaly === 'wandering' ? 'wandering' : 'route deviation';
  const minutesAt = (at: Date) => Math.max(0, Math.floor((at.getTime() - event.anomalyStartedAt.getTime()) / 60_000));
  const parts = [
    `From the recorded locations, I detected ${behavior} for ${callName} and recorded low risk after ${minutesAt(event.openedAt)} minutes.`,
  ];
  if (event.escalatedAt) parts.push(`The recorded behavior continued, reaching high risk after ${minutesAt(event.escalatedAt)} minutes.`);
  if (event.resolvedAt) {
    parts.push(event.resolution === 'met'
      ? 'The risk record was resolved after a caregiver confirmed they had met.'
      : 'The recorded return home resolved the risk.');
  } else parts.push('The recorded risk remains unresolved.');
  parts.push('No notifications were sent and no navigation was started for this record.');
  return parts.join(' ');
}

// The care agent's runner: trip recognition and risk rules on stored fixes in sample-time order, the
// clock check, and "We've Met". One queue serialises every run, so trip and risk processing never race.
@Injectable()
export class CareAgentRunner implements OnModuleInit, OnModuleDestroy {
  private queue: Promise<void> = Promise.resolve();
  private timer?: NodeJS.Timeout;

  constructor(private readonly store: CareStore, private readonly risks: RiskRecords, private readonly events: CareEvents) {}

  onModuleInit(): void {
    this.events.onLocationsStored(({ elderId, replay }) => this.enqueue(() => this.processFixes(elderId, replay)));
    this.events.onDispositionSubmitted(e => (e.kind === 'met' ? this.enqueue(() => this.resolveMet(e.elderId, e.riskEventId)) : Promise.resolve()));
    this.timer = setInterval(() => void this.enqueue(() => this.checkClock(Date.now())).catch(() => undefined), CLOCK_CHECK_MS);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    clearInterval(this.timer);
  }

  private enqueue(work: () => Promise<void>): Promise<void> {
    const run = this.queue.then(work);
    this.queue = run.catch(error => console.error('Care agent run failed:', (error as Error).message));
    return run;
  }

  private async context(elderId: number): Promise<{ zones: SafeZone[]; routes: GeoPoint[][]; settings: CaregiverSettings }> {
    const [zones, routes, settings] = await Promise.all([
      this.store.safeZones(elderId), this.risks.referenceRoutes(elderId), this.risks.settings(elderId),
    ]);
    return { zones, routes, settings };
  }

  async processFixes(elderId: number, replayRequest = false): Promise<void> {
    const { zones, routes, settings } = await this.context(elderId);
    const record = await this.store.tracker(elderId);
    let trip = (record?.state as TrackerState | undefined) ?? initialState();
    let risk = (record?.riskState as RiskState | null | undefined) ?? initialRiskState();
    let through = record?.processedThrough ?? null;
    let historyReplay = record?.historyReplay ?? false;
    const touched = new Set<string>();
    for (;;) {
      const pending = await this.store.pointsAfter(elderId, through, CHUNK);
      if (!pending.length) break;
      historyReplay = pending[0].historyReplay ?? false;
      const boundary = pending.findIndex(p => (p.historyReplay ?? false) !== historyReplay);
      const fixes = boundary < 0 ? pending : pending.slice(0, boundary);
      const changes: TripChange[] = [];
      const outputs: RiskOutput[] = [];
      for (const stored of fixes) {
        const fix = toFix(stored);
        const t = step(trip, fix, zones, DEMO_TRIP_PARAMS);
        trip = t.state;
        changes.push(...t.events.map(toChange));
        const r = riskStep(risk, fix, { zones, routes, tripStartedAt: trip.trip?.startedAt ?? null });
        risk = r.state;
        outputs.push(...r.outputs);
      }
      through = fixes[fixes.length - 1].sampledAt;
      const result = await this.risks.recordEvaluation(elderId, {
        tracking: { changes, next: { phase: trip.phase, processedThrough: through, state: trip, historyReplay } },
        riskState: risk, writes: outputs.map(toWrite), actions: planActions(outputs, settings, historyReplay), historyReplay,
      });
      result.touched.forEach(id => touched.add(id));
      if (pending.length < CHUNK && boundary < 0) break;
    }
    // A repeated history request can arrive after live tracking resumed. Its empty replay must not
    // trigger wall-clock navigation renewal for that live tracker.
    if (historyReplay || replayRequest) await this.explain(elderId, touched);
    else await this.followUp(elderId, Date.now(), risk, settings, touched);
  }

  async checkClock(now: number): Promise<void> {
    for (const elderId of await this.store.trackedElderIds()) {
      const record = await this.store.tracker(elderId);
      if (!record || record.historyReplay) continue;
      const { zones, routes, settings } = await this.context(elderId);
      const trip = tick(record.state as TrackerState, now, zones, DEMO_TRIP_PARAMS);
      const riskBefore = (record.riskState as RiskState | null) ?? initialRiskState();
      const risk = riskTick(riskBefore, now, { zones, routes, tripStartedAt: trip.state.trip?.startedAt ?? null });
      const touched = new Set<string>();
      if (trip.events.length || risk.outputs.length) {
        const result = await this.risks.recordEvaluation(elderId, {
          tracking: trip.events.length
            ? { changes: trip.events.map(toChange), next: { phase: trip.state.phase, processedThrough: record.processedThrough, state: trip.state } }
            : undefined,
          riskState: risk.state, writes: risk.outputs.map(toWrite), actions: planActions(risk.outputs, settings),
        });
        result.touched.forEach(id => touched.add(id));
      }
      await this.followUp(elderId, now, risk.state, settings, touched);
    }
  }

  // "We've Met" from the caregiver phone: resolves the event at once, with or without fresh fixes.
  async resolveMet(elderId: number, eventId: string): Promise<void> {
    const event = await this.risks.riskEvent(elderId, eventId);
    if (event.status !== 'active') return;
    const now = Date.now();
    const record = await this.store.tracker(elderId);
    const before = (record?.riskState as RiskState | null | undefined) ?? initialRiskState();
    let { state, outputs } = applyMet(before, now);
    if (!outputs.length || (outputs[0].type === 'resolved' && outputs[0].key !== event.key)) {
      // The rule state lost track of this event: resolve the record as asked and keep the rest of the state.
      state = before;
      outputs = [{ type: 'resolved', key: event.key, anomaly: event.anomaly, level: event.level, at: now, resolution: 'met' }];
    }
    const settings = await this.risks.settings(elderId);
    const result = await this.risks.recordEvaluation(elderId, {
      riskState: state, writes: outputs.map(toWrite), actions: planActions(outputs, settings),
    });
    await this.explain(elderId, new Set(result.touched));
  }

  // After each run: re-evaluate lapsed navigation, then refresh explanations of the events this run touched.
  private async followUp(elderId: number, now: number, risk: RiskState, settings: CaregiverSettings, touched: Set<string>): Promise<void> {
    const active = await this.risks.activeRiskEvent(elderId);
    if (active) {
      touched.add(active.id);
      const latest = await this.risks.latestNavigation(active.id);
      const fixFresh = !!risk.lastFix && now - risk.lastFix.t <= DEMO_RISK_PARAMS.freshSeconds * 1000;
      const decision = navigationReissue(latest, now, { riskActive: true, autoNavigation: settings.autoNavigation, fixFresh });
      if (latest && (decision.expire || decision.issueSeq !== null)) {
        await this.risks.renewNavigation(elderId, decision.expire ? latest.id : null,
          decision.issueSeq !== null ? navigationAction(active.key, decision.issueSeq, now) : null);
      }
    }
    await this.explain(elderId, touched);
  }

  // The explanation is not a risk decision: a failure here never blocks the rules (section 9).
  private async explain(elderId: number, ids: Set<string>): Promise<void> {
    if (!ids.size) return;
    try {
      const { elder } = await this.store.household(elderId);
      for (const id of ids) {
        const event = await this.risks.riskEvent(elderId, id);
        const text = event.historyReplay ? explainHistoricalRisk(event, elder.callName)
          : explainRisk(event, await this.risks.activity(id), elder.callName);
        if (text !== event.explanation) await this.risks.saveExplanation(id, text);
      }
    } catch (error) { console.error('Risk explanation failed:', (error as Error).message); }
  }
}
