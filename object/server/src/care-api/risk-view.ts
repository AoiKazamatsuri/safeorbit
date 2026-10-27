import { StoredFix } from './care-store';
import { GeoPoint } from './geo';
import { riskHeadline } from './location-view';
import { ActionRecord, RiskActivity, RiskEventRecord } from './risk-records';

// Risk event page (product design 5.3) in the shape the App decodes. Texts are English for the Demo;
// the "kind" fields let the App localise later without server changes.
export interface TimelineItem { at: string; kind: string; text: string }
export interface HelpItem { kind: 'navigation' | 'lowRiskNotification' | 'highRiskAlert' | 'resolvedNotification'; status: string; text: string; at: string }
export interface RiskEventDetail {
  id: string; level: 'warning' | 'high'; status: 'active' | 'resolved'; anomaly: 'wandering' | 'deviation';
  headline: string; durationMinutes: number;
  anomalyStartedAt: string; openedAt: string; escalatedAt: string | null; resolvedAt: string | null;
  resolution: 'home' | 'met' | null; falseAlarm: boolean; canMarkFalseAlarm: boolean;
  explanation: string | null;
  coordinate: GeoPoint | null; recordedAt: string | null; trail: GeoPoint[];
  help: HelpItem[]; timeline: TimelineItem[];
  transitions: Array<{ seq: number; kind: string; fromLevel: string | null; toLevel: string | null; at: string }>;
  actions: Array<{
    id: string; type: string; status: string; reason: string | null; decidedAt: string; createdAt: string;
    expiresAt: string | null; deliveredAt: string | null; resultAt: string | null;
    deliveries: Array<{ channel: string; result: string; detail: string | null; at: string }>;
  }>;
  observations: Array<{ kind: string; startedAt: string; endedAt: string | null; features: Record<string, number> }>;
}

export interface RiskEventSummary {
  id: string; level: 'warning' | 'high'; status: 'active' | 'resolved'; anomaly: 'wandering' | 'deviation';
  anomalyStartedAt: string; openedAt: string; escalatedAt: string | null; resolvedAt: string | null;
  resolution: 'home' | 'met' | null; falseAlarm: boolean;
}

const iso = (d: Date | null) => (d ? d.toISOString() : null);
const anomalyName = (a: string) => (a === 'wandering' ? 'wandering' : 'off route');

export function riskSummary(e: RiskEventRecord): RiskEventSummary {
  return {
    id: e.id, level: e.level, status: e.status, anomaly: e.anomaly, anomalyStartedAt: e.anomalyStartedAt.toISOString(),
    openedAt: e.openedAt.toISOString(), escalatedAt: iso(e.escalatedAt), resolvedAt: iso(e.resolvedAt),
    resolution: e.resolution, falseAlarm: e.falseAlarm,
  };
}

const PUSH_LABEL: Record<string, [HelpItem['kind'], string]> = {
  notifyLow: ['lowRiskNotification', 'Low-risk notification'],
  notifyHigh: ['highRiskAlert', 'Urgent alert'],
  notifyResolved: ['resolvedNotification', 'Risk-resolved notification'],
};
const PUSH_OUTCOME: Record<string, string> = {
  pending: 'sending', sending: 'sending', sent: 'sent', failed: 'could not be delivered',
  notConfigured: 'not sent: push is not configured', noRecipient: 'not sent: no family phone is registered for notifications',
  skipped: 'switched off in settings',
};
const NAVIGATION_TEXT: Record<string, string> = {
  pending: 'Navigation home requested on her phone', delivered: 'Navigation home sent to her phone',
  started: 'Navigation home started', failed: 'Navigation home could not start',
  expired: 'No answer from her phone; navigation request expired', cancelled: 'Navigation request withdrawn: risk resolved',
  skipped: 'Automatic navigation is off',
};

function helpItems(actions: ActionRecord[]): HelpItem[] {
  const items: HelpItem[] = [];
  const nav = actions.filter(a => a.kind === 'startNavigation').at(-1);
  if (nav) {
    const text = NAVIGATION_TEXT[nav.status] ?? `Navigation ${nav.status}`;
    items.push({ kind: 'navigation', status: nav.status,
      text: nav.status === 'failed' && nav.reason ? `${text} (${nav.reason})` : text,
      at: (nav.resultAt ?? nav.deliveredAt ?? nav.decidedAt).toISOString() });
  }
  for (const a of actions.filter(x => x.kind !== 'startNavigation')) {
    const [kind, label] = PUSH_LABEL[a.kind];
    items.push({ kind, status: a.status, text: `${label} ${PUSH_OUTCOME[a.status] ?? a.status}`, at: (a.resultAt ?? a.decidedAt).toISOString() });
  }
  return items;
}

