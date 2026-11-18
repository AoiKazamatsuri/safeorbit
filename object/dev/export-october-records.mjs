// Run against the isolated T58 rehearsal service after replaying the fixed October history.
import assert from 'node:assert/strict';
import { demoApi } from './demo-api.mjs';
import { localDay } from './history.mjs';

const month = '2026-10';
const api = demoApi('http://127.0.0.1:30158');
const { caregiver } = await api.phones();
const records = await api.get(`/v1/records?month=${month}&week=2026-10-19`, caregiver);
const trends = await api.get(`/v1/trends?month=${month}`, caregiver);
const recent = await api.get('/v1/trips?limit=100', caregiver);
const october = recent.filter(trip => localDay(new Date(trip.startedAt), records.timezone).startsWith(month));

assert.equal(records.timezone, 'Asia/Shanghai');
assert.equal(records.days.length, 24);
assert.equal(october.length, 24);

const timestamp = value => value && new Date(value).toISOString().replace(/\.\d{3}Z$/, 'Z');
const point = ({ latitude, longitude }) => ({ latitude, longitude });
const trips = await Promise.all(october.map(async entry => {
  const { trip, trail, anomalies, timeline } = await api.get(`/v1/trips/${entry.id}`, caregiver);
  const { id, name, startedAt, endedAt, startKnown, risk, anomalies: kinds, durationMinutes, deviations, calls, returnedHome } = trip;
  assert.ok(trail.length > 0 && timeline.length > 0);
  return {
    trip: { id, name, startedAt: timestamp(startedAt), endedAt: timestamp(endedAt), startKnown, risk,
      anomalies: kinds, durationMinutes, deviations, calls, returnedHome },
    trail: trail.map(point),
    anomalies: anomalies.map(value => ({ kind: value.kind, at: timestamp(value.at), ...point(value) })),
    timeline: timeline.map(({ id, at, title }) => ({ id, at: timestamp(at), title })),
  };
}));

trips.sort((left, right) => right.trip.startedAt.localeCompare(left.trip.startedAt));
process.stdout.write([
  '{',
  `  "days": ${JSON.stringify(records.days)},`,
  `  "trends": ${JSON.stringify(trends)},`,
  '  "trips": [',
  trips.map(detail => '    ' + JSON.stringify(detail)).join(',\n'),
  '  ]',
  '}',
].join('\n') + '\n');
