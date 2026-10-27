import { ConflictException, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';
import { PoolClient } from 'pg';
import { DatabaseService } from './database.service';
import { GeoPoint } from './geo';
import { DEMO_CAREGIVER_ID, DEMO_ELDER_ID, RESET_TABLES } from './schema';
import { DeviceRegistration, DeviceRole, isHomeName, LocationBatch, SafeZoneInput } from './validation';

export interface Household {
  elder: { name: string; callName: string; phone: string; timezone: string };
  caregiver: { name: string; phone: string };
}
// referenceRoutes: zone name -> planned WGS-84 walking route from home, for zones seeded without a phone.
export interface HouseholdSeed extends Household { safeZones: SafeZoneInput[]; referenceRoutes?: Record<string, GeoPoint[]> }
export interface Device { id: string; role: DeviceRole; elderId: number }
export interface SafeZone { id: string; name: string; isHome: boolean; center: GeoPoint; radiusMeters: number }
export interface StoredFix {
  sampledAt: Date; latitude: number; longitude: number;
  accuracy: number | null; speed: number | null; course: number | null;
}
export interface TripRecord { id: string; startedAt: Date; endedAt: Date | null; startKnown: boolean; stops: string[] }
export interface TrackerRecord { phase: string; activeTripId: string | null; processedThrough: Date | null; state: unknown; riskState: unknown }
export interface TrackingNext { phase: string; processedThrough: Date | null; state: unknown }
export type TripChange =
  | { type: 'started'; startedAt: Date; startKnown: boolean; stops: string[] }
  | { type: 'stops'; stops: string[] }
  | { type: 'ended'; endedAt: Date; stops: string[] };
export type PointStatus = 'accepted' | 'duplicate' | 'invalid';

const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');
const zoneRow = (r: any): SafeZone => ({
  id: r.id, name: r.name, isHome: r.is_home,
  center: { latitude: r.latitude, longitude: r.longitude }, radiusMeters: r.radius_m,
});
const fixRow = (r: any): StoredFix => ({
  sampledAt: r.sampled_at, latitude: r.latitude, longitude: r.longitude,
  accuracy: r.accuracy_m, speed: r.speed_mps, course: r.course_deg,
});
const tripRow = (r: any): TripRecord => ({
  id: String(r.id), startedAt: r.started_at, endedAt: r.ended_at, startKnown: r.start_known, stops: r.stops,
});

// The only reader and writer of the care database (architecture principle 3).
@Injectable()
export class CareStore {
  constructor(private readonly db: DatabaseService) {}

  async registerDevice(input: DeviceRegistration): Promise<{ token: string; device: Device }> {
    const [elder] = await this.db.query<{ id: number }>('SELECT id FROM elders WHERE id = $1', [DEMO_ELDER_ID]);
    if (!elder) throw new ServiceUnavailableException('Household is not seeded; run the demo reset first');
    const token = randomBytes(32).toString('base64url');
    const [row] = await this.db.query<{ id: string }>(
      `INSERT INTO devices (installation_id, role, elder_id, token_hash, push_token)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (installation_id) DO UPDATE SET role = EXCLUDED.role, token_hash = EXCLUDED.token_hash,
         push_token = COALESCE(EXCLUDED.push_token, devices.push_token), last_seen_at = now()
       RETURNING id`,
      [input.installationId, input.role, elder.id, hashToken(token), input.pushToken]);
    return { token, device: { id: row.id, role: input.role, elderId: elder.id } };
  }

  async deviceByToken(token: string): Promise<Device | null> {
    const [row] = await this.db.query<{ id: string; role: DeviceRole; elder_id: number }>(
      'UPDATE devices SET last_seen_at = now() WHERE token_hash = $1 RETURNING id, role, elder_id', [hashToken(token)]);
    return row ? { id: row.id, role: row.role, elderId: row.elder_id } : null;
  }

  async household(elderId: number): Promise<Household> {
    const [row] = await this.db.query<any>(
      `SELECT e.name, e.call_name, e.phone, e.timezone, c.name AS c_name, c.phone AS c_phone
       FROM elders e JOIN caregivers c ON c.elder_id = e.id AND c.is_primary WHERE e.id = $1`, [elderId]);
    if (!row) throw new ServiceUnavailableException('Household is not seeded');
    return {
      elder: { name: row.name, callName: row.call_name, phone: row.phone, timezone: row.timezone },
      caregiver: { name: row.c_name, phone: row.c_phone },
    };
  }

  async elderDevice(elderId: number): Promise<{ batteryPercent: number | null } | null> {
    const [row] = await this.db.query<{ battery_percent: number | null }>(
      `SELECT battery_percent FROM devices WHERE elder_id = $1 AND role = 'elder' ORDER BY last_seen_at DESC LIMIT 1`, [elderId]);
    return row ? { batteryPercent: row.battery_percent } : null;
  }

  async safeZones(elderId: number): Promise<SafeZone[]> {
    return (await this.db.query('SELECT * FROM safe_zones WHERE elder_id = $1 ORDER BY is_home DESC, created_at', [elderId])).map(zoneRow);
  }

  async createSafeZone(elderId: number, input: SafeZoneInput): Promise<SafeZone> {
    const isHome = isHomeName(input.name);
    if (isHome && (await this.safeZones(elderId)).some(z => z.isHome)) throw new ConflictException('A home zone already exists');
    const [row] = await this.db.query(
      `INSERT INTO safe_zones (elder_id, name, is_home, latitude, longitude, radius_m)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [elderId, input.name, isHome, input.center.latitude, input.center.longitude, input.radiusMeters]);
    return zoneRow(row);
  }

  async updateSafeZone(elderId: number, id: string, input: SafeZoneInput): Promise<SafeZone> {
    const zones = await this.safeZones(elderId);
    const zone = zones.find(z => z.id === id);
    if (!zone) throw new NotFoundException('Safe zone not found');
    const isHome = isHomeName(input.name);
    if (zone.isHome && !isHome) throw new ConflictException('The home zone must keep its home name');
    if (!zone.isHome && isHome && zones.some(z => z.isHome)) throw new ConflictException('A home zone already exists');
    return this.db.transaction(async client => {
      const { rows: [row] } = await client.query(
        `UPDATE safe_zones SET name = $3, is_home = $4, latitude = $5, longitude = $6, radius_m = $7
         WHERE elder_id = $1 AND id = $2 RETURNING *`,
        [elderId, id, input.name, isHome, input.center.latitude, input.center.longitude, input.radiusMeters]);
      // A moved zone needs a newly planned route; until the caregiver phone uploads it, deviation has no reference there.
      if (zone.center.latitude !== input.center.latitude || zone.center.longitude !== input.center.longitude) {
        await client.query('DELETE FROM reference_routes WHERE zone_id = $1', [id]);
      }
      return zoneRow(row);
    });
  }

  // Its reference route goes with it (ON DELETE CASCADE).
  async deleteSafeZone(elderId: number, id: string): Promise<void> {
    const zone = (await this.safeZones(elderId)).find(z => z.id === id);
    if (!zone) throw new NotFoundException('Safe zone not found');
    if (zone.isHome) throw new ConflictException('The home zone cannot be deleted');
    await this.db.query('DELETE FROM safe_zones WHERE elder_id = $1 AND id = $2', [elderId, id]);
  }

  // Stores valid points; repeated sample times are reported as duplicates, not stored twice.
  async storePoints(device: Device, batch: LocationBatch): Promise<PointStatus[]> {
    const valid = batch.points.flatMap((p, index) => (p ? [{ p, index }] : []));
    const statuses: PointStatus[] = batch.points.map(p => (p ? 'duplicate' : 'invalid'));
    await this.db.transaction(async client => {
      await client.query(
        `UPDATE devices SET battery_percent = COALESCE($2, battery_percent),
           location_permission = COALESCE($3, location_permission), precise_location = COALESCE($4, precise_location)
         WHERE id = $1`, [device.id, batch.batteryPercent, batch.locationPermission, batch.preciseLocation]);
      if (!valid.length) return;
      const inserted = await client.query<{ sampled_at: Date }>(
        `INSERT INTO location_points (elder_id, sampled_at, latitude, longitude, accuracy_m, speed_mps, course_deg, geog)
         SELECT $1, t, lat, lon, acc, spd, crs, ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
         FROM unnest($2::timestamptz[], $3::float8[], $4::float8[], $5::float4[], $6::float4[], $7::float4[])
           AS u(t, lat, lon, acc, spd, crs)
         ON CONFLICT (elder_id, sampled_at) DO NOTHING RETURNING sampled_at`,
        [device.elderId, valid.map(v => v.p.sampledAt), valid.map(v => v.p.latitude), valid.map(v => v.p.longitude),
          valid.map(v => v.p.accuracy), valid.map(v => v.p.speed), valid.map(v => v.p.course)]);
      const fresh = new Set(inserted.rows.map(r => r.sampled_at.getTime()));
      for (const { p, index } of valid) {
        if (fresh.delete(p.sampledAt.getTime())) statuses[index] = 'accepted';
      }
    });
    return statuses;
  }

  async pointsAfter(elderId: number, after: Date | null, limit: number): Promise<StoredFix[]> {
    return (await this.db.query(
      `SELECT sampled_at, latitude, longitude, accuracy_m, speed_mps, course_deg FROM location_points
       WHERE elder_id = $1 AND ($2::timestamptz IS NULL OR sampled_at > $2) ORDER BY sampled_at LIMIT $3`,
      [elderId, after, limit])).map(fixRow);
  }

  async pointsSince(elderId: number, since: Date, limit: number): Promise<StoredFix[]> {
    return (await this.db.query(
      `SELECT * FROM (SELECT sampled_at, latitude, longitude, accuracy_m, speed_mps, course_deg FROM location_points
         WHERE elder_id = $1 AND sampled_at >= $2 ORDER BY sampled_at DESC LIMIT $3) recent ORDER BY sampled_at`,
      [elderId, since, limit])).map(fixRow);
  }

  async latestPoints(elderId: number, count: number): Promise<StoredFix[]> {
    return (await this.db.query(
      `SELECT sampled_at, latitude, longitude, accuracy_m, speed_mps, course_deg FROM location_points
       WHERE elder_id = $1 ORDER BY sampled_at DESC LIMIT $2`, [elderId, count])).map(fixRow);
  }

  async trackedElderIds(): Promise<number[]> {
    return (await this.db.query<{ elder_id: number }>('SELECT elder_id FROM tracker_state')).map(r => r.elder_id);
  }

  async tracker(elderId: number): Promise<TrackerRecord | null> {
    const [row] = await this.db.query<any>('SELECT * FROM tracker_state WHERE elder_id = $1', [elderId]);
    return row ? {
      phase: row.phase, activeTripId: row.active_trip_id === null ? null : String(row.active_trip_id),
      processedThrough: row.processed_through, state: row.state, riskState: row.risk_state,
    } : null;
  }

  // Trip changes and the tracker state that produced them are written in one transaction.
  async recordTracking(elderId: number, changes: TripChange[], next: TrackingNext): Promise<void> {
    await this.db.transaction(client => applyTracking(client, elderId, changes, next));
  }

  async activeTrip(elderId: number): Promise<TripRecord | null> {
    const [row] = await this.db.query(
      'SELECT t.* FROM tracker_state s JOIN trips t ON t.id = s.active_trip_id WHERE s.elder_id = $1', [elderId]);
    return row ? tripRow(row) : null;
  }

  async trip(elderId: number, id: string): Promise<TripRecord | null> {
    const [row] = await this.db.query('SELECT * FROM trips WHERE elder_id = $1 AND id = $2', [elderId, id]);
    return row ? tripRow(row) : null;
  }

  async pointsBetween(elderId: number, from: Date, to: Date | null, limit: number): Promise<StoredFix[]> {
    return (await this.db.query(
      `SELECT sampled_at, latitude, longitude, accuracy_m, speed_mps, course_deg FROM location_points
       WHERE elder_id = $1 AND sampled_at >= $2 AND ($3::timestamptz IS NULL OR sampled_at <= $3) ORDER BY sampled_at LIMIT $4`,
      [elderId, from, to, limit])).map(fixRow);
  }

  async trips(elderId: number, limit: number): Promise<TripRecord[]> {
    return (await this.db.query('SELECT * FROM trips WHERE elder_id = $1 ORDER BY started_at DESC LIMIT $2', [elderId, limit])).map(tripRow);
  }

  // Demo reset: back to the seeded household with no history. Registered phones are kept unless asked.
  async reset(seed: HouseholdSeed, options: { devices: boolean }): Promise<void> {
    if (seed.safeZones.filter(z => isHomeName(z.name)).length !== 1) throw new Error('The seed needs exactly one home zone');
    await this.db.transaction(async client => {
      await client.query(`TRUNCATE ${[...RESET_TABLES, ...(options.devices ? ['devices'] : [])].join(', ')}`);
      await client.query(
        `INSERT INTO elders (id, name, call_name, phone, timezone) VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (id) DO UPDATE SET name = $2, call_name = $3, phone = $4, timezone = $5`,
        [DEMO_ELDER_ID, seed.elder.name, seed.elder.callName, seed.elder.phone, seed.elder.timezone]);
      await client.query(
        `INSERT INTO caregivers (id, elder_id, name, phone, is_primary) VALUES ($1, $2, $3, $4, true)
         ON CONFLICT (id) DO UPDATE SET name = $3, phone = $4, is_primary = true`,
        [DEMO_CAREGIVER_ID, DEMO_ELDER_ID, seed.caregiver.name, seed.caregiver.phone]);
      for (const z of seed.safeZones) {
        const { rows: [zone] } = await client.query<{ id: string }>(
          `INSERT INTO safe_zones (elder_id, name, is_home, latitude, longitude, radius_m) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
          [DEMO_ELDER_ID, z.name, isHomeName(z.name), z.center.latitude, z.center.longitude, z.radiusMeters]);
        const route = seed.referenceRoutes?.[z.name];
        if (route && !isHomeName(z.name)) {
          await client.query(`INSERT INTO reference_routes (zone_id, elder_id, points, source) VALUES ($1, $2, $3, 'seed')`,
            [zone.id, DEMO_ELDER_ID, JSON.stringify(route)]);
        }
      }
    });
  }
}

