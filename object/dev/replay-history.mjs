// Historical ingestion only: same upload interface, explicit replay=true, never consume live actions.
import { pathToFileURL } from 'node:url';
import { demoApi } from './demo-api.mjs';
import { generateHistory } from './history.mjs';

export async function replayHistory({ server = 'http://127.0.0.1:3000', now = new Date(), batchSize = 120, onTrip = () => {} } = {}) {
  if (!Number.isInteger(batchSize) || batchSize < 1 || batchSize > 200) throw new Error('History batch size must be 1–200');
  const api = demoApi(server);
  const tokens = await api.phones();
  const household = await api.get('/v1/household', tokens.caregiver);
  const history = generateHistory({ now, timezone: household.elder.timezone });
  const tally = {};
  for (const trip of history.trips) {
    for (let index = 0; index < trip.points.length; index += batchSize) {
      const reply = (await api.call('/v1/locations?replay=true', {
        method: 'POST', token: tokens.elder,
        body: { points: trip.points.slice(index, index + batchSize), batteryPercent: 80, locationPermission: 'always', preciseLocation: true },
      })).data;
      if (!Array.isArray(reply.actions) || reply.actions.length) throw new Error('Historical upload returned live actions');
      for (const { status } of reply.results) {
        tally[status] = (tally[status] ?? 0) + 1;
        if (!['accepted', 'duplicate'].includes(status)) throw new Error(`Historical fix rejected: ${status}`);
      }
    }
    onTrip(trip);
  }
  return { timezone: history.timezone, from: history.from, to: history.to, trips: history.trips.length, points: history.trips.reduce((n, t) => n + t.points.length, 0), uploads: tally, actionsInReplies: 0 };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const option = (key, fallback) => args.includes(key) ? args[args.indexOf(key) + 1] : fallback;
  try {
    const result = await replayHistory({ server: option('--server', 'http://127.0.0.1:3000'), now: option('--now', new Date()), onTrip: t => console.log(`${t.day} ${t.kind}: ${t.points.length} fixes`) });
    console.log(JSON.stringify(result, null, 2));
  } catch (error) { console.error('History replay failed:', error.message); process.exitCode = 1; }
}
