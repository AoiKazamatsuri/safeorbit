import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PoolClient } from 'pg';
import { applyTracking, TrackingNext, TripChange } from './care-store';
import { CareEvents, StateChangeType } from './care-events';
import { DatabaseService } from './database.service';
import { GeoPoint } from './geo';

// Risk, outreach and disposition records of the care database. The care API owns these records; the care
// agent decides what to write and the outreach gateway reports deliveries, both only through this class
// (engineering architecture section 5, edges 8 and 11).

export interface CaregiverSettings {
  autoNavigation: boolean; lowRiskNotifications: boolean; recoveryNotifications: boolean; limitedMonitoringNotifications: boolean;
}
export const DEFAULT_CAREGIVER_SETTINGS: CaregiverSettings = {
  autoNavigation: true, lowRiskNotifications: true, recoveryNotifications: true, limitedMonitoringNotifications: true,
};

export type RiskLevelValue = 'warning' | 'high';
export type AnomalyValue = 'wandering' | 'deviation';
export type ActionKind = 'startNavigation' | 'notifyLow' | 'notifyHigh' | 'notifyResolved';

// What the care agent writes after a run of its rules; applied in order inside one transaction.
export type RiskWrite =
  | { type: 'observation'; key: string; kind: AnomalyValue; startedAt: Date; endedAt: Date | null;
      features: Record<string, number>; ruleVersion: string; riskKey: string | null }
  | { type: 'opened'; key: string; anomaly: AnomalyValue; anomalyStartedAt: Date; at: Date; minutes: number; tripStartedAt: Date | null }
  | { type: 'escalated'; key: string; at: Date; minutes: number }
  | { type: 'resolved'; key: string; at: Date; resolution: 'home' | 'met' };
export interface ActionWrite {
  riskKey: string; kind: ActionKind; target: 'elder' | 'caregivers'; idempotencyKey: string;
  status: 'pending' | 'skipped'; reason: string | null; details: Record<string, unknown>;
  decidedAt: Date; expiresInSeconds: number | null;
}
export interface EvaluationWrite {
  tracking?: { changes: TripChange[]; next: TrackingNext };
  riskState: unknown;
  writes: RiskWrite[];
  actions: ActionWrite[];
}

export interface RiskEventRecord {
  id: string; key: string; tripId: string | null; level: RiskLevelValue; status: 'active' | 'resolved'; anomaly: AnomalyValue;
  anomalyStartedAt: Date; openedAt: Date; escalatedAt: Date | null; resolvedAt: Date | null; resolution: 'home' | 'met' | null;
  falseAlarm: boolean; explanation: string | null; version: number; changedAt: Date;
}
export interface DeliveryRecord { channel: 'apns' | 'uploadReply'; deviceId: string | null; result: string; detail: string | null; at: Date }
export interface ActionRecord {
  id: string; riskEventId: string; kind: ActionKind; target: 'elder' | 'caregivers'; status: string; reason: string | null;
  details: Record<string, any>; decidedAt: Date; createdAt: Date; expiresAt: Date | null; deliveredAt: Date | null;
  resultAt: Date | null; deliveries: DeliveryRecord[];
}
export interface TransitionRecord { seq: number; kind: 'opened' | 'escalated' | 'resolved'; fromLevel: string | null; toLevel: string | null; at: Date; detail: Record<string, any> }
export interface ObservationRecord { key: string; kind: AnomalyValue; startedAt: Date; endedAt: Date | null; features: Record<string, number> }
export interface RiskActivity {
  transitions: TransitionRecord[]; actions: ActionRecord[];
  dispositions: Array<{ kind: 'met' | 'falseAlarm'; at: Date }>; calls: Array<{ at: Date }>; observations: ObservationRecord[];
}
export interface ElderAction { id: string; type: 'startNavigation'; riskEventId: string; expiresAt: string }
export interface PushJob { id: string; kind: ActionKind; riskEventId: string; details: Record<string, any> }
export interface PushRecipient { deviceId: string; pushToken: string }

