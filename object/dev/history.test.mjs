import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { generateHistory, historyTrack, localDay, localInstant } from './history.mjs';
import { replayHistory } from './replay-history.mjs';

const require = createRequire(import.meta.url);
const tripRules = require('../server/dist/src/care-agent/trip-recognition.js');
const riskRules = require('../server/dist/src/care-agent/risk-rules.js');
const seed = JSON.parse(readFileSync(new URL('./demo-household.json', import.meta.url)));
const zones = seed.safeZones.map((z, index) => ({ ...z, id: String(index), isHome: z.name === 'Home' }));
const routes = [JSON.parse(readFileSync(new URL('./demo-route.json', import.meta.url))).points];

export function recompute(history) {
  let trip = tripRules.initialState(), risk = riskRules.initialRiskState();
  const changes = [], outputs = [];
  for (const outing of history.trips) for (const point of outing.points) {
    const fix = { t: Date.parse(point.sampledAt), latitude: point.latitude, longitude: point.longitude, accuracy: point.accuracy };
    const t = tripRules.step(trip, fix, zones, tripRules.DEMO_TRIP_PARAMS);
    trip = t.state; changes.push(...t.events);
    const r = riskRules.riskStep(risk, fix, { zones, routes, tripStartedAt: trip.trip?.startedAt ?? null });
    risk = r.state; outputs.push(...r.outputs);
  }
  return { changes, outputs, trip, risk };
}

test('one month is deterministic, ordered, ends yesterday and mostly normal', () => {
  const options = { now: '2026-10-28T01:00:00Z', timezone: 'Asia/Shanghai' };
  const history = generateHistory(options);
  assert.deepEqual(history, generateHistory(options));
  assert.equal(history.from, '2026-09-28'); assert.equal(history.to, '2026-10-27');
  assert.equal(history.trips.length, 26);
  assert.ok(history.trips.filter(t => t.kind === 'normal').length > history.trips.length * 0.7);
  let previous = 0;
  for (const trip of history.trips) for (const point of trip.points) {
    assert.ok(Date.parse(point.sampledAt) > previous); previous = Date.parse(point.sampledAt);
    assert.equal(localDay(previous, history.timezone), trip.day);
    assert.ok(point.accuracy <= 10);
  }
  assert.ok(previous < Date.parse(options.now));
});

test('calendar month clamp and local clock across year, leap day and DST', () => {
  assert.equal(generateHistory({ now: '2026-03-31T02:00:00Z' }).from, '2026-02-28');
  assert.equal(generateHistory({ now: '2024-03-31T02:00:00Z' }).from, '2024-02-29');
  assert.equal(generateHistory({ now: '2026-01-01T02:00:00Z' }).from, '2025-12-01');
  assert.equal(new Date(localInstant('2026-03-08', 9, 0, 'America/New_York')).toISOString(), '2026-03-08T13:00:00.000Z');
  assert.equal(new Date(localInstant('2026-11-01', 9, 0, 'America/New_York')).toISOString(), '2026-11-01T14:00:00.000Z');
  assert.throws(() => generateHistory({ now: 'invalid' }), /Invalid/);
  assert.throws(() => historyTrack('unknown'), /Unknown/);
});

test('same sample-time rules derive completed normal, low-risk deviation and high-risk wandering trips', () => {
  for (const kind of ['normal', 'deviation', 'wandering']) {
    const points = historyTrack(kind).map(({ offset, ...p }) => ({ ...p, sampledAt: new Date(Date.UTC(2026, 9, 20, 1) + offset * 1000).toISOString() }));
    const result = recompute({ trips: [{ points }] });
    assert.equal(result.changes.filter(e => e.type === 'started').length, 1);
    assert.equal(result.changes.filter(e => e.type === 'ended').length, 1);
    const risk = result.outputs.filter(o => o.type !== 'observation');
    assert.deepEqual(risk.map(r => r.type), kind === 'normal' ? [] : kind === 'deviation' ? ['opened', 'resolved'] : ['opened', 'escalated', 'resolved']);
    if (risk.length) assert.equal(risk[0].anomaly, kind === 'deviation' ? 'deviation' : 'wandering');
  }
  const history = generateHistory({ now: '2026-10-28T01:00:00Z' });
  const result = recompute(history);
  assert.equal(result.changes.filter(e => e.type === 'started').length, history.trips.length);
  assert.equal(result.changes.filter(e => e.type === 'ended').length, history.trips.length);
  assert.equal(result.outputs.filter(e => e.type === 'opened').length, 5);
  assert.equal(result.outputs.filter(e => e.type === 'escalated').length, 2);
  assert.equal(result.outputs.filter(e => e.type === 'resolved').length, 5);
});

test('history importer rejects invalid batching before network access', async () => {
  await assert.rejects(replayHistory({ batchSize: 0 }), /1–200/);
  await assert.rejects(replayHistory({ batchSize: 201 }), /1–200/);
});
