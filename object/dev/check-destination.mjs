// Run against an isolated, demo-enabled backend seeded with Home only and no location history.
// From the repo root: node object/dev/check-destination.mjs --server http://127.0.0.1:3000
// Add --observe-ms 6000 to leave time for the caregiver simulator to refresh at each checkpoint.
import assert from 'node:assert/strict';
import { setTimeout as wait } from 'node:timers/promises';
import { parseArgs } from 'node:util';
import { demoApi } from './demo-api.mjs';

const { values } = parseArgs({ options: {
  server: { type: 'string' },
  'observe-ms': { type: 'string', default: '0' },
} });
const server = new URL(values.server);
assert(['localhost', '127.0.0.1', '[::1]'].includes(server.hostname) && server.protocol === 'http:',
  'Use an isolated loopback test backend');
const observeMs = Number(values['observe-ms']);
assert(Number.isInteger(observeMs) && observeMs >= 0 && observeMs <= 10_000, 'observe-ms must be 0–10000');

const api = demoApi(server.origin);
const { elder, caregiver } = await api.phones();
const zones = await api.get('/v1/safe-zones', caregiver);
const home = zones[0];
assert(zones.length === 1 && home.isHome && home.radiusMeters === 50, 'Seed only Home with a 50 m radius');
assert.equal((await api.call('/v1/location', { token: caregiver, allow: [404] })).status, 404,
  'Replay requires an empty demo location history');

const longitudeMeters = 111_195 * Math.cos(home.center.latitude * Math.PI / 180);
function point(east, north) {
  return {
    latitude: home.center.latitude + north / 111_195,
    longitude: home.center.longitude + east / longitudeMeters,
  };
}
async function addZone(name, north) {
  const center = point(250, north);
  const { data: zone } = await api.call('/v1/safe-zones', {
    method: 'POST', token: caregiver, body: { name, center, radiusMeters: 50 },
  });
  await api.call(`/v1/safe-zones/${zone.id}/route`, {
    method: 'PUT', token: caregiver, body: { points: [home.center, point(250, 0), center] },
  });
  return zone.id;
}
const market = await addZone('Market', 190);
await addZone('Park', -190);

const now = Date.now();
function trackFix(east, north, seconds) {
  return { ...point(east, north), sampledAt: new Date(now + seconds * 1000).toISOString(), accuracy: 5 };
}
async function upload(points, expected = 'accepted') {
  const { data } = await api.call('/v1/locations', {
    method: 'POST', token: elder, body: { points, batteryPercent: 80, locationPermission: 'always', preciseLocation: true },
  });
  assert.deepEqual(data.results.map(({ status }) => status), points.map(() => expected));
  assert.deepEqual(data.actions, []);
}
async function checkpoint(label, status, destination) {
  const snapshot = await api.get('/v1/location', caregiver);
  assert.equal(snapshot.status, status, label);
  assert.equal(snapshot.possibleDestination?.zoneId, destination, label);
  assert.equal(snapshot.riskLevel, 'normal', label);
  console.log(`PASS ${label}: ${status}${destination ? ' / Possibly heading to Market' : ''}, risk normal`);
  if (observeMs) await wait(observeMs);
  return snapshot;
}

const sharedPath = [
  [0, -175], [30, -160], [60, -145], [85, -130], [110, -115],
  [140, -100], [170, -85], [200, -70], [225, -55], [250, -40],
].map(([east, seconds]) => trackFix(east, 0, seconds));
await upload(sharedPath);
await checkpoint('shared segment', 'Out', undefined);

const marketBranch = Array.from({ length: 10 }, (_, index) => trackFix(250, 12 * (index + 1), -38 + 3 * index));
await upload(marketBranch);
const inferred = await checkpoint('sustained movement beyond the fork', 'Out', market);
assert(Date.parse(inferred.possibleDestination.expiresAt) > Date.now(), 'prediction has a future expiry');

await upload([marketBranch.at(-1)], 'duplicate');
const repeated = await api.get('/v1/location', caregiver);
assert.deepEqual(repeated.possibleDestination, inferred.possibleDestination);
console.log('PASS duplicate sample does not renew the prediction');

await upload([trackFix(250, 174, -1)]);
await checkpoint('arrival', 'At Market', undefined);
assert.deepEqual(await api.get('/v1/risk-events', caregiver), []);