const eventRow = (r: any): RiskEventRecord => ({
  id: String(r.id), key: r.key, tripId: r.trip_id === null ? null : String(r.trip_id), level: r.level, status: r.status,
  anomaly: r.anomaly, anomalyStartedAt: r.anomaly_started_at, openedAt: r.opened_at, escalatedAt: r.escalated_at,
  resolvedAt: r.resolved_at, resolution: r.resolution, falseAlarm: r.false_alarm, explanation: r.explanation,
  version: r.version, changedAt: r.changed_at,
});
const settingsRow = (r: any): CaregiverSettings => ({
  autoNavigation: r.auto_navigation, lowRiskNotifications: r.low_risk_notifications,
  recoveryNotifications: r.recovery_notifications, limitedMonitoringNotifications: r.limited_monitoring_notifications,
});
const ACTIVE_NAVIGATION = `kind = 'startNavigation' AND status IN ('pending', 'delivered')`;

@Injectable()
export class RiskRecords {
  constructor(private readonly db: DatabaseService, private readonly events: CareEvents) {}

  private async announce(elderId: number, type: StateChangeType): Promise<void> {
    const [row] = await this.db.query<{ seq: string }>(`SELECT nextval('state_change_seq') AS seq`);
    this.events.publishStateChanged({ elderId, seq: Number(row.seq), type });
  }

  // ---- reference routes and caregiver settings

  async referenceRoutes(elderId: number): Promise<GeoPoint[][]> {
    return (await this.db.query<{ points: GeoPoint[] }>(
      `SELECT r.points FROM reference_routes r JOIN safe_zones z ON z.id = r.zone_id
       WHERE r.elder_id = $1 AND NOT z.is_home ORDER BY z.created_at`, [elderId])).map(r => r.points);
  }

  async zonesWithRoute(elderId: number): Promise<Set<string>> {
    return new Set((await this.db.query<{ zone_id: string }>('SELECT zone_id FROM reference_routes WHERE elder_id = $1', [elderId]))
      .map(r => r.zone_id));
  }

  async saveReferenceRoute(elderId: number, zoneId: string, points: GeoPoint[]): Promise<{ zoneId: string; pointCount: number; uploadedAt: string }> {
    const [zone] = await this.db.query<{ is_home: boolean }>('SELECT is_home FROM safe_zones WHERE elder_id = $1 AND id = $2', [elderId, zoneId]);
    if (!zone) throw new NotFoundException('Safe zone not found');
    if (zone.is_home) throw new ConflictException('Home has no reference route; routes run from home to another safe zone');
    const [row] = await this.db.query<{ uploaded_at: Date }>(
      `INSERT INTO reference_routes (zone_id, elder_id, points, source) VALUES ($1, $2, $3, 'phone')
       ON CONFLICT (zone_id) DO UPDATE SET points = EXCLUDED.points, source = 'phone', uploaded_at = now() RETURNING uploaded_at`,
      [zoneId, elderId, JSON.stringify(points)]);
    return { zoneId, pointCount: points.length, uploadedAt: row.uploaded_at.toISOString() };
  }

  private async primaryCaregiverId(elderId: number): Promise<number> {
    const [row] = await this.db.query<{ id: number }>('SELECT id FROM caregivers WHERE elder_id = $1 AND is_primary ORDER BY id LIMIT 1', [elderId]);
    if (!row) throw new NotFoundException('Household is not seeded');
    return row.id;
  }

  // Demo: one caregiver, so every caregiver phone of the household shares the primary caregiver's settings.
  async settings(elderId: number): Promise<CaregiverSettings> {
    const [row] = await this.db.query(
      `SELECT s.* FROM caregiver_settings s JOIN caregivers c ON c.id = s.caregiver_id WHERE c.elder_id = $1 AND c.is_primary`, [elderId]);
    return row ? settingsRow(row) : { ...DEFAULT_CAREGIVER_SETTINGS };
  }

  async saveSettings(elderId: number, change: Partial<CaregiverSettings>): Promise<CaregiverSettings> {
    const next = { ...(await this.settings(elderId)), ...change };
    const [row] = await this.db.query(
      `INSERT INTO caregiver_settings (caregiver_id, auto_navigation, low_risk_notifications, recovery_notifications,
         limited_monitoring_notifications, updated_at) VALUES ($1, $2, $3, $4, $5, now())
       ON CONFLICT (caregiver_id) DO UPDATE SET auto_navigation = $2, low_risk_notifications = $3, recovery_notifications = $4,
         limited_monitoring_notifications = $5, updated_at = now() RETURNING *`,
      [await this.primaryCaregiverId(elderId), next.autoNavigation, next.lowRiskNotifications, next.recoveryNotifications,
        next.limitedMonitoringNotifications]);
    return settingsRow(row);
  }

  // ---- care agent writes

