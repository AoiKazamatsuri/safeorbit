import { Injectable, NotFoundException } from '@nestjs/common';
import { CareStore, StoredFix } from './care-store';
import { DatabaseService } from './database.service';
import { buildRecords, buildTrends, buildTripDetail, localDate, parseMonth, parseWeek, RecordsData } from './records-view';

@Injectable()
export class Records {
  constructor(private readonly db: DatabaseService, private readonly store: CareStore) {}

  // Demo history is small. Load the complete household read model in one consistent database snapshot;
  // no UI-specific rollups or arbitrary row caps can make the calendar and trends disagree.
  async data(elderId: number): Promise<RecordsData> {
    return this.db.transaction(async client => {
      await client.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY');
      const { rows: [elder] } = await client.query('SELECT timezone FROM elders WHERE id = $1', [elderId]);
      if (!elder) throw new NotFoundException('Household not found');
      const { rows: trips } = await client.query('SELECT * FROM trips WHERE elder_id = $1 ORDER BY started_at', [elderId]);
      const { rows: risks } = await client.query('SELECT * FROM risk_events WHERE elder_id = $1 ORDER BY opened_at', [elderId]);
      const { rows: observations } = await client.query('SELECT * FROM behaviour_observations WHERE elder_id = $1 ORDER BY started_at', [elderId]);
      const { rows: actions } = await client.query('SELECT * FROM actions WHERE elder_id = $1 ORDER BY decided_at', [elderId]);
      const { rows: calls } = await client.query('SELECT * FROM call_records WHERE elder_id = $1 ORDER BY at', [elderId]);
      return {
        timezone: elder.timezone,
        trips: trips.map(r => ({ id: String(r.id), startedAt: r.started_at, endedAt: r.ended_at, startKnown: r.start_known, stops: r.stops })),
        risks: risks.map(r => ({ id: String(r.id), tripId: r.trip_id === null ? null : String(r.trip_id), openedAt: r.opened_at,
          escalatedAt: r.escalated_at, resolvedAt: r.resolved_at, falseAlarm: r.false_alarm })),
        observations: observations.map(r => ({ key: r.key, kind: r.kind, startedAt: r.started_at, riskEventId: r.risk_event_id === null ? null : String(r.risk_event_id) })),
        actions: actions.map(r => ({ id: String(r.id), riskEventId: String(r.risk_event_id), kind: r.kind, status: r.status,
          reason: r.reason, decidedAt: r.decided_at, resultAt: r.result_at })),
        calls: calls.map(r => ({ id: String(r.id), riskEventId: r.risk_event_id === null ? null : String(r.risk_event_id), at: r.at })),
      };
    });
  }
  async calendar(elderId: number, month?: string, week?: string, now = new Date()) {
    // Validate supplied parameters before touching the database.
    parseMonth(month, '2000-01'); parseWeek(week, '2000-01-01');
    const data = await this.data(elderId), today = localDate(now, data.timezone);
    return buildRecords(data, parseMonth(month, today.slice(0, 7)), parseWeek(week, today), now);
  }
  async trends(elderId: number, month?: string, now = new Date()) {
    parseMonth(month, '2000-01');
    const data = await this.data(elderId);
    return buildTrends(data, parseMonth(month, localDate(now, data.timezone).slice(0, 7)), now);
  }
  async detail(elderId: number, id: string, now = new Date()) {
    if (!/^\d{1,18}$/.test(id)) throw new NotFoundException('Trip not found');
    const data = await this.data(elderId), trip = data.trips.find(t => t.id === id);
    if (!trip) throw new NotFoundException('Trip not found');
    const [rows, zones] = await Promise.all([
      this.db.query<any>(`SELECT sampled_at, latitude, longitude, accuracy_m, speed_mps, course_deg FROM location_points
        WHERE elder_id = $1 AND sampled_at >= $2 AND sampled_at <= $3 ORDER BY sampled_at`, [elderId, trip.startedAt, trip.endedAt ?? now]),
      this.store.safeZones(elderId),
    ]);
    const trail: StoredFix[] = rows.map(r => ({ sampledAt: r.sampled_at, latitude: r.latitude, longitude: r.longitude,
      accuracy: r.accuracy_m, speed: r.speed_mps, course: r.course_deg }));
    return buildTripDetail(data, trip, trail, zones, now);
  }
}
