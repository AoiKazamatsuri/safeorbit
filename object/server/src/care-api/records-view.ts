import { SafeZone, StoredFix, TripRecord } from './care-store';
import { distanceMeters } from './geo';
import { tripName } from './location-view';
import { AnomalyValue } from './risk-records';
import { InputError } from './validation';

// The common read model for calendar, trends, details and future read-only conversation tools.
export interface RecordRisk {
  id: string; tripId: string | null; openedAt: Date; escalatedAt: Date | null; resolvedAt: Date | null; falseAlarm: boolean;
}
export interface RecordObservation { key: string; kind: AnomalyValue; startedAt: Date; riskEventId: string | null }
export interface RecordAction { id: string; riskEventId: string; kind: string; status: string; reason: string | null; decidedAt: Date; resultAt: Date | null }
export interface RecordCall { id: string; riskEventId: string | null; at: Date }
export interface RecordsData {
  timezone: string; trips: TripRecord[]; risks: RecordRisk[]; observations: RecordObservation[];
  actions: RecordAction[]; calls: RecordCall[];
}
export type RecordRiskLevel = 'normal' | 'warning' | 'high';

export function localDate(at: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(at);
  const value = (type: string) => parts.find(p => p.type === type)!.value;
  return `${value('year')}-${value('month')}-${value('day')}`;
}
export function addDays(date: string, days: number): string {
  const value = new Date(`${date}T12:00:00Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}
export function weekStart(date: string): string {
  const weekday = new Date(`${date}T12:00:00Z`).getUTCDay();
  return addDays(date, -((weekday + 6) % 7));
}
export function parseMonth(value: unknown, fallback: string): string {
  if (value === undefined) return fallback;
  if (typeof value !== 'string' || !/^[1-9]\d{3}-(0[1-9]|1[0-2])$/.test(value)) throw new InputError('month must be YYYY-MM');
  return value;
}
export function parseWeek(value: unknown, fallback: string): string {
  if (value === undefined) return weekStart(fallback);
  if (typeof value !== 'string' || !/^[1-9]\d{3}-\d{2}-\d{2}$/.test(value)
    || !Number.isFinite(Date.parse(`${value}T12:00:00Z`)) || addDays(value, 0) !== value) throw new InputError('week must be a valid YYYY-MM-DD');
  return weekStart(value);
}
export function monthAfter(month: string, offset: number): string {
  const at = new Date(`${month}-01T12:00:00Z`); at.setUTCMonth(at.getUTCMonth() + offset);
  return at.toISOString().slice(0, 7);
}
const included = (data: RecordsData) => data.risks.filter(r => !r.falseAlarm);
const inTrip = (at: Date, trip: TripRecord, now: Date) => at >= trip.startedAt && at <= (trip.endedAt ?? now);
export function validObservations(data: RecordsData): RecordObservation[] {
  const falseIds = new Set(data.risks.filter(r => r.falseAlarm).map(r => r.id));
  return [...new Map(data.observations.filter(o => !o.riskEventId || !falseIds.has(o.riskEventId)).map(o => [o.key, o])).values()];
}
function tripObservations(data: RecordsData, trip: TripRecord, now: Date): RecordObservation[] {
  const ids = new Set(data.risks.filter(r => r.tripId === trip.id).map(r => r.id));
  return validObservations(data).filter(o => o.riskEventId ? ids.has(o.riskEventId) : inTrip(o.startedAt, trip, now));
}
function tripCalls(data: RecordsData, trip: TripRecord, now: Date): RecordCall[] {
  const ids = new Set(data.risks.filter(r => r.tripId === trip.id).map(r => r.id));
  return data.calls.filter(c => c.riskEventId ? ids.has(c.riskEventId) : inTrip(c.at, trip, now));
}
export function summarizeTrip(data: RecordsData, trip: TripRecord, now: Date) {
  const risks = included(data).filter(r => r.tripId === trip.id);
  const observations = tripObservations(data, trip, now);
  const risk: RecordRiskLevel = risks.some(r => r.escalatedAt) ? 'high' : risks.length ? 'warning' : 'normal';
  return {
    id: trip.id, name: tripName(trip.stops), startedAt: trip.startedAt.toISOString(), endedAt: trip.endedAt?.toISOString() ?? null,
    startKnown: trip.startKnown, risk, anomalies: [...new Set(observations.map(o => o.kind))],
    durationMinutes: Math.max(0, Math.round(((trip.endedAt ?? now).getTime() - trip.startedAt.getTime()) / 60_000)),
    deviations: observations.filter(o => o.kind === 'deviation').length, calls: tripCalls(data, trip, now).length,
    returnedHome: trip.endedAt !== null,
  };
}
export function buildRecords(data: RecordsData, month: string, week: string, now: Date) {
  const days = new Map<string, RecordRiskLevel>();
  const monthFirst = `${month}-01`, nextMonth = `${monthAfter(month, 1)}-01`;
  const risks = included(data);
  for (const trip of data.trips) {
    const start = localDate(trip.startedAt, data.timezone), end = localDate(trip.endedAt ?? now, data.timezone);
    for (let date = start < monthFirst ? monthFirst : start; date <= end && date < nextMonth; date = addDays(date, 1)) {
      let level: RecordRiskLevel = days.get(date) ?? 'normal';
      for (const risk of risks.filter(r => r.tripId === trip.id)) {
        const opened = localDate(risk.openedAt, data.timezone), resolved = localDate(risk.resolvedAt ?? now, data.timezone);
        if (opened > date || resolved < date) continue;
        if (risk.escalatedAt && localDate(risk.escalatedAt, data.timezone) <= date) level = 'high';
        else if (level === 'normal') level = 'warning';
      }
      days.set(date, level);
    }
  }
  const weekEnd = addDays(week, 7);
  return { timezone: data.timezone, month, weekStart: week,
    days: [...days].sort(([a], [b]) => a.localeCompare(b)).map(([date, risk]) => ({ date, risk })),
    trips: data.trips.filter(t => localDate(t.startedAt, data.timezone) < weekEnd && localDate(t.endedAt ?? now, data.timezone) >= week)
      .sort((a, b) => b.startedAt.getTime() - a.startedAt.getTime()).map(t => summarizeTrip(data, t, now)),
  };
}
export function buildTrends(data: RecordsData, month: string, now: Date) {
  const today = localDate(now, data.timezone), previousMonth = monthAfter(month, -1);
  const atMonth = (at: Date, target: string) => localDate(at, data.timezone).slice(0, 7) === target;
  const observations = validObservations(data), risks = included(data);
  const riskIds = new Set(risks.map(r => r.id));
  const deviations = observations.filter(o => o.kind === 'deviation');
  const comparison = (count: (month: string) => number) => ({ current: count(month), previous: count(previousMonth) });
  const last = weekStart(month === today.slice(0, 7) ? today : addDays(`${monthAfter(month, 1)}-01`, -1));
  const safeRate = (target: string) => {
    const trips = data.trips.filter(t => atMonth(t.startedAt, target) && risks.some(r => r.tripId === t.id));
    const safe = trips.filter(t => t.endedAt && !risks.some(r => r.tripId === t.id && r.escalatedAt));
    return trips.length ? Math.round(100 * safe.length / trips.length) : 0;
  };
  const monthTrips = data.trips.filter(t => atMonth(t.startedAt, month));
  const hours = new Map<string, number>();
  for (const t of monthTrips) {
    const hour = Number(new Intl.DateTimeFormat('en-GB', { timeZone: data.timezone, hour: '2-digit', hourCycle: 'h23' }).format(t.startedAt));
    const period = hour < 12 ? 'morning' : hour < 18 ? 'afternoon' : 'evening';
    hours.set(period, (hours.get(period) ?? 0) + 1);
  }
  const common = [...hours].sort((a, b) => b[1] - a[1])[0];
  return { timezone: data.timezone, month, previousMonth,
    weeks: Array.from({ length: 8 }, (_, i) => {
      const start = addDays(last, (i - 7) * 7);
      return { start, deviations: deviations.filter(o => weekStart(localDate(o.startedAt, data.timezone)) === start).length };
    }),
    deviations: comparison(target => deviations.filter(o => atMonth(o.startedAt, target)).length),
    metrics: {
      unusualMovement: comparison(target => observations.filter(o => atMonth(o.startedAt, target)).length),
      navigationAssistance: comparison(target => data.actions.filter(a => riskIds.has(a.riskEventId)
        && a.kind === 'startNavigation' && a.status === 'started' && a.resultAt && atMonth(a.resultAt, target)).length),
      highRisk: comparison(target => risks.filter(r => r.escalatedAt && atMonth(r.escalatedAt, target)).length),
      safeReturnRate: comparison(safeRate),
    },
    pattern: common ? `Based on ${monthTrips.length} recorded trips this month, ${common[1]} started in the ${common[0]}.`
      : 'No recorded trips this month yet.',
  };
}
export function buildTripDetail(data: RecordsData, trip: TripRecord, trail: StoredFix[], zones: SafeZone[], now: Date) {
  const risks = included(data).filter(r => r.tripId === trip.id);
  const ids = new Set(data.risks.filter(r => r.tripId === trip.id).map(r => r.id));
  const timeline: Array<{ id: string; at: string; title: string }> = [];
  const add = (id: string, at: Date, title: string) => timeline.push({ id, at: at.toISOString(), title });
  add(`trip-${trip.id}-start`, trip.startedAt, trip.startKnown ? 'Left home' : 'Trip observed; departure time unknown');
  let lastZone: string | undefined;
  for (const [index, p] of trail.entries()) {
    const zone = zones.find(z => !z.isHome && distanceMeters(p, z.center) <= z.radiusMeters);
    if (zone && zone.id !== lastZone) add(`trip-${trip.id}-stop-${index}`, p.sampledAt, `Arrived at ${zone.name}`);
    lastZone = zone?.id;
  }
  const anomalies = tripObservations(data, trip, now).flatMap(o => {
    add(`observation-${o.key}`, o.startedAt, o.kind === 'wandering' ? 'Wandering observed' : 'Route deviation observed');
    if (!trail.length) return [];
    const nearest = trail.reduce((a, b) => Math.abs(a.sampledAt.getTime() - o.startedAt.getTime()) <= Math.abs(b.sampledAt.getTime() - o.startedAt.getTime()) ? a : b);
    return [{ kind: o.kind, at: o.startedAt.toISOString(), latitude: nearest.latitude, longitude: nearest.longitude }];
  });
  for (const r of risks) {
    add(`risk-${r.id}-opened`, r.openedAt, 'Low risk detected');
    if (r.escalatedAt) add(`risk-${r.id}-high`, r.escalatedAt, 'Risk increased to high');
    if (r.resolvedAt) add(`risk-${r.id}-resolved`, r.resolvedAt, 'Risk resolved');
  }
  for (const a of data.actions.filter(a => ids.has(a.riskEventId))) {
    const name = a.kind === 'startNavigation' ? 'Navigation home' : a.kind === 'notifyHigh' ? 'High-risk alert' : a.kind === 'notifyResolved' ? 'Recovery notification' : 'Low-risk notification';
    const outcome = a.reason === 'historyReplay' ? (a.kind === 'startNavigation' ? 'not started' : 'not sent')
      : a.status === 'started' ? 'started' : a.status === 'sent' ? 'sent' : `${a.status}${a.reason ? ` (${a.reason})` : ''}`;
    add(`action-${a.id}`, a.resultAt ?? a.decidedAt, `${name}: ${outcome}`);
  }
  for (const c of tripCalls(data, trip, now)) add(`call-${c.id}`, c.at, 'Call initiated; connection unknown');
  if (trip.endedAt) add(`trip-${trip.id}-home`, trip.endedAt, 'Returned home');
  return { trip: summarizeTrip(data, trip, now), trail: trail.map(p => ({ latitude: p.latitude, longitude: p.longitude })), anomalies,
    timeline: timeline.sort((a, b) => a.at.localeCompare(b.at) || a.id.localeCompare(b.id)) };
}