  // Trip changes, observations, risk transitions and actions of one run commit together (C2 edge 8).
  async recordEvaluation(elderId: number, input: EvaluationWrite): Promise<{ touched: string[] }> {
    let changed = false;
    const touched = await this.db.transaction(async client => {
      if (input.tracking) await applyTracking(client, elderId, input.tracking.changes, input.tracking.next, input.riskState);
      else await client.query('UPDATE tracker_state SET risk_state = $2, updated_at = now() WHERE elder_id = $1',
        [elderId, JSON.stringify(input.riskState)]);
      const ids = new Set<string>();
      for (const w of input.writes) {
        const id = await applyRiskWrite(client, elderId, w);
        if (id) { ids.add(id); changed = true; }
      }
      for (const a of input.actions) if (await insertAction(client, elderId, a)) changed = true;
      return [...ids];
    });
    if (changed) await this.announce(elderId, 'risk');
    return { touched };
  }

  async saveExplanation(eventId: string, text: string): Promise<void> {
    await this.db.query('UPDATE risk_events SET explanation = $2 WHERE id = $1', [eventId, text]);
  }

  async latestNavigation(eventId: string): Promise<{ id: string; seq: number; status: string; expiresAt: Date | null } | null> {
    const [row] = await this.db.query<any>(
      `SELECT id, (details->>'seq')::int AS seq, status, expires_at FROM actions
       WHERE risk_event_id = $1 AND kind = 'startNavigation' ORDER BY id DESC LIMIT 1`, [eventId]);
    return row ? { id: String(row.id), seq: row.seq ?? 1, status: row.status, expiresAt: row.expires_at } : null;
  }

  // Marks a lapsed navigation request expired and, when given, issues its replacement.
  async renewNavigation(elderId: number, expireId: string | null, next: ActionWrite | null): Promise<void> {
    await this.db.transaction(async client => {
      if (expireId) {
        await client.query(`UPDATE actions SET status = 'expired', reason = 'noAnswer' WHERE id = $1 AND ${ACTIVE_NAVIGATION}`, [expireId]);
      }
      if (next) await insertAction(client, elderId, next);
    });
    await this.announce(elderId, 'action');
  }

  // ---- reads

  async activeRiskEvent(elderId: number): Promise<RiskEventRecord | null> {
    const [row] = await this.db.query(`SELECT * FROM risk_events WHERE elder_id = $1 AND status = 'active'`, [elderId]);
    return row ? eventRow(row) : null;
  }

  // The active event, else the latest one resolved within the window, so the caregiver can still open it
  // (and mark it as a false alarm) from the person card for a while after it ends.
  async currentRiskEvent(elderId: number, resolvedWindowSeconds: number): Promise<RiskEventRecord | null> {
    const [row] = await this.db.query(
      `SELECT * FROM risk_events WHERE elder_id = $1
         AND (status = 'active' OR changed_at >= now() - make_interval(secs => $2))
       ORDER BY (status = 'active') DESC, id DESC LIMIT 1`, [elderId, resolvedWindowSeconds]);
    return row ? eventRow(row) : null;
  }

  async riskEvent(elderId: number, id: string): Promise<RiskEventRecord> {
    if (!/^\d{1,18}$/.test(id)) throw new NotFoundException('Risk event not found');
    const [row] = await this.db.query('SELECT * FROM risk_events WHERE elder_id = $1 AND id = $2', [elderId, id]);
    if (!row) throw new NotFoundException('Risk event not found');
    return eventRow(row);
  }

  async riskEvents(elderId: number, limit: number): Promise<RiskEventRecord[]> {
    return (await this.db.query('SELECT * FROM risk_events WHERE elder_id = $1 ORDER BY id DESC LIMIT $2', [elderId, limit])).map(eventRow);
  }

