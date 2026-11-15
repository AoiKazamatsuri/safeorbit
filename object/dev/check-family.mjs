// Run against a local T50 backend with a disposable database. The check never uses an existing household.
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';

const server = new URL(process.argv[2] ?? 'http://127.0.0.1:3000');
if (!['http:', 'https:'].includes(server.protocol) || !['localhost', '127.0.0.1', '[::1]'].includes(server.hostname)
    || server.username || server.password || server.pathname !== '/' || server.search || server.hash) {
  throw new Error('Usage: node object/dev/check-family.mjs [local-server-origin]');
}

async function call(path, { method = 'GET', token, body, expect = 200 } = {}) {
  const response = await fetch(new URL(path, server), {
    method,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
    redirect: 'error',
    signal: AbortSignal.timeout(15_000),
  });
  // Report resource type, never the supplied token or a response that may contain it.
  const expected = Array.isArray(expect) ? expect : [expect];
  assert.ok(expected.includes(response.status),
    `${method} ${path.split('/').slice(0, 4).join('/')} returned ${response.status}, expected ${expected.join(' or ')}`);
  return response.status === 200 ? response.json() : undefined;
}

function enrollment() {
  return { installationId: randomUUID(), deviceToken: randomBytes(32).toString('base64url') };
}

function family(name, latitude) {
  return {
    ...enrollment(),
    caregiver: { name: `Caregiver ${name}`, phone: '+12025550101' },
    elder: { name: `Senior ${name}`, callName: name, phone: '+12025550102', timezone: 'Asia/Shanghai' },
    home: { latitude, longitude: 121.47, radiusMeters: 100 },
  };
}

function join(inviteCode, role = 'elder') {
  return {
    ...enrollment(), inviteCode, role,
    ...(role === 'caregiver' ? { name: 'Second caregiver', phone: '+12025550103' } : {}),
  };
}

async function upload(token, home) {
  const point = { sampledAt: new Date().toISOString(), latitude: home.latitude, longitude: home.longitude, accuracy: 5 };
  const response = await call('/v1/locations', { method: 'POST', token, body: { points: [point] } });
  assert.deepEqual(response.results.map(point => point.status), ['accepted']);
}

const created = [];

async function create(body) {
  const session = await call('/v1/family', { method: 'POST', body });
  created.push(session.deviceToken);
  assert.ok(session.deviceToken === body.deviceToken, 'creation uses the retained device credential');
  assert.equal(session.role, 'caregiver');
  assert.equal(session.isPrimary, true);
  return session.deviceToken;
}

async function deleteFamily(token) {
  await call('/v1/family', { method: 'DELETE', token, expect: 204 });
  created.splice(created.indexOf(token), 1);
}

try {
  const north = family('North', 31.23);
  const south = family('South', 31.20);
  const caregiverA = await create(north);
  const caregiverB = await create(south);
  const replayed = await call('/v1/family', { method: 'POST', body: north });
  assert.ok(replayed.deviceToken === caregiverA, 'retry returns the same family session');
  await call('/v1/family', {
    method: 'POST', body: { ...north, deviceToken: enrollment().deviceToken }, expect: 409,
  });
  const membershipA = await call('/v1/family/members', { token: caregiverA });
  const membershipB = await call('/v1/family/members', { token: caregiverB });
  assert.ok(membershipA.inviteCode !== membershipB.inviteCode, 'each household has its own invitation');
  const elderRequest = join(membershipA.inviteCode.toLowerCase());
  const elderA = await call('/v1/family/join', { method: 'POST', body: elderRequest });
  const competing = await Promise.all([join(membershipB.inviteCode), join(membershipB.inviteCode)].map(
    body => call('/v1/family/join', { method: 'POST', body, expect: [200, 409] })));
  const accepted = competing.filter(Boolean);
  assert.equal(accepted.length, 1, 'only one concurrent elder enrollment succeeds');
  const [elderB] = accepted;
  const replayedJoin = await call('/v1/family/join', { method: 'POST', body: elderRequest });
  assert.ok(replayedJoin.memberId === elderA.memberId, 'retry retains the same elder membership');
  await call('/v1/family/join', { method: 'POST', body: join(membershipA.inviteCode), expect: 409 });
  await call('/v1/family/join', { method: 'POST', body: join('ZZZZZZZZZZZZ'), expect: 404 });
  await call('/v1/location', { expect: 401 });
  await call('/v1/family/members', { token: elderA.deviceToken, expect: 403 });
  await call('/v1/locations?replay=true', { method: 'POST', token: elderA.deviceToken, body: {}, expect: 403 });
  assert.equal((await call('/v1/family/session', { token: elderA.deviceToken })).role, 'elder');
  console.log('PASS: invitations, enrollment retries, role checks and one elder per household');

  await upload(elderA.deviceToken, north.home);
  await upload(elderB.deviceToken, south.home);
  const [locationA, locationB] = await Promise.all([
    call('/v1/location', { token: caregiverA }),
    call('/v1/location', { token: caregiverB }),
  ]);
  assert.equal(locationA.coordinate.latitude, north.home.latitude);
  assert.equal(locationB.coordinate.latitude, south.home.latitude);
  assert.equal(locationA.riskLevel, 'normal');
  assert.equal(locationB.riskLevel, 'normal');
  const zone = locationA.safeZones.find(zone => zone.isHome);
  assert.ok(zone);
  await call(`/v1/safe-zones/${zone.id}`, { method: 'DELETE', token: caregiverB, expect: 404 });
  for (const token of [caregiverA, caregiverB]) {
    await call('/v1/records', { token });
    assert.deepEqual(await call('/v1/risk-events', { token }), []);
  }
  console.log('PASS: location, records and risk queries for two households and cross-household resource rejection');

  const secondary = await call('/v1/family/join', { method: 'POST', body: join(membershipA.inviteCode, 'caregiver') });
  const members = await call('/v1/family/members', { token: secondary.deviceToken });
  assert.equal(members.members.length, 3);
  await call('/v1/family', { method: 'DELETE', token: secondary.deviceToken, expect: 403 });
  await call(`/v1/family/members/${secondary.memberId}`, { method: 'DELETE', token: caregiverB, expect: 404 });
  await call(`/v1/family/members/${secondary.memberId}`, { method: 'DELETE', token: caregiverA, expect: 204 });
  await call('/v1/records', { token: secondary.deviceToken, expect: 401 });
  await call('/v1/family/membership', { method: 'DELETE', token: elderA.deviceToken, expect: 204 });
  await call('/v1/family/session', { token: elderA.deviceToken, expect: 401 });
  await call('/v1/family/join', { method: 'POST', body: elderRequest, expect: 409 });
  await deleteFamily(caregiverA);
  await call('/v1/family/session', { token: caregiverA, expect: 401 });
  await call('/v1/family/join', { method: 'POST', body: join(membershipA.inviteCode), expect: 404 });
  assert.equal((await call('/v1/location', { token: caregiverB })).coordinate.latitude, south.home.latitude);
  await deleteFamily(caregiverB);
  await call('/v1/family/session', { token: elderB.deviceToken, expect: 401 });
  console.log('PASS: member removal, leaving, household deletion and immediate credential revocation');
} finally {
  for (const token of [...created]) {
    try { await deleteFamily(token); }
    catch { console.error('Could not clean a household created by this check'); process.exitCode = 1; }
  }
}