function timeline(e: RiskEventRecord, activity: RiskActivity): TimelineItem[] {
  const items: Array<TimelineItem & { order: number }> = [];
  const add = (at: Date | null, kind: string, text: string, order: number) => { if (at) items.push({ at: at.toISOString(), kind, text, order }); };
  add(e.anomalyStartedAt, 'anomalyStarted', e.anomaly === 'wandering' ? 'Started wandering' : 'Left the usual route', 0);
  for (const t of activity.transitions) {
    const minutes = t.detail?.minutes;
    if (t.kind === 'opened') add(t.at, 'lowRisk', `Low risk: ${anomalyName(e.anomaly)} for ${minutes} minutes`, 1);
    if (t.kind === 'escalated') add(t.at, 'highRisk', `High risk: ${anomalyName(e.anomaly)} for ${minutes} minutes`, 1);
    if (t.kind === 'resolved') {
      add(t.at, 'resolved', t.detail?.resolution === 'met' ? "You confirmed you've met; risk resolved" : 'Back home; risk resolved', 3);
    }
  }
  for (const a of activity.actions) {
    if (a.kind === 'startNavigation') {
      if (a.status === 'skipped') { add(a.decidedAt, 'navigationSkipped', NAVIGATION_TEXT.skipped, 2); continue; }
      add(a.decidedAt, 'navigationSent', 'Asked her phone to start navigation home', 2);
      if (a.status === 'started') add(a.resultAt, 'navigationStarted', NAVIGATION_TEXT.started, 2);
      if (a.status === 'failed') add(a.resultAt, 'navigationFailed', a.reason ? `${NAVIGATION_TEXT.failed} (${a.reason})` : NAVIGATION_TEXT.failed, 2);
      if (a.status === 'expired') add(a.expiresAt, 'navigationExpired', NAVIGATION_TEXT.expired, 2);
      continue;
    }
    const [, label] = PUSH_LABEL[a.kind];
    add(a.decidedAt, a.status === 'skipped' ? 'notificationSkipped' : 'familyNotified', `${label} ${PUSH_OUTCOME[a.status] ?? a.status}`, 2);
  }
  for (const c of activity.calls) add(c.at, 'familyCalled', 'Family called her', 2);
  for (const d of activity.dispositions) if (d.kind === 'falseAlarm') add(d.at, 'falseAlarm', 'Marked as false alarm', 4);
  return items.sort((a, b) => a.at.localeCompare(b.at) || a.order - b.order).map(({ order, ...item }) => item);
}

export function buildRiskDetail(input: {
  event: RiskEventRecord; activity: RiskActivity; latest: StoredFix | null; trail: StoredFix[]; now?: Date;
}): RiskEventDetail {
  const { event: e, activity } = input;
  const until = e.resolvedAt ?? input.now ?? new Date();
  const point = (p: StoredFix) => ({ latitude: p.latitude, longitude: p.longitude });
  return {
    ...riskSummary(e),
    headline: riskHeadline(e.anomaly, e.anomalyStartedAt, until),
    durationMinutes: Math.max(0, Math.floor((until.getTime() - e.anomalyStartedAt.getTime()) / 60_000)),
    canMarkFalseAlarm: e.status === 'resolved' && !e.falseAlarm,
    explanation: e.explanation,
    coordinate: input.latest ? point(input.latest) : null,
    recordedAt: input.latest ? input.latest.sampledAt.toISOString() : null,
    trail: input.trail.map(point),
    help: helpItems(activity.actions),
    timeline: timeline(e, activity),
    transitions: activity.transitions.map(t => ({ seq: t.seq, kind: t.kind, fromLevel: t.fromLevel, toLevel: t.toLevel, at: t.at.toISOString() })),
    actions: activity.actions.map(a => ({
      id: a.id, type: a.kind, status: a.status, reason: a.reason, decidedAt: a.decidedAt.toISOString(), createdAt: a.createdAt.toISOString(),
      expiresAt: iso(a.expiresAt), deliveredAt: iso(a.deliveredAt), resultAt: iso(a.resultAt),
      deliveries: a.deliveries.map(d => ({ channel: d.channel, result: d.result, detail: d.detail, at: d.at.toISOString() })),
    })),
    observations: activity.observations.map(o => ({ kind: o.kind, startedAt: o.startedAt.toISOString(), endedAt: iso(o.endedAt), features: o.features })),
  };
}
