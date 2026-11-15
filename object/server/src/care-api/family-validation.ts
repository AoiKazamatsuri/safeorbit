import { Household } from './care-store';
import { DeviceRole, InputError, parseSafeZone, SafeZoneInput } from './validation';

export interface FamilyCredentials { installationId: string; deviceToken: string }
export interface CreateFamily extends FamilyCredentials, Household { home: SafeZoneInput }
export interface JoinFamily extends FamilyCredentials { inviteCode: string; role: DeviceRole; name?: string; phone?: string }
export function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new InputError('Body must be an object');
  return value as Record<string, unknown>;
}
function text(value: unknown, field: string, max: number): string {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max || /[\x00-\x1f\x7f]/.test(value)) {
    throw new InputError(`${field} is invalid`);
  }
  return value.trim();
}
function credentials(body: Record<string, unknown>): FamilyCredentials {
  if (typeof body.installationId !== 'string' || !/^[A-Za-z0-9-]{8,100}$/.test(body.installationId)) throw new InputError('installationId is invalid');
  if (typeof body.deviceToken !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(body.deviceToken)
    || Buffer.from(body.deviceToken, 'base64url').toString('base64url') !== body.deviceToken) throw new InputError('deviceToken is invalid');
  return { installationId: body.installationId, deviceToken: body.deviceToken };
}
function phone(value: unknown): string {
  const result = text(value, 'phone', 40);
  if (!/^\+?[0-9 ()-]{3,40}$/.test(result)) throw new InputError('phone is invalid');
  return result;
}
export function parseCreateFamily(value: unknown): CreateFamily {
  const body = object(value), elder = object(body.elder), caregiver = object(body.caregiver), home = object(body.home);
  const timezone = text(elder.timezone, 'timezone', 100);
  try { new Intl.DateTimeFormat('en', { timeZone: timezone }).format(); } catch { throw new InputError('timezone is invalid'); }
  return {
    ...credentials(body),
    elder: { name: text(elder.name, 'name', 100), callName: text(elder.callName, 'callName', 100), phone: phone(elder.phone), timezone },
    caregiver: { name: text(caregiver.name, 'name', 100), phone: phone(caregiver.phone) },
    home: parseSafeZone({ name: 'Home', center: { latitude: home.latitude, longitude: home.longitude }, radiusMeters: home.radiusMeters }),
  };
}
export function parseJoinFamily(value: unknown): JoinFamily {
  const body = object(value);
  const inviteCode = typeof body.inviteCode === 'string' ? body.inviteCode.trim().toUpperCase() : '';
  if (!/^[A-Z0-9]{12}$/.test(inviteCode)) throw new InputError('inviteCode is invalid');
  if (body.role !== 'elder' && body.role !== 'caregiver') throw new InputError('role is invalid');
  return { ...credentials(body), inviteCode, role: body.role,
    ...(body.role === 'caregiver' ? { name: text(body.name, 'name', 100), phone: phone(body.phone) } : {}) };
}
export function parsePushToken(value: unknown): string {
  const token = object(value).pushToken;
  if (typeof token !== 'string' || !/^[a-fA-F0-9]{32,200}$/.test(token)) throw new InputError('pushToken is invalid');
  return token.toLowerCase();
}
