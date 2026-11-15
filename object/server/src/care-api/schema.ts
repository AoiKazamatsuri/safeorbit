import { PoolClient } from 'pg';

// Applied idempotently at startup; existing household 1 remains the isolated demo family.
// Risk and outreach tables (T38): reference routes, behaviour observations, risk events with append-only
// transitions, actions with delivery records, dispositions, call records and caregiver settings.
export const SCHEMA_SQL = `
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE TABLE IF NOT EXISTS elders (
  id integer PRIMARY KEY, name text NOT NULL, call_name text NOT NULL,
  phone text NOT NULL, timezone text NOT NULL);
CREATE TABLE IF NOT EXISTS caregivers (
  id integer PRIMARY KEY, elder_id integer NOT NULL REFERENCES elders(id),
  name text NOT NULL, phone text NOT NULL, is_primary boolean NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), installation_id text NOT NULL UNIQUE,
  role text NOT NULL CHECK (role IN ('elder', 'caregiver')),
  elder_id integer NOT NULL REFERENCES elders(id), token_hash text NOT NULL UNIQUE,
  push_token text, battery_percent smallint, location_permission text, precise_location boolean,
  created_at timestamptz NOT NULL DEFAULT now(), last_seen_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS safe_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), elder_id integer NOT NULL REFERENCES elders(id),
  name text NOT NULL, is_home boolean NOT NULL, latitude double precision NOT NULL,
  longitude double precision NOT NULL, radius_m integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now());
CREATE UNIQUE INDEX IF NOT EXISTS safe_zones_one_home ON safe_zones (elder_id) WHERE is_home;
CREATE TABLE IF NOT EXISTS location_points (
  id bigserial PRIMARY KEY, elder_id integer NOT NULL REFERENCES elders(id),
  sampled_at timestamptz NOT NULL, latitude double precision NOT NULL, longitude double precision NOT NULL,
  accuracy_m real, speed_mps real, course_deg real, geog geography(Point, 4326) NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(), UNIQUE (elder_id, sampled_at));
ALTER TABLE location_points ADD COLUMN IF NOT EXISTS history_replay boolean NOT NULL DEFAULT false;
CREATE TABLE IF NOT EXISTS trips (
  id bigserial PRIMARY KEY, elder_id integer NOT NULL REFERENCES elders(id),
  started_at timestamptz NOT NULL, ended_at timestamptz, start_known boolean NOT NULL,
  stops text[] NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS trips_elder_started ON trips (elder_id, started_at DESC);
CREATE TABLE IF NOT EXISTS tracker_state (
  elder_id integer PRIMARY KEY REFERENCES elders(id), phase text NOT NULL,
  active_trip_id bigint REFERENCES trips(id), processed_through timestamptz,
  state jsonb NOT NULL, updated_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE tracker_state ADD COLUMN IF NOT EXISTS risk_state jsonb;
ALTER TABLE tracker_state ADD COLUMN IF NOT EXISTS history_replay boolean NOT NULL DEFAULT false;

-- Planned walking route home -> zone (WGS-84), one per non-home zone; goes with its zone.
CREATE TABLE IF NOT EXISTS reference_routes (
  zone_id uuid PRIMARY KEY REFERENCES safe_zones(id) ON DELETE CASCADE,
  elder_id integer NOT NULL REFERENCES elders(id), points jsonb NOT NULL,
  source text NOT NULL CHECK (source IN ('phone', 'seed')), uploaded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS risk_events (
  id bigserial PRIMARY KEY, elder_id integer NOT NULL REFERENCES elders(id), key text NOT NULL,
  trip_id bigint REFERENCES trips(id),
  level text NOT NULL CHECK (level IN ('warning', 'high')),
  status text NOT NULL CHECK (status IN ('active', 'resolved')),
  anomaly text NOT NULL CHECK (anomaly IN ('wandering', 'deviation')),
  anomaly_started_at timestamptz NOT NULL, opened_at timestamptz NOT NULL, escalated_at timestamptz,
  resolved_at timestamptz, resolution text CHECK (resolution IN ('home', 'met')),
  false_alarm boolean NOT NULL DEFAULT false, explanation text,
  version integer NOT NULL DEFAULT 1, created_at timestamptz NOT NULL DEFAULT now(),
  changed_at timestamptz NOT NULL DEFAULT now(),  -- server time of the latest write
  UNIQUE (elder_id, key));
ALTER TABLE risk_events ADD COLUMN IF NOT EXISTS history_replay boolean NOT NULL DEFAULT false;
-- One active risk event per elder at a time; writers also check the version (engineering architecture section 8).
CREATE UNIQUE INDEX IF NOT EXISTS risk_events_one_active ON risk_events (elder_id) WHERE status = 'active';
CREATE TABLE IF NOT EXISTS risk_transitions (
  id bigserial PRIMARY KEY, risk_event_id bigint NOT NULL REFERENCES risk_events(id), seq integer NOT NULL,
  kind text NOT NULL CHECK (kind IN ('opened', 'escalated', 'resolved')),
  from_level text, to_level text, at timestamptz NOT NULL, detail jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (risk_event_id, seq));
CREATE OR REPLACE FUNCTION safeorbit_append_only() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' AND EXISTS (
    SELECT 1 FROM risk_events WHERE id = OLD.risk_event_id
      AND elder_id::text = current_setting('safeorbit.delete_elder_id', true)
  ) THEN RETURN OLD; END IF;
  RAISE EXCEPTION '% is append-only', TG_TABLE_NAME;
END $$;
DROP TRIGGER IF EXISTS risk_transitions_append_only ON risk_transitions;
CREATE TRIGGER risk_transitions_append_only BEFORE UPDATE OR DELETE ON risk_transitions
  FOR EACH ROW EXECUTE FUNCTION safeorbit_append_only();
CREATE TABLE IF NOT EXISTS behaviour_observations (
  id bigserial PRIMARY KEY, elder_id integer NOT NULL REFERENCES elders(id), key text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('wandering', 'deviation')),
  started_at timestamptz NOT NULL, ended_at timestamptz, features jsonb NOT NULL,
  rule_version text NOT NULL, risk_event_id bigint REFERENCES risk_events(id),
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (elder_id, key));
CREATE TABLE IF NOT EXISTS actions (
  id bigserial PRIMARY KEY, elder_id integer NOT NULL REFERENCES elders(id),
  risk_event_id bigint NOT NULL REFERENCES risk_events(id),
  kind text NOT NULL CHECK (kind IN ('startNavigation', 'notifyLow', 'notifyHigh', 'notifyResolved')),
  target text NOT NULL CHECK (target IN ('elder', 'caregivers')),
  idempotency_key text NOT NULL UNIQUE, status text NOT NULL, reason text, details jsonb NOT NULL DEFAULT '{}',
  decided_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz,
  delivered_at timestamptz, result_at timestamptz);
CREATE INDEX IF NOT EXISTS actions_pending ON actions (elder_id, status);
CREATE TABLE IF NOT EXISTS deliveries (
  id bigserial PRIMARY KEY, action_id bigint NOT NULL REFERENCES actions(id), device_id uuid,
  channel text NOT NULL CHECK (channel IN ('apns', 'uploadReply')), result text NOT NULL, detail text,
  at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS dispositions (
  id bigserial PRIMARY KEY, risk_event_id bigint NOT NULL REFERENCES risk_events(id),
  kind text NOT NULL CHECK (kind IN ('met', 'falseAlarm')), caregiver_id integer NOT NULL REFERENCES caregivers(id),
  device_id uuid, at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS call_records (
  id bigserial PRIMARY KEY, elder_id integer NOT NULL REFERENCES elders(id), risk_event_id bigint REFERENCES risk_events(id),
  caregiver_id integer NOT NULL REFERENCES caregivers(id), device_id uuid, at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS caregiver_settings (
  caregiver_id integer PRIMARY KEY REFERENCES caregivers(id),
  auto_navigation boolean NOT NULL DEFAULT true, low_risk_notifications boolean NOT NULL DEFAULT true,
  recovery_notifications boolean NOT NULL DEFAULT true, limited_monitoring_notifications boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now());
CREATE SEQUENCE IF NOT EXISTS state_change_seq;
CREATE SEQUENCE IF NOT EXISTS family_elder_id_seq START WITH 2;
CREATE SEQUENCE IF NOT EXISTS family_caregiver_id_seq START WITH 2;
ALTER TABLE elders ALTER COLUMN id SET DEFAULT nextval('family_elder_id_seq');
ALTER TABLE caregivers ALTER COLUMN id SET DEFAULT nextval('family_caregiver_id_seq');
CREATE TABLE IF NOT EXISTS families (
  elder_id integer PRIMARY KEY REFERENCES elders(id), invite_code text UNIQUE,
  is_demo boolean NOT NULL DEFAULT false,
  CHECK ((is_demo AND elder_id = 1 AND invite_code IS NULL)
    OR (NOT is_demo AND elder_id <> 1 AND invite_code ~ '^[A-Z0-9]{12}$')));
-- Only the pre-existing demo is migrated; startup never invents an ordinary membership.
INSERT INTO families (elder_id, is_demo) SELECT id, true FROM elders WHERE id = 1 ON CONFLICT DO NOTHING;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS caregiver_id integer REFERENCES caregivers(id);
ALTER TABLE devices ADD COLUMN IF NOT EXISTS is_demo boolean NOT NULL DEFAULT false;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS revoked_at timestamptz;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS enrollment_hash text;
UPDATE devices SET is_demo = true, caregiver_id = CASE WHEN role = 'caregiver' THEN 1 ELSE NULL END
  WHERE elder_id = 1 AND NOT is_demo;
CREATE UNIQUE INDEX IF NOT EXISTS devices_one_family_elder ON devices(elder_id)
  WHERE role = 'elder' AND revoked_at IS NULL AND NOT is_demo;
CREATE TABLE IF NOT EXISTS caregiver_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email text NOT NULL UNIQUE,
  password_hash text NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS caregiver_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), account_id uuid NOT NULL REFERENCES caregiver_accounts(id),
  token_hash text NOT NULL UNIQUE, created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '30 days');
ALTER TABLE caregivers ADD COLUMN IF NOT EXISTS account_id uuid REFERENCES caregiver_accounts(id);
ALTER TABLE caregivers ADD COLUMN IF NOT EXISTS member_id uuid;
ALTER TABLE caregivers ADD COLUMN IF NOT EXISTS departed_at timestamptz;
UPDATE caregivers c SET member_id = COALESCE(
  (SELECT d.id FROM devices d WHERE d.caregiver_id = c.id AND d.revoked_at IS NULL ORDER BY d.created_at,d.id LIMIT 1),
  gen_random_uuid()) WHERE member_id IS NULL;
ALTER TABLE caregivers ALTER COLUMN member_id SET DEFAULT gen_random_uuid();
ALTER TABLE caregivers ALTER COLUMN member_id SET NOT NULL;
UPDATE caregivers c SET departed_at = now(),is_primary = false
  WHERE c.elder_id <> 1 AND c.account_id IS NULL AND c.departed_at IS NULL
    AND NOT EXISTS (SELECT 1 FROM devices d WHERE d.caregiver_id = c.id AND d.revoked_at IS NULL);
CREATE UNIQUE INDEX IF NOT EXISTS caregivers_member_id ON caregivers(member_id);
CREATE UNIQUE INDEX IF NOT EXISTS caregivers_one_account_family ON caregivers(account_id)
  WHERE departed_at IS NULL AND account_id IS NOT NULL;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS account_session_id uuid REFERENCES caregiver_sessions(id) ON DELETE CASCADE;
CREATE UNIQUE INDEX IF NOT EXISTS devices_one_account_session ON devices(account_session_id)
  WHERE account_session_id IS NOT NULL AND revoked_at IS NULL;

`;