  async activity(eventId: string): Promise<RiskActivity> {
    const [transitions, actions, deliveries, dispositions, calls, observations] = await Promise.all([
      this.db.query<any>('SELECT * FROM risk_transitions WHERE risk_event_id = $1 ORDER BY seq', [eventId]),
      this.db.query<any>('SELECT * FROM actions WHERE risk_event_id = $1 ORDER BY id', [eventId]),
      this.db.query<any>(
        'SELECT d.* FROM deliveries d JOIN actions a ON a.id = d.action_id WHERE a.risk_event_id = $1 ORDER BY d.id', [eventId]),
      this.db.query<any>('SELECT kind, at FROM dispositions WHERE risk_event_id = $1 ORDER BY id', [eventId]),
      this.db.query<any>('SELECT at FROM call_records WHERE risk_event_id = $1 ORDER BY id', [eventId]),
      this.db.query<any>('SELECT * FROM behaviour_observations WHERE risk_event_id = $1 ORDER BY started_at', [eventId]),
    ]);
    return {
      transitions: transitions.map(r => ({ seq: r.seq, kind: r.kind, fromLevel: r.from_level, toLevel: r.to_level, at: r.at, detail: r.detail })),
      actions: actions.map(r => ({
        id: String(r.id), riskEventId: String(r.risk_event_id), kind: r.kind, target: r.target, status: r.status, reason: r.reason,
        details: r.details, decidedAt: r.decided_at, createdAt: r.created_at, expiresAt: r.expires_at, deliveredAt: r.delivered_at,
        resultAt: r.result_at,
        deliveries: deliveries.filter(d => String(d.action_id) === String(r.id))
          .map(d => ({ channel: d.channel, deviceId: d.device_id, result: d.result, detail: d.detail, at: d.at })),
      })),
      dispositions: dispositions.map(r => ({ kind: r.kind, at: r.at })),
      calls: calls.map(r => ({ at: r.at })),
      observations: observations.map(r => ({ key: r.key, kind: r.kind, startedAt: r.started_at, endedAt: r.ended_at, features: r.features })),
    };
  }

  // Completed trips with no risk (false alarms do not count as risk), for the familiarity status line.
  async riskFreeTripCount(elderId: number): Promise<number> {
    const [row] = await this.db.query<{ n: string }>(
      `SELECT count(*) AS n FROM trips t WHERE t.elder_id = $1 AND t.ended_at IS NOT NULL
         AND NOT EXISTS (SELECT 1 FROM risk_events r WHERE r.trip_id = t.id AND NOT r.false_alarm)`, [elderId]);
    return Number(row.n);
  }

  async observationCount(elderId: number): Promise<number> {
    const [row] = await this.db.query<{ n: string }>('SELECT count(*) AS n FROM behaviour_observations WHERE elder_id = $1', [elderId]);
    return Number(row.n);
  }

  // ---- elder phone

  // Pending actions for the elder phone ride on every upload reply until answered, expired or withdrawn;
  // the App acts on each id once.
  async elderActions(elderId: number): Promise<ElderAction[]> {
    return this.db.transaction(async client => {
      const { rows } = await client.query<any>(
        `UPDATE actions SET status = 'delivered', delivered_at = COALESCE(delivered_at, now())
         WHERE elder_id = $1 AND target = 'elder' AND ${ACTIVE_NAVIGATION} AND expires_at > now()
         RETURNING id, risk_event_id, kind, expires_at, (delivered_at = now()) AS first`, [elderId]);
      for (const r of rows.filter(r => r.first)) {
        await client.query(`INSERT INTO deliveries (action_id, channel, result) VALUES ($1, 'uploadReply', 'included')`, [r.id]);
      }
      return rows.sort((a, b) => Number(a.id) - Number(b.id)).map(r => ({
        id: String(r.id), type: r.kind, riskEventId: String(r.risk_event_id), expiresAt: r.expires_at.toISOString(),
      }));
    });
  }

  async recordActionResult(elderId: number, actionId: string, result: 'started' | 'failed', reason: string | null):
    Promise<{ id: string; status: string }> {
    if (!/^\d{1,18}$/.test(actionId)) throw new NotFoundException('Action not found');
    const outcome = await this.db.transaction(async client => {
      const { rows: [row] } = await client.query<any>(
        `SELECT status FROM actions WHERE id = $1 AND elder_id = $2 AND target = 'elder' FOR UPDATE`, [actionId, elderId]);
      if (!row) throw new NotFoundException('Action not found');
      if (row.status === result) return { id: actionId, status: result, changed: false };
      if (row.status === 'cancelled') throw new ConflictException('This navigation request was withdrawn: the risk is resolved');
      if (!['pending', 'delivered', 'expired'].includes(row.status)) throw new ConflictException(`Action already ${row.status}`);
      await client.query('UPDATE actions SET status = $2, reason = $3, result_at = now() WHERE id = $1', [actionId, result, reason]);
      return { id: actionId, status: result, changed: true };
    });
    if (outcome.changed) await this.announce(elderId, 'action');
    return { id: outcome.id, status: outcome.status };
  }

  // ---- caregiver phone

