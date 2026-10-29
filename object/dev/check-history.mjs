// End-to-end history acceptance against the local Demo, with sample-time rule recomputation.
// Run after building server: node object/dev/check-history.mjs [--local] [--server URL]
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { demoApi } from './demo-api.mjs';
import { generateHistory, localDay } from './history.mjs';
import { replayHistory } from './replay-history.mjs';

const require = createRequire(import.meta.url);
const tripRules = require('../server/dist/src/care-agent/trip-recognition.js');
const riskRules = require('../server/dist/src/care-agent/risk-rules.js');
const args = process.argv.slice(2);
const at = args.indexOf('--server');
const server = at >= 0 ? args[at + 1] : 'http://127.0.0.1:3000';
const repo = fileURLToPath(new URL('../../', import.meta.url));
const reset = spawnSync('node', ['object/dev/reset-demo.mjs', '--history', '--server', server, ...(args.includes('--local') ? ['--local'] : [])], { cwd: repo, stdio: 'inherit' });
if (reset.status !== 0) throw new Error('History reset failed');
const now = new Date();
const api = demoApi(server);
let tokens = await api.phones();
const household = await api.get('/v1/household', tokens.caregiver);
const history = generateHistory({ now, timezone: household.elder.timezone });
const zones = await api.get('/v1/safe-zones', tokens.caregiver);
const routes = [JSON.parse(readFileSync(new URL('./demo-route.json', import.meta.url))).points];
let trip = tripRules.initialState(), risk = riskRules.initialRiskState();
const changes = [], outputs = [];
for (const outing of history.trips) for (const point of outing.points) {
  const fix = { t: Date.parse(point.sampledAt), latitude: point.latitude, longitude: point.longitude, accuracy: point.accuracy };
  const t = tripRules.step(trip, fix, zones, tripRules.DEMO_TRIP_PARAMS);
  trip = t.state; changes.push(...t.events);
  const r = riskRules.riskStep(risk, fix, { zones, routes, tripStartedAt: trip.trip?.startedAt ?? null });
  risk = r.state; outputs.push(...r.outputs);
}
const actualTrips = await api.get('/v1/trips?limit=100', tokens.caregiver);
const expectedTrips = changes.filter(e => e.type === 'started');
const expectedEnds = changes.filter(e => e.type === 'ended');
assert.equal(actualTrips.length, expectedTrips.length);
for (const expected of expectedTrips) assert.ok(actualTrips.some(t => Date.parse(t.startedAt) === expected.startedAt));
for (const expected of expectedEnds) assert.ok(actualTrips.some(t => Date.parse(t.endedAt) === expected.endedAt));
const events = await api.get('/v1/risk-events?limit=100', tokens.caregiver);
assert.equal(events.length, outputs.filter(e => e.type === 'opened').length);
assert.equal(events.filter(e => e.level === 'high').length, outputs.filter(e => e.type === 'escalated').length);
assert.ok(events.every(e => e.status === 'resolved'));
for (const event of events) {
  const detail = await api.get(`/v1/risk-events/${event.id}`, tokens.caregiver);
  assert.ok(detail.actions.length > 0);
  assert.ok(detail.actions.every(a => a.status === 'skipped' && a.reason === 'historyReplay'));
  assert.ok(detail.actions.every(a => a.deliveries.length === 0));
  assert.match(detail.explanation, /From the recorded locations/);
  assert.match(detail.explanation, /No notifications were sent and no navigation was started/);
}
console.log(`PASS rule recomputation: ${actualTrips.length} trips, ${events.length} risks, ${events.filter(e => e.level === 'high').length} high; all historical actions skipped, no deliveries`);
const months = [...new Set([history.from.slice(0, 7), history.to.slice(0, 7)])];
for (const month of months) {
  const records = await api.get(`/v1/records?month=${month}`, tokens.caregiver);
  const trend = await api.get(`/v1/trends?month=${month}`, tokens.caregiver);
  assert.equal(records.timezone, history.timezone);
  assert.equal(trend.weeks.length, 8);
  assert.equal(trend.metrics.navigationAssistance.current, 0);
  assert.ok(trend.pattern.length > 20);
  const expectedHigh = outputs.filter(e => e.type === 'escalated' && new Intl.DateTimeFormat('en-CA', { timeZone: history.timezone, year: 'numeric', month: '2-digit' }).format(new Date(e.at)).startsWith(month)).length;
  assert.equal(trend.metrics.highRisk.current, expectedHigh);
  const observations = [...new Map(outputs.filter(o => o.type === 'observation').map(o => [o.key, o])).values()];
  const inMonth = value => localDay(new Date(value), history.timezone).startsWith(month);
  assert.equal(trend.metrics.unusualMovement.current, observations.filter(o => inMonth(o.startedAt)).length);
  assert.equal(trend.deviations.current, observations.filter(o => o.kind === 'deviation' && inMonth(o.startedAt)).length);
  for (const week of trend.weeks) {
    const begin = Date.parse(week.start + 'T12:00:00Z');
    const end = new Date(begin + 7 * 86400000).toISOString().slice(0, 10);
    assert.equal(week.deviations, observations.filter(o => o.kind === 'deviation' && localDay(new Date(o.startedAt), history.timezone) >= week.start && localDay(new Date(o.startedAt), history.timezone) < end).length);
  }
  const expectedDays = expectedTrips.filter(t => inMonth(t.startedAt)).map(t => {
    const opened = outputs.filter(o => o.type === 'opened' && o.tripStartedAt === t.startedAt);
    const high = outputs.some(o => o.type === 'escalated' && opened.some(e => e.key === o.key));
    return { date: localDay(new Date(t.startedAt), history.timezone), risk: high ? 'high' : opened.length ? 'warning' : 'normal' };
  });
  assert.deepEqual(records.days, expectedDays);
  const affected = expectedDays.filter(d => d.risk !== 'normal');
  assert.equal(trend.metrics.safeReturnRate.current, affected.length ? Math.round(100 * affected.filter(d => d.risk === 'warning').length / affected.length) : 0);
  console.log(`PASS ${month}: ${records.days.length} calendar days, ${trend.deviations.current} deviations, ${trend.metrics.highRisk.current} high-risk events, ${trend.metrics.safeReturnRate.current}% safe returns`);
}
for (const sample of [actualTrips[0], actualTrips[Math.floor(actualTrips.length / 2)]]) {
  const detail = await api.get(`/v1/trips/${sample.id}`, tokens.caregiver);
  const points = history.trips.flatMap(t => t.points).filter(p => p.sampledAt >= sample.startedAt && p.sampledAt <= sample.endedAt);
  assert.equal(detail.trail.length, points.length);
  assert.equal(detail.trip.id, sample.id);
  assert.ok(detail.timeline.length >= 2);
}
console.log('PASS complete trip details and timeline');
const again = await replayHistory({ server, now });
assert.equal(again.uploads.accepted ?? 0, 0);
assert.equal(again.uploads.duplicate, again.points);
tokens = await api.phones();
assert.equal((await api.get('/v1/trips?limit=100', tokens.caregiver)).length, actualTrips.length);
assert.equal((await api.get('/v1/risk-events?limit=100', tokens.caregiver)).length, events.length);
console.log('PASS duplicate replay: unchanged trip and risk counts, no actions in replies');
const falseEvent = events.find(e => e.anomaly === 'deviation');
if (falseEvent) {
  const month = localDay(new Date(falseEvent.openedAt ?? falseEvent.anomalyStartedAt), history.timezone).slice(0, 7);
  const before = await api.get(`/v1/trends?month=${month}`, tokens.caregiver);
  await api.call(`/v1/risk-events/${falseEvent.id}/false-alarm`, { method: 'POST', token: tokens.caregiver });
  const after = await api.get(`/v1/trends?month=${month}`, tokens.caregiver);
  assert.equal(after.deviations.current, before.deviations.current - 1);
  const affectedTrip = actualTrips.find(t => t.startedAt <= falseEvent.anomalyStartedAt && t.endedAt >= falseEvent.anomalyStartedAt);
  assert.ok(affectedTrip);
  const detail = await api.get(`/v1/trips/${affectedTrip.id}`, tokens.caregiver);
  assert.equal(detail.trip.risk, 'normal');
  console.log('PASS resolved false alarm excluded from records and trends');
}
console.log('All history checks passed');