// The one household this Demo serves.
export const DEMO_ELDER_ID = 1;
export const DEMO_CAREGIVER_ID = 1;

// Delete only one household's business data. The trigger exemption is transaction-local and
// checks the parent event, so ordinary UPDATE/DELETE and other families remain append-only.
export async function clearHouseholdData(client: PoolClient, elderId: number): Promise<void> {
  await client.query("SELECT set_config('safeorbit.delete_elder_id', $1, true)", [String(elderId)]);
  await client.query('DELETE FROM deliveries WHERE action_id IN (SELECT id FROM actions WHERE elder_id = $1)', [elderId]);
  for (const table of ['dispositions', 'risk_transitions']) {
    await client.query(`DELETE FROM ${table} WHERE risk_event_id IN (SELECT id FROM risk_events WHERE elder_id = $1)`, [elderId]);
  }
  for (const table of ['actions', 'call_records', 'behaviour_observations', 'risk_events', 'reference_routes',
    'tracker_state', 'trips', 'location_points', 'safe_zones']) {
    await client.query(`DELETE FROM ${table} WHERE elder_id = $1`, [elderId]);
  }
  await client.query('DELETE FROM caregiver_settings WHERE caregiver_id IN (SELECT id FROM caregivers WHERE elder_id = $1)', [elderId]);
  await client.query("SELECT set_config('safeorbit.delete_elder_id', '', true)");
}
