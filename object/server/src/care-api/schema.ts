// Demo schema, applied idempotently at startup and before a reset. One pre-seeded household (T37).
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
`;

// The one household this Demo serves.
export const DEMO_ELDER_ID = 1;
export const DEMO_CAREGIVER_ID = 1;