  async submitMet(elderId: number, eventId: string, deviceId: string): Promise<RiskEventRecord> {
    const event = await this.riskEvent(elderId, eventId);
    if (event.status !== 'active') throw new ConflictException('This risk is already resolved');
    await this.db.query(`INSERT INTO dispositions (risk_event_id, kind, caregiver_id, device_id) VALUES ($1, 'met', $2, $3)`,
      [eventId, await this.primaryCaregiverId(elderId), deviceId]);
    return event;
  }

  // A disposition on a resolved event; the risk level and its transitions are untouched (principle 1).
  async markFalseAlarm(elderId: number, eventId: string, deviceId: string): Promise<{ event: RiskEventRecord; changed: boolean }> {
    const caregiverId = await this.primaryCaregiverId(elderId);
    const result = await this.db.transaction(async client => {
      const { rows: [row] } = await client.query('SELECT * FROM risk_events WHERE elder_id = $1 AND id = $2', [elderId, eventId]);
      if (!row) throw new NotFoundException('Risk event not found');
      const event = eventRow(row);
      if (event.status !== 'resolved') throw new ConflictException('Mark as False Alarm is available once the risk is resolved');
      if (event.falseAlarm) return { event, changed: false };
      await client.query(`INSERT INTO dispositions (risk_event_id, kind, caregiver_id, device_id) VALUES ($1, 'falseAlarm', $2, $3)`,
        [eventId, caregiverId, deviceId]);
      const updated = await client.query(
        `UPDATE risk_events SET false_alarm = true, version = version + 1, changed_at = now()
         WHERE id = $1 AND version = $2 RETURNING *`, [eventId, event.version]);
      if (!updated.rowCount) throw new ConflictException('The risk event changed meanwhile; try again');
      return { event: eventRow(updated.rows[0]), changed: true };
    });
    if (result.changed) await this.announce(elderId, 'risk');
    return result;
  }

  // "Call" pressed on the caregiver phone; the Demo only knows a call was started, not whether it connected.
  async recordCall(elderId: number, deviceId: string, riskEventId: string | null): Promise<{ id: string; at: string; riskEventId: string | null }> {
    const linked = riskEventId ? (await this.riskEvent(elderId, riskEventId)).id : (await this.activeRiskEvent(elderId))?.id ?? null;
    const [row] = await this.db.query<{ id: string; at: Date }>(
      'INSERT INTO call_records (elder_id, risk_event_id, caregiver_id, device_id) VALUES ($1, $2, $3, $4) RETURNING id, at',
      [elderId, linked, await this.primaryCaregiverId(elderId), deviceId]);
    return { id: String(row.id), at: row.at.toISOString(), riskEventId: linked };
  }

  // ---- outreach gateway

  // Claims caregiver notifications not yet sent, so two runs never send the same one.
  async claimPushJobs(elderId: number): Promise<PushJob[]> {
    return (await this.db.query<any>(
      `UPDATE actions SET status = 'sending' WHERE elder_id = $1 AND target = 'caregivers' AND status = 'pending'
       RETURNING id, kind, risk_event_id, details`, [elderId]))
      .sort((a, b) => Number(a.id) - Number(b.id))
      .map(r => ({ id: String(r.id), kind: r.kind, riskEventId: String(r.risk_event_id), details: r.details }));
  }

  async pushRecipients(elderId: number): Promise<PushRecipient[]> {
    return (await this.db.query<{ id: string; push_token: string }>(
      `SELECT id, push_token FROM devices WHERE elder_id = $1 AND role = 'caregiver' AND push_token IS NOT NULL ORDER BY created_at`,
      [elderId])).map(r => ({ deviceId: r.id, pushToken: r.push_token }));
  }

  // Delivery receipt (C2 edge 11): one record per attempt, and the action's overall outcome.
  async recordPushOutcome(elderId: number, actionId: string, status: string,
    deliveries: Array<{ deviceId: string | null; result: string; detail: string | null }>): Promise<void> {
    await this.db.transaction(async client => {
      for (const d of deliveries) {
        await client.query(`INSERT INTO deliveries (action_id, device_id, channel, result, detail) VALUES ($1, $2, 'apns', $3, $4)`,
          [actionId, d.deviceId, d.result, d.detail]);
      }
      await client.query('UPDATE actions SET status = $2, result_at = now() WHERE id = $1', [actionId, status]);
    });
    await this.announce(elderId, 'action');
  }
}

