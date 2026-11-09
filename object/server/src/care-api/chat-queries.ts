import { Injectable } from '@nestjs/common';
import { CareStore } from './care-store';
import { Records } from './records';
import { addDays, buildTrends, localDate, monthAfter, summarizeTrip } from './records-view';

export type ChatQuery = { kind: 'current' | 'events' | 'trip' | 'compare'; id?: string; month?: string; from?: string; to?: string; level?: 'warning' | 'high'; latest?: boolean };
export interface Citation { kind: 'riskEvent' | 'trip' | 'statistic'; id: string; label: string; date?: string; startDate?: string; endDate?: string }
export interface QueryResult { facts: unknown; citations: Citation[]; evidence?: Record<string, unknown> }

@Injectable()
export class ChatQueries {
  constructor(private readonly records: Records, private readonly store: CareStore) {}
  async localToday(elderId: number, now = new Date()): Promise<string> {
    return localDate(now, (await this.store.household(elderId)).elder.timezone);
  }
  async run(elderId: number, query: ChatQuery, now = new Date()): Promise<QueryResult> {
    const data = await this.records.data(elderId);
    const today = localDate(now, data.timezone);
    if (query.kind === 'current') {
      const risk = [...data.risks].reverse().find(r => !r.falseAlarm && !r.resolvedAt);
      const trip = [...data.trips].reverse().find(t => !t.endedAt);
      const tracker = await this.store.tracker(elderId);
      if (!tracker?.processedThrough) return { facts: null, citations: [] };
      const date = localDate(tracker.processedThrough, data.timezone);
      const activeRisk = risk ? { id: risk.id, date: localDate(risk.openedAt, data.timezone), level: risk.escalatedAt ? 'high' : 'warning' } : null;
      const activeTrip = trip ? { id: trip.id, date: localDate(trip.startedAt, data.timezone) } : null;
      const status = { lastRecordedDate: date, phase: tracker.phase, historyReplay: tracker.historyReplay === true,
        olderThanFiveMinutes: now.getTime() - tracker.processedThrough.getTime() > 300_000,
        hasActiveRisk: activeRisk !== null, hasActiveTrip: activeTrip !== null };
      const citations: Citation[] = [{ kind: 'statistic', id: `current-${date}`, label: 'Last recorded status', startDate: date, endDate: date }];
      const evidence: Record<string, unknown> = { [`statistic:current-${date}`]: status };
      if (activeRisk) {
        citations.push({ kind: 'riskEvent', id: activeRisk.id, date: activeRisk.date, label: `Risk event ${activeRisk.id}` });
        evidence[`riskEvent:${activeRisk.id}`] = activeRisk;
      }
      if (activeTrip) {
        citations.push({ kind: 'trip', id: activeTrip.id, date: activeTrip.date, label: `Trip ${activeTrip.id}` });
        evidence[`trip:${activeTrip.id}`] = activeTrip;
      }
      return { facts: { status, activeRisk, activeTrip }, citations, evidence };
    }
    if (query.kind === 'events') {
      const risks = data.risks.filter(r => {
        const date = localDate(query.level === 'high' && r.escalatedAt ? r.escalatedAt : r.openedAt, data.timezone);
        return !r.falseAlarm && (!query.level || query.level === (r.escalatedAt ? 'high' : 'warning'))
          && (!query.from || date >= query.from) && (!query.to || date <= query.to);
      }).slice(query.latest ? -1 : -20).reverse();
      const facts = risks.map(r => ({
        id: r.id, date: localDate(r.openedAt, data.timezone), level: r.escalatedAt ? 'high' : 'warning',
        escalatedDate: r.escalatedAt ? localDate(r.escalatedAt, data.timezone) : null,
        resolvedDate: r.resolvedAt ? localDate(r.resolvedAt, data.timezone) : null,
        anomaly: r.anomaly, resolution: r.resolution,
        actions: data.actions.filter(a => a.riskEventId === r.id).map(a => ({ kind: a.kind, status: a.status })),
        anomalies: data.observations.filter(o => o.riskEventId === r.id).map(o => o.kind),
      }));
      return { facts, citations: risks.map(r => ({ kind: 'riskEvent', id: r.id, date: localDate(r.openedAt, data.timezone), label: `Risk event ${r.id}` })),
        evidence: Object.fromEntries(facts.map(f => [`riskEvent:${f.id}`, f])) };
    }
    if (query.kind === 'trip') {
      const trip = query.id ? data.trips.find(t => t.id === query.id) : data.trips.at(-1);
      if (!trip) return { facts: null, citations: [] };
      const summary = summarizeTrip(data, trip, now);
      const { name: _name, ...safe } = summary;
      // ISO timestamps are replaced with dates interpreted in the elder's timezone.
      return { facts: { ...safe, startedAt: localDate(trip.startedAt, data.timezone), endedAt: trip.endedAt ? localDate(trip.endedAt, data.timezone) : null },
        citations: [{ kind: 'trip', id: trip.id, label: `Trip ${trip.id}`, date: localDate(trip.startedAt, data.timezone) }] };
    }
    const month = query.month && /^[1-9]\d{3}-(0[1-9]|1[0-2])$/.test(query.month) ? query.month : today.slice(0, 7);
    const trends = buildTrends(data, month, now);
    const start = `${trends.previousMonth}-01`, previousEnd = addDays(`${month}-01`, -1);
    const end = month === today.slice(0, 7) ? today : addDays(`${monthAfter(month, 1)}-01`, -1);
    const citations: Citation[] = [
      { kind: 'statistic', id: `month-${trends.previousMonth}`, label: `Monthly behaviour ${trends.previousMonth}`, startDate: start, endDate: previousEnd },
      { kind: 'statistic', id: `month-${month}`, label: `Monthly behaviour ${month}`, startDate: `${month}-01`, endDate: end },
    ];
    const periods = (['previous', 'current'] as const).map((period, index) => ({
      month: period === 'current' ? month : trends.previousMonth,
      startDate: citations[index].startDate, endDate: citations[index].endDate,
      tripCount: trends.totals.tripCount[period], riskEventCount: trends.totals.riskEventCount[period],
      deviations: trends.deviations[period],
      metrics: Object.fromEntries(Object.entries(trends.metrics).map(([key, values]) => [key, values[period]])),
      ...(period === 'current' ? { pattern: trends.pattern } : {}),
    }));
    return {
      facts: { periods, pattern: trends.pattern },
      citations,
      evidence: Object.fromEntries(citations.map((citation, index) => [`statistic:${citation.id}`, periods[index]])),
    };
  }
}
