import 'reflect-metadata';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { test } from 'node:test';
import { BadRequestException, ConflictException, HttpException, UnauthorizedException } from '@nestjs/common';
import { AccountController } from '../src/care-api/account-controller';
import { AccountStore, parseAccount, passwordHash, passwordMatches } from '../src/care-api/account-store';
import { DeviceAuth } from '../src/care-api/device-auth';
import { FamilyStore } from '../src/care-api/family-store';
import { parseCreateFamily, parseJoinFamily } from '../src/care-api/family-validation';

const password = 'Test only password 1234';
const session = { id: 'login-1', accountId: 'account-1', email: 'fixture@example.invalid' };
const member = { id: 'device-1', elderId: 7, role: 'caregiver' as const, caregiverId: 9, isDemo: false };
const hash = (value: string) => createHash('sha256').update(value).digest('hex');

test('account validation normalizes email, preserves password whitespace and bounds inputs', () => {
  assert.deepEqual(parseAccount({ email: '  Fixture@Example.Invalid ', password }, true), { email: session.email, password });
  assert.equal(parseAccount({ email: session.email, password: ` ${password} ` }, true).password, ` ${password} `);
  for (const input of [null, [], {}, { email: 'invalid', password }, { email: session.email, password: 'short' },
    { email: session.email, password: '字'.repeat(400) }]) assert.throws(() => parseAccount(input, true), BadRequestException);
});

test('passwords use randomized scrypt salt, verify correctly, and unknown accounts run the same derivation', async () => {
  const [a, b] = await Promise.all([passwordHash(password), passwordHash(password)]);
  assert.notEqual(a, b);
  assert.match(a, /^scrypt:[0-9a-f]{32}:[0-9a-f]{128}$/);
  assert.equal(await passwordMatches(password, a), true);
  assert.equal(await passwordMatches('wrong password', a), false);
  assert.equal(await passwordMatches(password), false);
  assert.ok(!a.includes(password));
});

test('login attempts are bounded per email and client and become available after the window', () => {
  const store = new AccountStore({} as any, {} as any, {} as any);
  for (let i = 0; i < 10; i++) store.limit(session.email, '127.0.0.1', 1000);
  assert.throws(() => store.limit(session.email, '127.0.0.2', 1001), (error: unknown) => error instanceof HttpException && error.getStatus() === 429);
  store.limit(session.email, '127.0.0.1', 301001);
});

test('account controller uses legacy credentials only for explicit registration and never accepts malformed bearer', async () => {
  const calls: unknown[] = [];
  const controller = new AccountController({
    limit: () => undefined,
    register: async (...args: unknown[]) => { calls.push(args); return {}; },
    require: async (authorization: string) => { assert.equal(authorization, 'Bearer account-token'); return session; },
    logout: async (value: unknown) => { calls.push(value); },
  } as any);
  await controller.register({ email: session.email, password }, 'Bearer legacy-token');
  assert.deepEqual(calls[0], [{ email: session.email, password }, 'legacy-token']);
  await assert.rejects(controller.register({ email: session.email, password }, 'malformed'), UnauthorizedException);
  await controller.logout('Bearer account-token');
  assert.deepEqual(calls[1], session);
});

test('unknown email and wrong password produce the same login error without a session insert', async () => {
  let row: unknown;
  const store = new AccountStore({ query: async () => row ? [row] : [], transaction: () => assert.fail('must not create a login') } as any, {} as any, {} as any);
  await assert.rejects(store.login({ email: session.email, password }), (error: unknown) => error instanceof UnauthorizedException && error.message === 'Email or password is incorrect');
  row = { password_hash: await passwordHash('a different password'), id: session.accountId };
  await assert.rejects(store.login({ email: session.email, password }), (error: unknown) => error instanceof UnauthorizedException && error.message === 'Email or password is incorrect');
});

test('account bearer resolution checks hash and expiry; logout deletes only the current login', async () => {
  const queries: Array<[string, unknown[]]> = [];
  const store = new AccountStore({ query: async (sql: string, values: unknown[]) => {
    queries.push([sql, values]);
    return [{ id: session.id, account_id: session.accountId, email: session.email }];
  } } as any, {} as any, {} as any);
  await assert.rejects(store.require(), UnauthorizedException);
  assert.deepEqual(await store.require('Bearer account-token'), session);
  assert.equal(queries[0][1][0], hash('account-token'));
  assert.match(queries[0][0], /s.expires_at > now\(\)/);
  await store.logout(session);
  assert.deepEqual(queries[1], ['DELETE FROM caregiver_sessions WHERE id = $1 AND account_id = $2', [session.id, session.accountId]]);
});

test('account restoration with no family preserves login and never creates family access', async () => {
  const queries: string[] = [];
  const store = new AccountStore({ transaction: async (work: any) => work({ query: async (sql: string) => {
    queries.push(sql);
    return { rows: sql.includes('FROM caregiver_sessions') ? [{ id: session.id }] : [] };
  } }) } as any, {} as any, {} as any);
  assert.deepEqual(await store.response(session), { accountId: session.accountId, email: session.email, family: null });
  assert.ok(queries.every(sql => !sql.startsWith('INSERT')));
});

