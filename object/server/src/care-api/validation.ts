import { GeoPoint, isValidPoint } from './geo';

// Request bodies come from the two Demo phones; reject malformed input with 400 rather than trusting it.
export class InputError extends Error {}

export type DeviceRole = 'elder' | 'caregiver';
export interface DeviceRegistration { role: DeviceRole; installationId: string; pushToken: string | null }
export interface SafeZoneInput { name: string; center: GeoPoint; radiusMeters: number }
export interface LocationPointInput {
  sampledAt: Date; latitude: number; longitude: number;
  accuracy: number | null; speed: number | null; course: number | null;
}
export interface LocationBatch {
  points: Array<LocationPointInput | null>;  // null marks a point rejected as invalid
  batteryPercent: number | null; locationPermission: string | null; preciseLocation: boolean | null;
}

export const MAX_POINTS_PER_BATCH = 1000;
const FUTURE_TOLERANCE_MS = 5 * 60_000;
const PERMISSIONS = ['always', 'whenInUse', 'denied', 'notDetermined', 'restricted'];

const isObject = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);
const optionalNumber = (v: unknown, min: number, max: number) =>
  typeof v === 'number' && Number.isFinite(v) && v >= min && v <= max ? v : null;

export function isHomeName(name: string): boolean {
  return ['home', '家'].includes(name.trim().toLowerCase());
}

export function parseDeviceRegistration(body: unknown): DeviceRegistration {
  if (!isObject(body)) throw new InputError('Body must be an object');
  const { role, installationId, pushToken } = body;
  if (role !== 'elder' && role !== 'caregiver') throw new InputError('role must be elder or caregiver');
  if (typeof installationId !== 'string' || !/^[A-Za-z0-9-]{8,100}$/.test(installationId)) throw new InputError('installationId is invalid');
  if (pushToken !== undefined && pushToken !== null && (typeof pushToken !== 'string' || !/^[0-9a-fA-F]{32,200}$/.test(pushToken))) {
    throw new InputError('pushToken is invalid');
  }
  return { role, installationId, pushToken: typeof pushToken === 'string' ? pushToken.toLowerCase() : null };
}

export function parseSafeZone(body: unknown): SafeZoneInput {
  if (!isObject(body)) throw new InputError('Body must be an object');
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  if (name.length < 1 || name.length > 40) throw new InputError('name must be 1-40 characters');
  const center = body.center;
  if (!isObject(center) || !isValidPoint(center as Partial<GeoPoint>)) throw new InputError('center is invalid');
  const radius = body.radiusMeters;
  if (typeof radius !== 'number' || !Number.isInteger(radius) || radius < 50 || radius > 5000) {
    throw new InputError('radiusMeters must be an integer from 50 to 5000');
  }
  return { name, center: { latitude: Number(center.latitude), longitude: Number(center.longitude) }, radiusMeters: radius };
}

export function parseLocationBatch(body: unknown, now = Date.now()): LocationBatch {
  if (!isObject(body)) throw new InputError('Body must be an object');
  const { points } = body;
  if (!Array.isArray(points) || points.length === 0 || points.length > MAX_POINTS_PER_BATCH) {
    throw new InputError(`points must hold 1-${MAX_POINTS_PER_BATCH} entries`);
  }
  return {
    points: points.map(p => parsePoint(p, now)),
    batteryPercent: optionalNumber(body.batteryPercent, 0, 100) === null ? null : Math.round(body.batteryPercent as number),
    locationPermission: typeof body.locationPermission === 'string' && PERMISSIONS.includes(body.locationPermission) ? body.locationPermission : null,
    preciseLocation: typeof body.preciseLocation === 'boolean' ? body.preciseLocation : null,
  };
}

function parsePoint(p: unknown, now: number): LocationPointInput | null {
  if (!isObject(p) || typeof p.sampledAt !== 'string' || !isValidPoint(p as Partial<GeoPoint>)) return null;
  const sampledAt = new Date(p.sampledAt);
  if (Number.isNaN(sampledAt.getTime()) || sampledAt.getTime() > now + FUTURE_TOLERANCE_MS) return null;
  return {
    sampledAt, latitude: Number(p.latitude), longitude: Number(p.longitude),
    accuracy: optionalNumber(p.accuracy, 0, 10_000),
    speed: optionalNumber(p.speed, 0, 200),
    course: optionalNumber(p.course, 0, 360),
  };
}

// T38 request bodies.
export const MAX_ROUTE_POINTS = 5000;
export function parseReferenceRoute(body: unknown): GeoPoint[] {
  if (!isObject(body) || !Array.isArray(body.points)) throw new InputError('points must be an array of WGS-84 coordinates');
  const { points } = body;
  if (points.length < 2 || points.length > MAX_ROUTE_POINTS) throw new InputError(`points must hold 2-${MAX_ROUTE_POINTS} entries`);
  return points.map((p, i) => {
    if (!isObject(p) || !isValidPoint(p as Partial<GeoPoint>)) throw new InputError(`points[${i}] is invalid`);
    return { latitude: Number(p.latitude), longitude: Number(p.longitude) };
  });
}

export const SETTING_KEYS = ['autoNavigation', 'lowRiskNotifications', 'recoveryNotifications', 'limitedMonitoringNotifications'] as const;
export type SettingKey = typeof SETTING_KEYS[number];
// Any subset of the four switches; keys left out keep their stored value.
export function parseSettings(body: unknown): Partial<Record<SettingKey, boolean>> {
  if (!isObject(body)) throw new InputError('Body must be an object');
  const unknown = Object.keys(body).filter(k => !(SETTING_KEYS as readonly string[]).includes(k));
  if (unknown.length) throw new InputError(`Unknown setting: ${unknown.join(', ')}`);
  const result: Partial<Record<SettingKey, boolean>> = {};
  for (const key of SETTING_KEYS) {
    if (body[key] === undefined) continue;
    if (typeof body[key] !== 'boolean') throw new InputError(`${key} must be true or false`);
    result[key] = body[key] as boolean;
  }
  if (!Object.keys(result).length) throw new InputError('Give at least one setting');
  return result;
}

export function parseActionResult(body: unknown): { result: 'started' | 'failed'; reason: string | null } {
  if (!isObject(body)) throw new InputError('Body must be an object');
  if (body.result !== 'started' && body.result !== 'failed') throw new InputError('result must be started or failed');
  const reason = body.reason;
  if (reason !== undefined && reason !== null && (typeof reason !== 'string' || reason.length > 200)) {
    throw new InputError('reason must be text of at most 200 characters');
  }
  return { result: body.result, reason: typeof reason === 'string' && reason.trim() ? reason.trim() : null };
}

export function parseCallRecord(body: unknown): { riskEventId: string | null } {
  if (body === undefined || body === null) return { riskEventId: null };
  if (!isObject(body)) throw new InputError('Body must be an object');
  const id = body.riskEventId;
  if (id === undefined || id === null) return { riskEventId: null };
  if (typeof id !== 'string' || !/^\d{1,18}$/.test(id)) throw new InputError('riskEventId is invalid');
  return { riskEventId: id };
}
