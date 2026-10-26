// Uploads a demo track as the elder phone would, timed to end now, then prints what the caregiver phone sees.
// Run from the repository root after a reset:
//   node object/dev/replay-track.mjs [home-market-home] [--server http://127.0.0.1:3000] [--batch 12] [--stop-after <seconds>]
// --stop-after cuts the track, e.g. to see the caregiver view while she is still at the market.
import { TRACKS } from './tracks.mjs';

const argv = process.argv.slice(2);
const option = (name, fallback) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : fallback; };
const name = argv.find(a => !a.startsWith('--') && !argv[argv.indexOf(a) - 1]?.startsWith('--')) ?? 'home-market-home';
const server = option('--server', 'http://127.0.0.1:3000');
const batchSize = Number(option('--batch', '12'));
const stopAfter = Number(option('--stop-after', 'Infinity'));
if (!TRACKS[name]) throw new Error(`Unknown track ${name}; known: ${Object.keys(TRACKS).join(', ')}`);

async function call(path, { method = 'GET', token, body } = {}) {
  const response = await fetch(server + path, {
    method, body: body && JSON.stringify(body),
    headers: { 'Content-Type': 'application/json', ...(token && { Authorization: `Bearer ${token}` }) },
  });
  const data = response.status === 204 ? null : await response.json();
  if (!response.ok) throw new Error(`${method} ${path} → ${response.status} ${JSON.stringify(data)}`);
  return data;
}

const elder = await call('/v1/devices', { method: 'POST', body: { role: 'elder', installationId: 'replay-elder-phone' } });
const caregiver = await call('/v1/devices', { method: 'POST', body: { role: 'caregiver', installationId: 'replay-caregiver-phone' } });
const track = TRACKS[name]().filter(fix => fix.offset <= stopAfter);
const start = Date.now() - 1000 - track.at(-1).offset * 1000;
const tally = {};
for (let i = 0; i < track.length; i += batchSize) {
  const points = track.slice(i, i + batchSize).map(({ offset, ...fix }) => ({ sampledAt: new Date(start + offset * 1000).toISOString(), ...fix }));
  const reply = await call('/v1/locations', {
    method: 'POST', token: elder.deviceToken,
    body: { points, batteryPercent: 80, locationPermission: 'always', preciseLocation: true },
  });
  for (const { status } of reply.results) tally[status] = (tally[status] ?? 0) + 1;
}
const location = await call('/v1/location', { token: caregiver.deviceToken });
const trips = await call('/v1/trips?limit=3', { token: caregiver.deviceToken });
console.log(JSON.stringify({
  track: name, points: track.length, uploads: tally,
  caregiverSees: { status: location.status, phase: location.phase, tripName: location.tripName, recordedAt: location.recordedAt, trailPoints: location.trail.length, batteryPercent: location.batteryPercent },
  recentTrips: trips.map(t => ({ name: t.name, startedAt: t.startedAt, endedAt: t.endedAt, startKnown: t.startKnown })),
}, null, 2));