async function applyRiskWrite(client: PoolClient, elderId: number, w: RiskWrite): Promise<string | null> {
  if (w.type === 'observation') {
    await client.query(
      `INSERT INTO behaviour_observations (elder_id, key, kind, started_at, ended_at, features, rule_version, risk_event_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, (SELECT id FROM risk_events WHERE elder_id = $1 AND key = $8))
       ON CONFLICT (elder_id, key) DO UPDATE SET ended_at = EXCLUDED.ended_at, features = EXCLUDED.features,
         risk_event_id = COALESCE(EXCLUDED.risk_event_id, behaviour_observations.risk_event_id)`,
      [elderId, w.key, w.kind, w.startedAt, w.endedAt, JSON.stringify(w.features), w.ruleVersion, w.riskKey]);
    return null;
  }
  if (w.type === 'opened') {
    const { rows } = await client.query<{ id: string }>(
      `INSERT INTO risk_events (elder_id, key, trip_id, level, status, anomaly, anomaly_started_at, opened_at)
       VALUES ($1, $2, (SELECT id FROM trips WHERE elder_id = $1 AND started_at = $3 ORDER BY id DESC LIMIT 1),
         'warning', 'active', $4, $5, $6)
       ON CONFLICT (elder_id, key) DO NOTHING RETURNING id`,
      [elderId, w.key, w.tripStartedAt, w.anomaly, w.anomalyStartedAt, w.at]);
    if (!rows.length) return null;  // already written by an earlier run
    await addTransition(client, rows[0].id, 'opened', null, 'warning', w.at, { minutes: w.minutes });
    return String(rows[0].id);
  }
  const { rows: [event] } = await client.query<any>(
    'SELECT id, level, status, version FROM risk_events WHERE elder_id = $1 AND key = $2', [elderId, w.key]);
  if (!event || event.status !== 'active') return null;
  if (w.type === 'escalated') {
    if (event.level === 'high') return null;
    await versioned(client, event,
      `UPDATE risk_events SET level = 'high', escalated_at = $3, version = version + 1, changed_at = now() WHERE id = $1 AND version = $2`, [w.at]);
    await addTransition(client, event.id, 'escalated', 'warning', 'high', w.at, { minutes: w.minutes });
    return String(event.id);
  }
  await versioned(client, event,
    `UPDATE risk_events SET status = 'resolved', resolved_at = $3, resolution = $4, version = version + 1, changed_at = now()
     WHERE id = $1 AND version = $2`, [w.at, w.resolution]);
  await addTransition(client, event.id, 'resolved', event.level, null, w.at, { resolution: w.resolution });
  // Withdraw navigation the elder phone has not acted on.
  await client.query(`UPDATE actions SET status = 'cancelled', reason = 'riskResolved' WHERE risk_event_id = $1 AND ${ACTIVE_NAVIGATION}`, [event.id]);
  return String(event.id);
}

async function versioned(client: PoolClient, event: { id: string; version: number }, sql: string, extra: unknown[]): Promise<void> {
  const result = await client.query(sql, [event.id, event.version, ...extra]);
  if (!result.rowCount) throw new ConflictException('Risk event changed concurrently');
}

async function addTransition(client: PoolClient, eventId: string, kind: string, from: string | null, to: string | null,
  at: Date, detail: Record<string, unknown>): Promise<void> {
  await client.query(
    `INSERT INTO risk_transitions (risk_event_id, seq, kind, from_level, to_level, at, detail)
     VALUES ($1, (SELECT COALESCE(max(seq), 0) + 1 FROM risk_transitions WHERE risk_event_id = $1), $2, $3, $4, $5, $6)`,
    [eventId, kind, from, to, at, JSON.stringify(detail)]);
}

async function insertAction(client: PoolClient, elderId: number, a: ActionWrite): Promise<boolean> {
  const result = await client.query(
    `INSERT INTO actions (elder_id, risk_event_id, kind, target, idempotency_key, status, reason, details, decided_at, expires_at)
     SELECT $1, r.id, $3, $4, $5, $6, $7, $8, $9,
       CASE WHEN $10::float8 IS NULL THEN NULL ELSE now() + make_interval(secs => $10::float8) END
     FROM risk_events r WHERE r.elder_id = $1 AND r.key = $2
     ON CONFLICT (idempotency_key) DO NOTHING`,
    [elderId, a.riskKey, a.kind, a.target, `${elderId}:${a.idempotencyKey}`, a.status, a.reason, JSON.stringify(a.details),
      a.decidedAt, a.expiresInSeconds]);
  return !!result.rowCount;
}
