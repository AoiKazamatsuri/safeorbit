import 'reflect-metadata';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { CareStore, SafeZone, StoredFix } from '../src/care-api/care-store';
import { DeviceAuth } from '../src/care-api/device-auth';
import { Records } from '../src/care-api/records';
import { RecordsController } from '../src/care-api/records-controller';
import { buildRecords, buildTrends, buildTripDetail, localDate, parseMonth, parseWeek, RecordsData } from '../src/care-api/records-view';
import { InputError } from '../src/care-api/validation';

const date = (s: string) => new Date(s);
const NOW = date('2026-10-28T02:00:00Z');
const empty = (): RecordsData => ({ timezone: 'Asia/Shanghai', trips: [], risks: [], observations: [], actions: [], calls: [] });
const fixture = (): RecordsData => ({ ...empty(),
  trips: [
    { id: '1', startedAt: date('2026-09-30T15:40:00Z'), endedAt: date('2026-09-30T16:40:00Z'), startKnown: true, stops: ['Home', 'Market', 'Home'] },
    { id: '2', startedAt: date('2026-10-01T01:00:00Z'), endedAt: date('2026-10-01T02:00:00Z'), startKnown: true, stops: ['Home', 'Home'] },
    { id: '3', startedAt: date('2026-10-02T01:00:00Z'), endedAt: date('2026-10-02T02:00:00Z'), startKnown: true, stops: ['Home', 'Home'] },
  ],
  risks: [
    { id: 'r1', tripId: '1', openedAt: date('2026-09-30T15:55:00Z'), escalatedAt: date('2026-09-30T16:03:00Z'), resolvedAt: date('2026-09-30T16:43:00Z'), falseAlarm: false },
    { id: 'r2', tripId: '2', openedAt: date('2026-10-01T01:20:00Z'), escalatedAt: null, resolvedAt: date('2026-10-01T02:03:00Z'), falseAlarm: false },
    { id: 'r3', tripId: '3', openedAt: date('2026-10-02T01:20:00Z'), escalatedAt: date('2026-10-02T01:28:00Z'), resolvedAt: date('2026-10-02T02:03:00Z'), falseAlarm: true },
  ],
  observations: [
    { key: 'o1', kind: 'deviation', startedAt: date('2026-09-30T15:48:00Z'), riskEventId: 'r1' },
    { key: 'o1', kind: 'deviation', startedAt: date('2026-09-30T15:48:00Z'), riskEventId: 'r1' },
    { key: 'o2', kind: 'wandering', startedAt: date('2026-10-01T01:13:00Z'), riskEventId: 'r2' },
    { key: 'o3', kind: 'deviation', startedAt: date('2026-10-02T01:13:00Z'), riskEventId: 'r3' },
    { key: 'o4', kind: 'deviation', startedAt: date('2026-10-01T01:40:00Z'), riskEventId: null },
  ],
  actions: [
    { id: 'a1', riskEventId: 'r1', kind: 'startNavigation', status: 'started', reason: null, decidedAt: date('2026-09-30T15:59:00Z'), resultAt: date('2026-09-30T16:00:01Z') },
    { id: 'a2', riskEventId: 'r2', kind: 'startNavigation', status: 'skipped', reason: 'historyReplay', decidedAt: date('2026-10-01T01:20:00Z'), resultAt: null },
    { id: 'a3', riskEventId: 'r2', kind: 'startNavigation', status: 'failed', reason: 'routePlanningFailed', decidedAt: date('2026-10-01T01:20:00Z'), resultAt: date('2026-10-01T01:21:00Z') },
    { id: 'a4', riskEventId: 'r3', kind: 'startNavigation', status: 'started', reason: null, decidedAt: date('2026-10-02T01:20:00Z'), resultAt: date('2026-10-02T01:21:00Z') },
  ],
  calls: [{ id: 'c1', riskEventId: 'r1', at: date('2026-09-30T16:04:00Z') }, { id: 'c2', riskEventId: null, at: date('2026-10-01T01:15:00Z') }],
});