test('account restoration rotates only its own family credential while preserving stable membership and push token', async () => {
  const queries: Array<[string, unknown[]]> = [];
  const store = new AccountStore({ transaction: async (work: any) => work({ query: async (sql: string, values: unknown[] = []) => {
    queries.push([sql, values]);
    if (sql.includes('FROM caregiver_sessions')) return { rows: [{ id: session.id }] };
    if (sql.includes('SELECT id,elder_id FROM caregivers')) return { rows: [{ id: member.caregiverId, elder_id: member.elderId }] };
    if (sql.includes('SELECT id FROM caregivers')) return { rows: [{ id: member.caregiverId }] };
    if (sql.startsWith('SELECT push_token')) return { rows: [{ push_token: 'ab'.repeat(32) }] };
    if (sql.startsWith('INSERT INTO devices')) return { rows: [{ id: member.id }] };
    return { rows: [] };
  } }) } as any, {} as any, { session: async (device: unknown) => {
    assert.deepEqual(device, member);
    return { memberId: 'stable-member', role: 'caregiver' };
  } } as any);
  const response = await store.response(session);
  assert.equal(response.family?.memberId, 'stable-member');
  assert.match(response.family!.deviceToken, /^[a-zA-Z0-9_-]{43}$/);
  const insert = queries.find(([sql]) => sql.startsWith('INSERT INTO devices'))!;
  assert.equal(insert[1][3], hash(response.family!.deviceToken));
  assert.equal(insert[1][4], session.id);
  assert.equal(insert[1][5], 'ab'.repeat(32));
  assert.ok(queries.some(([sql, values]) => sql === 'DELETE FROM devices WHERE account_session_id = $1' && values[0] === session.id));
});

test('caregiver enrollment requires an account but elder enrollment remains invitation based', async () => {
  const family = new FamilyStore({ transaction: async () => { throw new ConflictException('mock elder-seat conflict'); } } as any, {} as any);
  const credentials = { installationId: 'test-installation', deviceToken: Buffer.alloc(32, 1).toString('base64url') };
  const create = parseCreateFamily({ ...credentials, elder: { name: 'Sam', callName: 'Sam', phone: '12345', timezone: 'UTC' },
    caregiver: { name: 'Alex', phone: '12345' }, home: { latitude: 31, longitude: 121, radiusMeters: 100 } });
  await assert.rejects(family.create(create), UnauthorizedException);
  await assert.rejects(family.join(parseJoinFamily({ ...credentials, role: 'caregiver', inviteCode: 'ABCDEFGHIJKL', name: 'Alex', phone: '12345' })), UnauthorizedException);
  await assert.rejects(family.join(parseJoinFamily({ ...credentials, role: 'elder', inviteCode: 'ABCDEFGHIJKL' })), ConflictException);
});

test('primary leave transfers household settings and revokes all own devices without deleting household data', async () => {
  const queries: Array<[string, unknown[]]> = [];
  const store = new FamilyStore({ transaction: async (work: any) => work({ query: async (sql: string, values: unknown[] = []) => {
    queries.push([sql, values]);
    if (sql.includes('COALESCE(c.is_primary')) return { rows: [{ ...member, caregiver_id: 9, is_primary: true }] };
    if (sql.includes('id <> $2')) return { rows: [{ id: 10 }] };
    return { rows: [] };
  } }) } as any, {} as any);
  await store.leave(member);
  assert.ok(queries.some(([sql, values]) => sql === 'UPDATE caregivers SET is_primary = true WHERE id = $1' && values[0] === 10));
  assert.ok(queries.some(([sql, values]) => sql.startsWith('INSERT INTO caregiver_settings') && values[0] === 9 && values[1] === 10));
  assert.ok(queries.some(([sql, values]) => sql.includes('UPDATE devices SET revoked_at') && sql.includes('caregiver_id = $1') && values[0] === 9));
  assert.ok(!queries.some(([sql]) => /DELETE FROM (elders|caregivers|families|caregiver_sessions)/.test(sql)));
});

test('legacy caregiver credentials prove ownership only; ordinary care endpoints require an account-scoped bearer', async () => {
  let device: any = { ...member, accountSessionId: null };
  const auth = new DeviceAuth({ deviceByToken: async () => device } as any);
  await assert.rejects(auth.require('Bearer legacy'), UnauthorizedException);
  assert.deepEqual(await auth.require('Bearer legacy', undefined, true), device);
  device = { ...device, accountSessionId: 'login-1' };
  assert.deepEqual(await auth.require('Bearer scoped'), device);
  device = { ...device, accountSessionId: null, isDemo: true };
  assert.deepEqual(await auth.require('Bearer demo'), device);
  device = { ...device, role: 'elder', isDemo: false };
  assert.deepEqual(await auth.require('Bearer elder'), device);
});