// Trip changes and the tracker state that produced them, inside the caller's transaction. riskState is
// written alongside when given, so trip and risk processing commit together.
export async function applyTracking(client: PoolClient, elderId: number, changes: TripChange[], next: TrackingNext,
  riskState?: unknown): Promise<void> {
  const current = await client.query<{ active_trip_id: string | null }>(
    'SELECT active_trip_id FROM tracker_state WHERE elder_id = $1 FOR UPDATE', [elderId]);
  let tripId = current.rows[0]?.active_trip_id ?? null;
  for (const change of changes) tripId = await applyTripChange(client, elderId, tripId, change);
  await client.query(
    `INSERT INTO tracker_state (elder_id, phase, active_trip_id, processed_through, state, risk_state, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, now())
     ON CONFLICT (elder_id) DO UPDATE SET phase = EXCLUDED.phase, active_trip_id = EXCLUDED.active_trip_id,
       processed_through = EXCLUDED.processed_through, state = EXCLUDED.state,
       risk_state = COALESCE(EXCLUDED.risk_state, tracker_state.risk_state), updated_at = now()`,
    [elderId, next.phase, tripId, next.processedThrough, JSON.stringify(next.state),
      riskState === undefined ? null : JSON.stringify(riskState)]);
}

async function applyTripChange(client: PoolClient, elderId: number, tripId: string | null, change: TripChange): Promise<string | null> {
  if (change.type === 'started') {
    const { rows } = await client.query<{ id: string }>(
      'INSERT INTO trips (elder_id, started_at, start_known, stops) VALUES ($1, $2, $3, $4) RETURNING id',
      [elderId, change.startedAt, change.startKnown, change.stops]);
    return String(rows[0].id);
  }
  if (tripId === null) return null;
  if (change.type === 'stops') {
    await client.query('UPDATE trips SET stops = $2 WHERE id = $1', [tripId, change.stops]);
    return tripId;
  }
  await client.query('UPDATE trips SET ended_at = $2, stops = $3 WHERE id = $1', [tripId, change.endedAt, change.stops]);
  return null;
}