test('calendar uses local days and actual escalation time across midnight; resolved stays and false alarms disappear', () => {
  const data = fixture();
  const september = buildRecords(data, '2026-09', '2026-09-28', NOW);
  assert.deepEqual(september.days, [{ date: '2026-09-30', risk: 'warning' }]);
  assert.deepEqual(buildRecords(data, '2026-10', '2026-09-28', NOW).days, [
    { date: '2026-10-01', risk: 'high' }, { date: '2026-10-02', risk: 'normal' },
  ]);
  assert.equal(september.trips.length, 3);
  const high = september.trips.find(t => t.id === '1')!;
  assert.deepEqual([high.risk, high.deviations, high.calls, high.durationMinutes, high.returnedHome], ['high', 1, 1, 60, true]);
  assert.deepEqual(september.trips.find(t => t.id === '3')!.anomalies, []);
  data.trips[0].startedAt = date('2026-09-27T15:55:00Z');
  assert.equal(buildRecords(data, '2026-09', '2026-09-28', NOW).trips.filter(t => t.id === '1').length, 1);
});

test('trends count unique behaviours, actual started navigation and escalation dates; safe return is grouped by trip start', () => {
  const trends = buildTrends(fixture(), '2026-10', NOW);
  assert.deepEqual(trends.deviations, { current: 1, previous: 1 });
  assert.deepEqual(trends.metrics, {
    unusualMovement: { current: 2, previous: 1 }, navigationAssistance: { current: 1, previous: 0 },
    highRisk: { current: 1, previous: 0 }, safeReturnRate: { current: 100, previous: 0 },
  });
  assert.equal(trends.weeks.length, 8);
  assert.equal(trends.weeks[0].start, '2026-09-07');
  assert.equal(trends.weeks[7].start, '2026-10-26');
  assert.equal(trends.weeks.find(w => w.start === '2026-09-28')!.deviations, 2);
  assert.match(trends.pattern, /2 recorded trips.*2 started in the morning/);
  assert.equal(buildTrends(fixture(), '2026-09', NOW).weeks[7].start, '2026-09-28');
  assert.equal(buildTrends(fixture(), '2027-01', NOW).previousMonth, '2026-12');
});

test('no records produces empty calendar, eight zero weeks and zero denominators, never samples', () => {
  assert.deepEqual(buildRecords(empty(), '2026-10', '2026-10-26', NOW).days, []);
  const trend = buildTrends(empty(), '2026-10', NOW);
  assert.ok(trend.weeks.every(w => w.deviations === 0));
  assert.deepEqual(trend.metrics.safeReturnRate, { current: 0, previous: 0 });
});

test('safe return uses risky trips only, counts each trip once and includes ongoing trips in the denominator', () => {
  const data = fixture();
  data.trips.push(
    { id: '4', startedAt: date('2026-10-03T01:00:00Z'), endedAt: null, startKnown: true, stops: ['Home'] },
    { id: '5', startedAt: date('2026-10-04T01:00:00Z'), endedAt: date('2026-10-04T02:00:00Z'), startKnown: true, stops: ['Home', 'Home'] },
    { id: '6', startedAt: date('2026-10-05T01:00:00Z'), endedAt: date('2026-10-05T02:00:00Z'), startKnown: true, stops: ['Home', 'Home'] },
  );
  const base = data.risks[1];
  data.risks.push(
    { ...base, id: 'r4', tripId: '4', openedAt: date('2026-10-03T01:20:00Z'), resolvedAt: null },
    { ...base, id: 'r5', tripId: '5', openedAt: date('2026-10-04T01:20:00Z'), escalatedAt: date('2026-10-04T01:30:00Z') },
    { ...base, id: 'r6', tripId: '2', openedAt: date('2026-10-01T01:30:00Z') },
  );
  assert.equal(buildTrends(data, '2026-10', NOW).metrics.safeReturnRate.current, 33);
  // Trip 2 is safe once despite two events; 4 is ongoing; 5 reached high; 3 is false alarm; 6 had no risk.
});

test('timezones respect DST, calendar dates validate strictly and weeks begin Monday across the year', () => {
  assert.equal(localDate(date('2026-11-01T05:30:00Z'), 'America/New_York'), '2026-11-01');
  assert.equal(localDate(date('2026-11-01T06:30:00Z'), 'America/New_York'), '2026-11-01');
  assert.equal(localDate(date('2026-10-01T00:30:00Z'), 'America/Los_Angeles'), '2026-09-30');
  assert.equal(parseWeek('2027-01-01', ''), '2026-12-28');
  assert.equal(parseWeek('2024-02-29', ''), '2024-02-26');
  for (const value of ['2026-02-29', '2026-04-31', '2026-13-01', 'bad', ['2026-10-01']]) assert.throws(() => parseWeek(value, ''), InputError);
  for (const value of ['2026-1', '2026-13', '', ['2026-10']]) assert.throws(() => parseMonth(value, ''), InputError);
});

