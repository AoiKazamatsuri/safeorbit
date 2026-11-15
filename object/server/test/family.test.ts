import 'reflect-metadata';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { test } from 'node:test';
import { BadRequestException, ConflictException, ForbiddenException, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { CareStore } from '../src/care-api/care-store';
import { applySchema } from '../src/care-api/database.service';
import { DeviceAuth } from '../src/care-api/device-auth';
import { FamilyController } from '../src/care-api/family-controller';
import { FamilyStore } from '../src/care-api/family-store';
import { parseCreateFamily, parseJoinFamily, parsePushToken } from '../src/care-api/family-validation';
import { clearHouseholdData } from '../src/care-api/schema';
import { RiskRecords } from '../src/care-api/risk-records';
import { CareEvents } from '../src/care-api/care-events';
import { InputError } from '../src/care-api/validation';

const account = { id: 'account-session', accountId: 'account-id', email: 'fixture@example.invalid' };
const token = () => randomBytes(32).toString('base64url');
const createBody = () => ({ installationId: 'test-family-creator', deviceToken: token(),
  elder: { name: 'Sam', callName: 'Grandpa', phone: '+12025550102', timezone: 'Asia/Shanghai' },
  caregiver: { name: 'Alex', phone: '+12025550101' }, home: { latitude: 31.23, longitude: 121.47, radiusMeters: 100 } });
const caregiver = { id: '166bcb60-e30a-4c4d-b5b3-7796267e9b21', elderId: 7, role: 'caregiver' as const, caregiverId: 8, isDemo: false, accountSessionId: 'account-session' };
const elder = { ...caregiver, id: '266bcb60-e30a-4c4d-b5b3-7796267e9b21', role: 'elder' as const, caregiverId: null };

test('family requests validate canonical credentials, profiles, timezone and WGS-84 home', () => {
  const body = createBody();
  assert.equal(parseCreateFamily(body).home.name, 'Home');
  for (const change of [{ deviceToken: 'a'.repeat(43) }, { deviceToken: 'a'.repeat(42) }, { installationId: 'short' },
    { elder: { ...body.elder, timezone: 'Not/AZone' } }, { caregiver: { name: ' ', phone: '1234' } },
    { home: { ...body.home, latitude: 100 } }, { home: { ...body.home, radiusMeters: 10 } }]) {
    assert.throws(() => parseCreateFamily({ ...body, ...change }), InputError);
  }
  assert.throws(() => parseCreateFamily(null), InputError);
  assert.throws(() => parseCreateFamily([]), InputError);
  assert.throws(() => parseCreateFamily({ ...body, elder: { ...body.elder, name: 'x\u0000y' } }), InputError);
});

test('invites normalize only case and outer whitespace; caregivers must supply contacts', () => {
  const input = { installationId: 'test-family-elder', deviceToken: token(), inviteCode: '  ajkd74m4nzkp ', role: 'elder' };
  assert.equal(parseJoinFamily(input).inviteCode, 'AJKD74M4NZKP');
  assert.equal(parseJoinFamily(input).name, undefined);
  for (const change of [{ role: 'admin' }, { inviteCode: 'AJKD 74M4NZKP' }, { inviteCode: '' }, { role: 'caregiver' }]) {
    assert.throws(() => parseJoinFamily({ ...input, ...change }), InputError);
  }
  assert.equal(parseJoinFamily({ ...input, role: 'caregiver', name: 'Pat', phone: '+12025550103' }).name, 'Pat');
  assert.equal(parsePushToken({ pushToken: 'AB'.repeat(32) }), 'ab'.repeat(32));
  assert.throws(() => parsePushToken({ pushToken: 'not-a-token' }), InputError);
});

test('family controller validates enrollment and enforces credentials and roles before calling store', async () => {
  const auth = new DeviceAuth({ deviceByToken: async (value: string) => value === 'care' ? caregiver : value === 'elder' ? elder : null } as any);
  const seen: unknown[] = [];
  const controller = new FamilyController({
    create: async (body: unknown) => { seen.push(body); return { role: 'caregiver' }; },
    join: async (body: unknown) => { seen.push(body); return { role: 'elder' }; },
    session: async (device: unknown) => { seen.push(device); return { role: 'caregiver' }; },
    members: async (device: unknown) => { seen.push(device); return { inviteCode: 'AJKD74M4NZKP', members: [] }; },
    pushToken: async (...args: unknown[]) => { seen.push(args); },
  } as any, auth, { require: async () => account } as any);
  await assert.rejects(controller.create({}), BadRequestException);
  await assert.rejects(controller.join({}), BadRequestException);
  await assert.rejects(controller.session(), UnauthorizedException);
  await assert.rejects(controller.members('Bearer elder'), ForbiddenException);
  await assert.rejects(controller.delete('Bearer elder'), ForbiddenException);
  await controller.create(createBody());
  await controller.session('Bearer care');
  await controller.members('Bearer care');
  await controller.pushToken({ pushToken: 'ab'.repeat(32) }, 'Bearer elder');
  assert.equal(seen.length, 4);
  assert.deepEqual(seen.at(-1), [elder, 'ab'.repeat(32)]);
});

test('new family enrollment maps database races to a bounded conflict and leaves rollback to transaction', async () => {
  const store = new FamilyStore({ transaction: async () => { throw Object.assign(new Error('detail'), { code: '23505' }); } } as any, {} as any);
  await assert.rejects(store.create(parseCreateFamily(createBody()), account), ConflictException);
});

test('an existing installation cannot acquire a session using a different credential or enrollment operation', async () => {
  const queries: string[] = [];
  const db = { transaction: async (work: any) => work({ query: async (sql: string) => {
    queries.push(sql);
    if (sql.startsWith('SELECT id FROM caregiver_sessions')) return { rows: [{ id: account.id }] };
    return { rows: sql.startsWith('SELECT * FROM devices') ? [{ id: caregiver.id, token_hash: 'other-token', revoked_at: null }] : [] };
  } }) };
  const store = new FamilyStore(db as any, {} as any);
  await assert.rejects(store.create(parseCreateFamily(createBody()), account), ConflictException);
  assert.ok(queries.every(sql => !sql.startsWith('INSERT')), 'conflicts never reach household inserts');
});

test('member removal, leaving and deletion check actual current membership under a family lock', async () => {
  let primary = false;
  let found = true;
  const writes: string[] = [];
  const db = { transaction: async (work: any) => work({ query: async (sql: string, values: unknown[] = []) => {
    if (sql.includes('COALESCE(c.is_primary')) return { rows: [{ ...caregiver, caregiver_id: 8, member_id: caregiver.id, is_primary: primary }] };
    if (sql.startsWith('SELECT id,is_primary FROM caregivers')) return { rows: values[0] === caregiver.id ? [{ id: 8, is_primary: true }] : [] };
    if (sql.startsWith('SELECT id FROM devices')) return { rows: found ? [{ id: elder.id }] : [] };
    writes.push(sql);
    return { rows: [] };
  } }) };
  const store = new FamilyStore(db as any, {} as any);
  await assert.rejects(store.remove(caregiver, elder.id), ForbiddenException);
  await assert.rejects(store.delete(caregiver), ForbiddenException);
  primary = true;
  await assert.rejects(store.leave(caregiver), ConflictException);
  await assert.rejects(store.remove(caregiver, caregiver.id), ForbiddenException);
  await assert.rejects(store.remove(caregiver, 'invalid-id'), NotFoundException);
  found = false;
  await assert.rejects(store.remove(caregiver, elder.id), NotFoundException);
  found = true;
  await store.remove(caregiver, elder.id);
  assert.ok(writes.some(sql => sql.includes('revoked_at = now(), push_token = NULL')));
  primary = false;
  await store.leave(caregiver);
});

test('revoked and demo credentials cannot recover an ordinary family session', async () => {
  const store = new FamilyStore({ query: async () => [] } as any, {} as any);
  await assert.rejects(store.session(caregiver), UnauthorizedException);
  await assert.rejects(store.session({ ...caregiver, isDemo: true }), ForbiddenException);
});

test('demo enrollment and reset default to disabled without any database writes', async t => {
  const old = process.env.SAFEORBIT_DEMO_MODE;
  delete process.env.SAFEORBIT_DEMO_MODE;
  t.after(() => { if (old === undefined) delete process.env.SAFEORBIT_DEMO_MODE; else process.env.SAFEORBIT_DEMO_MODE = old; });
  const store = new CareStore({ query: () => assert.fail('database must remain untouched'), transaction: () => assert.fail('database must remain untouched') } as any);
  await assert.rejects(store.registerDevice({ installationId: 'demo-family-phone', role: 'elder', pushToken: null }), ForbiddenException);
  await assert.rejects(store.reset({} as any, { devices: true }), ForbiddenException);
});

test('schema migration is atomic, rolls back failure and uses a transaction-scoped lock', async () => {
  const statements: string[] = [];
  await assert.rejects(applySchema({ query: async (sql: string) => {
    statements.push(sql);
    if (sql.startsWith('\nCREATE EXTENSION')) throw new Error('migration failed');
  } } as any), /migration failed/);
  assert.deepEqual([statements[0], statements[1], statements.at(-1)], ['BEGIN', 'SELECT pg_advisory_xact_lock(37037)', 'ROLLBACK']);
  assert.ok(!statements.includes('COMMIT'));
});

test('household cleanup is scoped through child rows, never truncates, and clears its append-only exemption', async () => {
  const queries: Array<[string, unknown[]]> = [];
  await clearHouseholdData({ query: async (sql: string, values: unknown[] = []) => { queries.push([sql, values]); } } as any, 7);
  assert.equal(queries[0][1][0], '7');
  assert.ok(queries.slice(1, -1).every(([sql, values]) => sql.startsWith('DELETE') && sql.includes('elder_id = $1') && values[0] === 7));
  assert.ok(queries.at(-1)![0].includes("set_config('safeorbit.delete_elder_id', '', true)"));
  assert.ok(queries.every(([sql]) => !/TRUNCATE|DISABLE TRIGGER/.test(sql)));
});

test('caregiver calls record the actual member and revoked devices are excluded from push recipients', async () => {
  const queries: Array<[string, unknown[]]> = [];
  const db = { query: async (sql: string, values: unknown[] = []) => {
    queries.push([sql, values]);
    if (sql.startsWith('SELECT c.id FROM devices')) return [{ id: 8 }];
    if (sql.startsWith('INSERT INTO call_records')) return [{ id: '11', at: new Date(0) }];
    return [];
  } };
  const risks = new RiskRecords(db as any, new CareEvents());
  await risks.recordCall(7, caregiver.id, null);
  assert.deepEqual(queries.find(([sql]) => sql.startsWith('INSERT INTO call_records'))![1], [7, null, 8, caregiver.id]);
  await risks.pushRecipients(7);
  assert.match(queries.at(-1)![0], /revoked_at IS NULL/);
  assert.match(queries.at(-1)![0], /NOT is_demo OR \$2/);
  assert.match(queries.at(-1)![0], /is_demo OR account_session_id IS NOT NULL/);
});
