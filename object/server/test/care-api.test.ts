import assert from 'node:assert/strict';
import { test } from 'node:test';
import { SafeZone, StoredFix } from '../src/care-api/care-store';
import { buildSnapshot } from '../src/care-api/location-view';
import { parseSeed } from '../src/care-api/reset-cli';
import {
  InputError, isHomeName, parseDeviceRegistration, parseLocationBatch, parseSafeZone,
} from '../src/care-api/validation';

const NOW = Date.UTC(2026, 9, 26, 2, 0, 0);
const point = (offsetS: number, extra: object = {}) =>
  ({ sampledAt: new Date(NOW + offsetS * 1000).toISOString(), latitude: 32.06, longitude: 118.77, ...extra });

test('a location batch keeps valid points and marks malformed ones', () => {
  const batch = parseLocationBatch({
    points: [point(-10, { accuracy: 8, speed: 1.1, course: 90 }), point(-5, { latitude: 120 }), point(600), { sampledAt: 'later' }],
    batteryPercent: 45.4, locationPermission: 'always', preciseLocation: true,
  }, NOW);
  assert.equal(batch.points[0]?.accuracy, 8);
  assert.deepEqual(batch.points.slice(1), [null, null, null]);  // bad latitude, 10 min in the future, bad time
  assert.deepEqual([batch.batteryPercent, batch.locationPermission, batch.preciseLocation], [45, 'always', true]);
  assert.equal(parseLocationBatch({ points: [point(-1)], batteryPercent: 140, locationPermission: 'maybe' }, NOW).batteryPercent, null);
  assert.throws(() => parseLocationBatch({ points: [] }, NOW), InputError);
  assert.throws(() => parseLocationBatch([point(0)], NOW), InputError);
});

test('safe zones need a name, a valid centre and a sensible radius; Home marks the home zone', () => {
  const zone = parseSafeZone({ name: ' Market ', center: { latitude: 32.05, longitude: 118.77 }, radiusMeters: 200 });
  assert.deepEqual(zone, { name: 'Market', center: { latitude: 32.05, longitude: 118.77 }, radiusMeters: 200 });
  for (const bad of [{ ...zone, name: '' }, { ...zone, radiusMeters: 20 }, { ...zone, radiusMeters: 150.5 }, { ...zone, center: { latitude: 91, longitude: 0 } }]) {
    assert.throws(() => parseSafeZone(bad), InputError);
  }
  assert.ok(isHomeName('home') && isHomeName(' Home ') && isHomeName('家'));
  assert.ok(!isHomeName('Homeland'));
});

test('phones register as elder or caregiver with a stable installation id', () => {
  assert.deepEqual(parseDeviceRegistration({ role: 'elder', installationId: 'A1B2C3D4-E5F6' }),
    { role: 'elder', installationId: 'A1B2C3D4-E5F6', pushToken: null });
  assert.throws(() => parseDeviceRegistration({ role: 'admin', installationId: 'A1B2C3D4-E5F6' }), InputError);
  assert.throws(() => parseDeviceRegistration({ role: 'caregiver', installationId: 'x' }), InputError);
});

test('the reset seed needs both people and parses its safe zones', () => {
  const seed = parseSeed({
    elder: { name: 'Li Lan', callName: 'Grandma', phone: '+12025550100', timezone: 'Asia/Shanghai' },
    caregiver: { name: 'Wang Min', phone: '+12025550101' },
    safeZones: [{ name: 'Home', center: { latitude: 32.06, longitude: 118.77 }, radiusMeters: 100 }],
  });
  assert.equal(seed.safeZones[0].radiusMeters, 100);
  assert.throws(() => parseSeed({ elder: {}, caregiver: {}, safeZones: [] }), InputError);
});

const HOME: SafeZone = { id: 'h', name: 'Home', isHome: true, center: { latitude: 32.06, longitude: 118.7665 }, radiusMeters: 100 };
const MARKET: SafeZone = { id: 'm', name: 'Market', isHome: false, center: { latitude: 32.056, longitude: 118.77 }, radiusMeters: 100 };
const fix = (latitude: number, longitude: number, t: number, course: number | null = null): StoredFix =>
  ({ sampledAt: new Date(t), latitude, longitude, accuracy: 5, speed: null, course });

test('the location snapshot says where she is in the shape the App decodes', () => {
  const atMarket = buildSnapshot({
    latest: [fix(32.056, 118.77, NOW), fix(32.0565, 118.77, NOW - 5000)], phase: 'trip', tripStops: ['Home', 'Market'],
    trail: [fix(32.06, 118.7665, NOW - 600_000), fix(32.056, 118.77, NOW)], zones: [HOME, MARKET], batteryPercent: 45,
  });
  assert.equal(atMarket.status, 'At Market');
  assert.equal(atMarket.recordedAt, new Date(NOW).toISOString());
  assert.equal(Math.round(atMarket.heading!), 180);  // moved due south
  assert.equal(atMarket.tripName, 'Home–Market');
  assert.deepEqual(atMarket.trail[0], { latitude: 32.06, longitude: 118.7665 });
  assert.deepEqual(Object.keys(atMarket.safeZones[0]), ['id', 'name', 'isHome', 'center', 'radiusMeters']);

  const base = { tripStops: null, trail: [], zones: [HOME, MARKET], batteryPercent: null };
  assert.equal(buildSnapshot({ ...base, latest: [fix(32.06, 118.7665, NOW, 45)], phase: 'home' }).status, 'At Home');
  assert.equal(buildSnapshot({ ...base, latest: [fix(32.06, 118.7665, NOW, 45)], phase: 'home' }).heading, 45);
  assert.equal(buildSnapshot({ ...base, latest: [fix(32.07, 118.78, NOW)], phase: 'trip' }).status, 'Out');
});
