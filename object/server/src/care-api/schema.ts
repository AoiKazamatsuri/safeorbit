// Demo schema, applied idempotently at startup and before a reset. One pre-seeded household (T37).
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
-- One active risk event per elder at a time; writers also check the version (engineering architecture section 8).
CREATE UNIQUE INDEX IF NOT EXISTS risk_events_one_active ON risk_events (elder_id) WHERE status = 'active';
CREATE TABLE IF NOT EXISTS risk_transitions (
  id bigserial PRIMARY KEY, risk_event_id bigint NOT NULL REFERENCES risk_events(id), seq integer NOT NULL,
  kind text NOT NULL CHECK (kind IN ('opened', 'escalated', 'resolved')),
  from_level text, to_level text, at timestamptz NOT NULL, detail jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (risk_event_id, seq));
CREATE OR REPLACE FUNCTION safeorbit_append_only() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION '% is append-only', TG_TABLE_NAME; END $$;
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
`;

// The one household this Demo serves.
export const DEMO_ELDER_ID = 1;
export const DEMO_CAREGIVER_ID = 1;

// Every table a demo reset empties, children before parents.
export const RESET_TABLES = [
  'deliveries', 'actions', 'dispositions', 'call_records', 'behaviour_observations', 'risk_transitions', 'risk_events',
  'reference_routes', 'caregiver_settings', 'tracker_state', 'trips', 'location_points', 'safe_zones',
];
