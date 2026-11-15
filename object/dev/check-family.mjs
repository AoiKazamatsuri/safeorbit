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

const owners = new Map();

async function register() {
  const credentials = { email: `${randomUUID()}@example.invalid`, password: randomBytes(24).toString('base64url') };
  const account = await call('/v1/account/register', { method: 'POST', body: credentials });
  assert.equal(account.family, null);
  return { ...account, credentials };
}

async function create(account, body) {
  const session = await call('/v1/family', { method: 'POST', token: account.accountToken, body });
  owners.set(session.memberId, session.deviceToken);
  assert.equal(session.role, 'caregiver');
  assert.equal(session.isPrimary, true);
  return session;
}

async function assertFamilyAccessEnded(token) {
  for (const path of ['/v1/family/session', '/v1/household', '/v1/location', '/v1/records', '/v1/risk-events']) {
    await call(path, { token, expect: 401 });
  }
  await call('/v1/agent/chat', { method: 'POST', token, body: {}, expect: 401 });
}

try {
  const north = family('North', 31.23);
  const south = family('South', 31.20);
  const northAccount = await register();
  const southAccount = await register();
  await call('/v1/family', { method: 'POST', body: north, expect: 401 });
  const initialA = await create(northAccount, north);
  const initialB = await create(southAccount, south);
  const replayed = await call('/v1/family', { method: 'POST', token: northAccount.accountToken, body: north });
  assert.equal(replayed.memberId, initialA.memberId);
  const northLogin = await call('/v1/account/login', { method: 'POST', body: northAccount.credentials });
  await call('/v1/account/session', { method: 'DELETE', token: northAccount.accountToken, expect: 204 });
  await call('/v1/account/session', { method: 'POST', token: northAccount.accountToken, expect: 401 });
  await assertFamilyAccessEnded(replayed.deviceToken);
  assert.equal((await call('/v1/family/session', { token: northLogin.family.deviceToken })).memberId, initialA.memberId);
  const reLogin = await call('/v1/account/login', { method: 'POST', body: northAccount.credentials });
  assert.equal(reLogin.accountId, northAccount.accountId);
  assert.equal(reLogin.family.memberId, initialA.memberId);
  assert.equal(reLogin.family.isPrimary, true);
  const caregiverA = reLogin.family.deviceToken;
  const caregiverB = initialB.deviceToken;
  owners.set(initialA.memberId, caregiverA);
  await assertFamilyAccessEnded(reLogin.accountToken);
  await call('/v1/family/membership', { method: 'DELETE', token: caregiverA, expect: 409 });
  console.log('PASS: logout revokes one login; signing in restores the same household and permissions');

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

  const secondaryAccount = await register();
  const secondary = await call('/v1/family/join', {
    method: 'POST', token: secondaryAccount.accountToken, body: join(membershipA.inviteCode, 'caregiver'),
  });
  const members = await call('/v1/family/members', { token: secondary.deviceToken });
  assert.equal(members.members.length, 3);
  await call('/v1/family', { method: 'DELETE', token: secondary.deviceToken, expect: 403 });
  await call(`/v1/family/members/${secondary.memberId}`, { method: 'DELETE', token: caregiverB, expect: 404 });
  const secondaryLogin = await call('/v1/account/login', { method: 'POST', body: secondaryAccount.credentials });
  await call('/v1/family/membership', { method: 'DELETE', token: secondary.deviceToken, expect: 204 });
  await assertFamilyAccessEnded(secondary.deviceToken);
  await assertFamilyAccessEnded(secondaryLogin.family.deviceToken);
  const unbound = await call('/v1/account/session', { method: 'POST', token: secondaryAccount.accountToken });
  assert.equal(unbound.accountId, secondaryAccount.accountId);
  assert.equal(unbound.family, null);
  assert.equal((await call('/v1/family/members', { token: caregiverA })).members.length, 2);
  assert.equal((await call('/v1/location', { token: caregiverA })).coordinate.latitude, north.home.latitude);

  const newFamily = await call('/v1/family/join', {
    method: 'POST', token: secondaryAccount.accountToken, body: join(membershipB.inviteCode, 'caregiver'),
  });
  assert.equal((await call('/v1/location', { token: newFamily.deviceToken })).coordinate.latitude, south.home.latitude);
  await call(`/v1/safe-zones/${zone.id}`, { method: 'DELETE', token: newFamily.deviceToken, expect: 404 });
  await assertFamilyAccessEnded(secondary.deviceToken);
  await call(`/v1/family/members/${newFamily.memberId}`, { method: 'DELETE', token: caregiverB, expect: 204 });
  await assertFamilyAccessEnded(newFamily.deviceToken);
  assert.equal((await call('/v1/account/session', { method: 'POST', token: secondaryAccount.accountToken })).family, null);
  console.log('PASS: leaving preserves login, blocks prior data, allows joining another family and preserves other members');

  const successor = await call('/v1/family/join', {
    method: 'POST', token: secondaryAccount.accountToken, body: join(membershipA.inviteCode, 'caregiver'),
  });
  await call('/v1/caregiver-settings', { method: 'PUT', token: caregiverA, body: { autoNavigation: false } });
  await call('/v1/family/membership', { method: 'DELETE', token: caregiverA, expect: 204 });
  owners.delete(initialA.memberId);
  owners.set(successor.memberId, successor.deviceToken);
  await assertFamilyAccessEnded(caregiverA);
  await assertFamilyAccessEnded(northLogin.family.deviceToken);
  assert.equal((await call('/v1/account/session', { method: 'POST', token: reLogin.accountToken })).family, null);
  assert.equal((await call('/v1/family/session', { token: successor.deviceToken })).isPrimary, true);
  assert.equal((await call('/v1/caregiver-settings', { token: successor.deviceToken })).autoNavigation, false);
  console.log('PASS: sole caregiver cannot leave; a successor takes over without changing household data or settings');

  await call('/v1/family/membership', { method: 'DELETE', token: elderA.deviceToken, expect: 204 });
  await call('/v1/family/session', { token: elderA.deviceToken, expect: 401 });
  await call('/v1/family/join', { method: 'POST', body: elderRequest, expect: 409 });
} finally {
  for (const token of owners.values()) {
    try { await call('/v1/family', { method: 'DELETE', token, expect: 204 }); }
    catch { console.error('Could not clean a household created by this check'); process.exitCode = 1; }
  }
}
