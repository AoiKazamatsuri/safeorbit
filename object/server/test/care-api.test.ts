import assert from 'node:assert/strict';
import { test } from 'node:test';
import { SafeZone, StoredFix } from '../src/care-api/care-store';
import { agentStatusLine, buildSnapshot, riskHeadline } from '../src/care-api/location-view';
import { parseSeed } from '../src/care-api/reset-cli';
import { ActionRecord, RiskActivity, RiskEventRecord } from '../src/care-api/risk-records';
import { buildRiskDetail } from '../src/care-api/risk-view';
import {
  InputError, isHomeName, parseActionResult, parseCallRecord, parseDeviceRegistration, parseLocationBatch, parseReferenceRoute,
  parseSafeZone, parseSettings,
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

test('the snapshot adds risk level, headline, agent status and the current risk event, keeping the old fields', () => {
  const base = { latest: [fix(32.058, 118.768, NOW)], phase: 'trip', tripStops: ['Home'], trail: [], zones: [HOME, MARKET], batteryPercent: 60 };
  const normal = buildSnapshot({ ...base, risk: null, riskFreeTrips: 2, now: new Date(NOW) });
  assert.deepEqual([normal.riskLevel, normal.riskHeadline, normal.riskEventId, normal.riskEventStatus, normal.agentStatus],
    ['normal', null, null, null, 'Learning daily routes (2/5 trips)']);
  assert.equal(normal.status, 'Out');
  const since = new Date(NOW - 7 * 60_000 - 20_000);
  const warning = buildSnapshot({ ...base, now: new Date(NOW), riskFreeTrips: 5,
    risk: { id: '4', status: 'active', level: 'warning', anomaly: 'wandering', anomalyStartedAt: since, resolvedAt: null } });
  assert.deepEqual([warning.riskLevel, warning.riskHeadline, warning.riskAnomaly, warning.riskSince, warning.riskEventId, warning.agentStatus],
    ['warning', 'Wandering for 7 minutes', 'wandering', since.toISOString(), '4', 'Monitoring']);
  const resolved = buildSnapshot({ ...base, now: new Date(NOW),
    risk: { id: '4', status: 'resolved', level: 'high', anomaly: 'deviation', anomalyStartedAt: since, resolvedAt: new Date(NOW) } });
  assert.deepEqual([resolved.riskLevel, resolved.riskHeadline, resolved.riskEventId, resolved.riskEventStatus], ['normal', null, '4', 'resolved']);
  assert.equal(riskHeadline('deviation', new Date(NOW - 61_000), new Date(NOW)), 'Off route for 1 minute');
  assert.equal(agentStatusLine(0), 'Learning daily routes (0/5 trips)');
});

test('new request bodies are validated: route, settings, action result and call', () => {
  assert.deepEqual(parseReferenceRoute({ points: [{ latitude: 32.06, longitude: 118.76 }, { latitude: 32.05, longitude: 118.77 }] }).length, 2);
  for (const bad of [{}, { points: [] }, { points: [{ latitude: 32, longitude: 118 }] }, { points: [{ latitude: 32, longitude: 118 }, { latitude: 99, longitude: 0 }] }]) {
    assert.throws(() => parseReferenceRoute(bad), InputError);
  }
  assert.deepEqual(parseSettings({ autoNavigation: false }), { autoNavigation: false });
  assert.throws(() => parseSettings({}), InputError);
  assert.throws(() => parseSettings({ highRiskAlerts: false }), InputError);
  assert.throws(() => parseSettings({ lowRiskNotifications: 'no' }), InputError);
  assert.deepEqual(parseActionResult({ result: 'failed', reason: ' routePlanningFailed ' }), { result: 'failed', reason: 'routePlanningFailed' });
  assert.deepEqual(parseActionResult({ result: 'started' }), { result: 'started', reason: null });
  assert.throws(() => parseActionResult({ result: 'done' }), InputError);
  assert.deepEqual(parseCallRecord(undefined), { riskEventId: null });
  assert.deepEqual(parseCallRecord({ riskEventId: '12' }), { riskEventId: '12' });
  assert.throws(() => parseCallRecord({ riskEventId: 12 }), InputError);
});

test('the reset seed can carry a reference route for a preset zone', () => {
  const zones = [{ name: 'Home', center: { latitude: 32.06, longitude: 118.77 }, radiusMeters: 100 },
    { name: 'Market', center: { latitude: 32.05, longitude: 118.77 }, radiusMeters: 100 }];
  const people = { elder: { name: 'Li Lan', callName: 'Grandma', phone: '1', timezone: 'Asia/Shanghai' }, caregiver: { name: 'W', phone: '2' } };
  const route = [{ latitude: 32.06, longitude: 118.77 }, { latitude: 32.05, longitude: 118.77 }];
  assert.deepEqual(parseSeed({ ...people, safeZones: zones, referenceRoutes: { Market: route } }).referenceRoutes, { Market: route });
  assert.deepEqual(parseSeed({ ...people, safeZones: zones }).referenceRoutes, {});
  assert.throws(() => parseSeed({ ...people, safeZones: zones, referenceRoutes: { Park: route } }), InputError);
});

test('the risk event page lists help, a time-ordered timeline and the raw records', () => {
  const at = (min: number) => new Date(NOW + min * 60_000);
  const event: RiskEventRecord = {
    id: '7', key: 'wandering:1', tripId: '3', level: 'high', status: 'resolved', anomaly: 'wandering', anomalyStartedAt: at(0),
    openedAt: at(7), escalatedAt: at(15), resolvedAt: at(20), resolution: 'met', falseAlarm: false, explanation: 'text', version: 4, changedAt: at(20),
  };
  const action = (id: string, kind: ActionRecord['kind'], status: string, decided: number, extra: Partial<ActionRecord> = {}): ActionRecord => ({
    id, riskEventId: '7', kind, target: kind === 'startNavigation' ? 'elder' : 'caregivers', status, reason: null, details: {},
    decidedAt: at(decided), createdAt: at(decided), expiresAt: null, deliveredAt: null, resultAt: null,
    deliveries: [{ channel: 'apns', deviceId: null, result: 'notConfigured', detail: null, at: at(decided) }], ...extra,
  });
  const activity: RiskActivity = {
    transitions: [
      { seq: 1, kind: 'opened', fromLevel: null, toLevel: 'warning', at: at(7), detail: { minutes: 7 } },
      { seq: 2, kind: 'escalated', fromLevel: 'warning', toLevel: 'high', at: at(15), detail: { minutes: 15 } },
      { seq: 3, kind: 'resolved', fromLevel: 'high', toLevel: null, at: at(20), detail: { resolution: 'met' } },
    ],
    actions: [
      action('1', 'startNavigation', 'failed', 7, { reason: 'routePlanningFailed', resultAt: at(7.5) }),
      action('2', 'notifyLow', 'notConfigured', 7), action('3', 'notifyHigh', 'notConfigured', 15), action('4', 'notifyResolved', 'notConfigured', 20),
    ],
    dispositions: [{ kind: 'met', at: at(20) }], calls: [{ at: at(16) }], observations: [],
  };
  const detail = buildRiskDetail({ event, activity, latest: fix(32.06, 118.7665, NOW + 20 * 60_000), trail: [] });
  assert.equal(detail.headline, 'Wandering for 20 minutes');
  assert.equal(detail.canMarkFalseAlarm, true);
  assert.deepEqual(detail.timeline.map(i => i.kind), [
    'anomalyStarted', 'lowRisk', 'navigationSent', 'familyNotified', 'navigationFailed', 'highRisk', 'familyNotified', 'familyCalled',
    'familyNotified', 'resolved',
  ]);
  assert.equal(detail.timeline[1].text, 'Low risk: wandering for 7 minutes');
  assert.deepEqual(detail.help.map(h => [h.kind, h.status]), [
    ['navigation', 'failed'], ['lowRiskNotification', 'notConfigured'], ['highRiskAlert', 'notConfigured'], ['resolvedNotification', 'notConfigured'],
  ]);
  assert.equal(detail.help[0].text, 'Navigation home could not start (routePlanningFailed)');
  assert.equal(detail.help[1].text, 'Low-risk notification not sent: push is not configured');
  assert.equal(detail.actions[1].deliveries[0].result, 'notConfigured');
});