test('detail retains a complete trail, maps anomalies to their time and tells the truth about calls and skipped help', () => {
  const data = fixture(), trip = data.trips[1];
  const zone: SafeZone = { id: 'market', name: 'Market', isHome: false, center: { latitude: 32, longitude: 118 }, radiusMeters: 50 };
  const trail: StoredFix[] = Array.from({ length: 6000 }, (_, i) => ({ sampledAt: new Date(trip.startedAt.getTime() + i * 500),
    latitude: 32, longitude: 118, accuracy: 5, speed: null, course: null }));
  const detail = buildTripDetail(data, trip, trail, [zone], NOW);
  assert.equal(detail.trail.length, 6000);
  assert.equal(detail.anomalies.length, 2);
  assert.equal(detail.trip.calls, 1);
  assert.ok(detail.timeline.some(t => t.title === 'Arrived at Market'));
  assert.ok(detail.timeline.some(t => /Navigation home: not started/.test(t.title)));
  assert.ok(detail.timeline.some(t => /Call initiated; connection unknown/.test(t.title)));
  assert.equal(detail.timeline[0].at, trip.startedAt.toISOString());
  assert.ok(detail.timeline.some(t => t.title === 'Returned home'));
});

let unavailable = false;
const fakeStore = {
  deviceByToken: async (token: string) => token === 'family' || token === 'elder' ? { id: token, elderId: 1, role: token === 'family' ? 'caregiver' : 'elder' } : null,
  safeZones: async () => [],
};
const sql: string[] = [];
const fakeDb = {
  transaction: async (work: (client: any) => Promise<unknown>) => {
    if (unavailable) throw new Error('database is down');
    return work({ query: async (query: string, values: unknown[]) => {
      sql.push(query);
      if (query.startsWith('SET ')) return { rows: [] };
      assert.equal(values[0], 1);
      return { rows: query.includes('FROM elders') ? [{ timezone: 'Asia/Shanghai' }] : [] };
    } });
  },
};
const records = new Records(fakeDb as any, fakeStore as any);
@Module({ controllers: [RecordsController], providers: [
  { provide: Records, useValue: records }, { provide: DeviceAuth, useValue: new DeviceAuth(fakeStore as any) },
] })
class RecordsTestModule {}

test('HTTP records enforce caregiver auth, validate queries, return zero data/404 and surface database unavailability as 503', async () => {
  const app = await NestFactory.create(RecordsTestModule, { logger: false });
  await app.listen(0, '127.0.0.1');
  const base = await app.getUrl();
  const get = (path: string, token?: string) => fetch(base + path, { headers: token ? { authorization: `Bearer ${token}` } : {} });
  try {
    for (const path of ['/v1/records', '/v1/trends', '/v1/trips/1']) {
      assert.equal((await get(path)).status, 401);
      assert.equal((await get(path, 'elder')).status, 403);
    }
    assert.equal((await get('/v1/records?month=2026-13', 'family')).status, 400);
    assert.equal((await get('/v1/records?week=2026-02-30', 'family')).status, 400);
    assert.equal((await get('/v1/trends?month=bad', 'family')).status, 400);
    const calendar = await get('/v1/records?month=2026-10&week=2026-10-28', 'family');
    assert.equal(calendar.status, 200);
    assert.deepEqual(await calendar.json(), { timezone: 'Asia/Shanghai', month: '2026-10', weekStart: '2026-10-26', days: [], trips: [] });
    assert.equal((await get('/v1/trends?month=2026-10', 'family')).status, 200);
    assert.equal((await get('/v1/trips/1', 'family')).status, 404);
    assert.equal((await get('/v1/trips/bad', 'family')).status, 404);
    unavailable = true;
    for (const path of ['/v1/records', '/v1/trends', '/v1/trips/1']) assert.equal((await get(path, 'family')).status, 503);
    assert.ok(sql.includes('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'));
  } finally { unavailable = false; await app.close(); }
});
