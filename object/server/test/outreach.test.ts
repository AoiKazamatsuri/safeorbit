import assert from 'node:assert/strict';
import { test } from 'node:test';
import { generateKeyPairSync, verify } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import http2 from 'node:http2';
import { AddressInfo } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ApnsSender, apnsConfigFromEnv, providerToken } from '../src/outreach-gateway/apns-sender';
import { OutreachService } from '../src/outreach-gateway/outreach.service';
import { riskPush } from '../src/outreach-gateway/push-payload';
import { PushMessage, PushSender } from '../src/outreach-gateway/push-sender';

test('notification payloads use localisation keys, never coordinates; only high risk is time-sensitive', () => {
  const low = riskPush('notifyLow', { anomaly: 'wandering', minutes: 7, navigation: true }, '12', 'Grandma');
  assert.deepEqual(low.payload, {
    aps: {
      alert: { 'title-loc-key': 'PUSH_RISK_LOW_TITLE', 'title-loc-args': ['Grandma'], 'loc-key': 'PUSH_RISK_LOW_WANDERING_NAV', 'loc-args': ['7'] },
      sound: 'default', 'interruption-level': 'active', 'thread-id': 'risk-12',
    },
    kind: 'riskLow', riskEventId: '12',
  });
  assert.equal(low.timeSensitive, false);
  const lowOff = riskPush('notifyLow', { anomaly: 'deviation', minutes: 7, navigation: false }, '12', 'Grandma');
  assert.equal((lowOff.payload.aps as any).alert['loc-key'], 'PUSH_RISK_LOW_DEVIATION');
  const high = riskPush('notifyHigh', { anomaly: 'wandering', minutes: 15 }, '12', 'Grandma');
  assert.equal((high.payload.aps as any)['interruption-level'], 'time-sensitive');
  assert.equal((high.payload.aps as any).alert['loc-key'], 'PUSH_RISK_HIGH_WANDERING');
  assert.equal(high.timeSensitive, true);
  const met = riskPush('notifyResolved', { anomaly: 'wandering', resolution: 'met' }, '12', 'Grandma');
  assert.equal((met.payload.aps as any).alert['loc-key'], 'PUSH_RISK_RESOLVED_MET');
  assert.equal((riskPush('notifyResolved', { resolution: 'home' }, '12', 'Grandma').payload.aps as any).alert['loc-key'], 'PUSH_RISK_RESOLVED_HOME');
  for (const m of [low, lowOff, high, met]) assert.ok(!/latitude|longitude|trail/.test(JSON.stringify(m.payload)));
  assert.throws(() => riskPush('startNavigation', {}, '12', 'Grandma'));
});

class FakeSender implements PushSender {
  sent: Array<{ token: string; message: PushMessage }> = [];
  constructor(public configured: boolean, private readonly answer: 'accepted' | 'rejected' = 'accepted') {}
  async send(token: string, message: PushMessage) { this.sent.push({ token, message }); return { result: this.answer, status: this.answer === 'accepted' ? 200 : 400 }; }
  close() {}
}

function fakeRisks(jobs: any[], recipients: any[]) {
  const outcomes: any[] = [];
  return {
    outcomes,
    risks: {
      claimPushJobs: async () => jobs.splice(0),
      pushRecipients: async () => recipients,
      recordPushOutcome: async (_e: number, id: string, status: string, deliveries: any[]) => { outcomes.push({ id, status, deliveries }); },
    },
  };
}
const store = { household: async () => ({ elder: { callName: 'Grandma' } }) };
const events = { onStateChanged: () => undefined };
const JOBS = () => [
  { id: '1', kind: 'notifyLow', riskEventId: '9', details: { anomaly: 'wandering', minutes: 7, navigation: true } },
  { id: '2', kind: 'notifyHigh', riskEventId: '9', details: { anomaly: 'wandering', minutes: 15 } },
];

test('without an APNs key nothing is sent and each notification is recorded as not configured', async () => {
  const sender = new FakeSender(false);
  const { risks, outcomes } = fakeRisks(JOBS(), [{ deviceId: 'd1', pushToken: 'ab' }]);
  await new OutreachService(risks as any, store as any, events as any, sender).deliver(1);
  assert.equal(sender.sent.length, 0);
  assert.deepEqual(outcomes.map(o => [o.id, o.status, o.deliveries[0].result]), [['1', 'notConfigured', 'notConfigured'], ['2', 'notConfigured', 'notConfigured']]);
});

test('configured: every caregiver phone with a push token gets each notification once, results are written back', async () => {
  const sender = new FakeSender(true);
  const { risks, outcomes } = fakeRisks(JOBS(), [{ deviceId: 'd1', pushToken: 'aa' }, { deviceId: 'd2', pushToken: 'bb' }]);
  const service = new OutreachService(risks as any, store as any, events as any, sender);
  await service.deliver(1);
  await service.deliver(1);  // nothing left to claim: no second send
  assert.deepEqual(sender.sent.map(s => [s.token, (s.message.payload as any).kind]), [['aa', 'riskLow'], ['bb', 'riskLow'], ['aa', 'riskHigh'], ['bb', 'riskHigh']]);
  assert.deepEqual(outcomes.map(o => [o.id, o.status, o.deliveries.length]), [['1', 'sent', 2], ['2', 'sent', 2]]);
  const none = fakeRisks(JOBS(), []);
  await new OutreachService(none.risks as any, store as any, events as any, new FakeSender(true)).deliver(1);
  assert.deepEqual(none.outcomes.map(o => o.status), ['noRecipient', 'noRecipient']);
  const rejected = fakeRisks(JOBS().slice(0, 1), [{ deviceId: 'd1', pushToken: 'aa' }]);
  await new OutreachService(rejected.risks as any, store as any, events as any, new FakeSender(true, 'rejected')).deliver(1);
  assert.deepEqual(rejected.outcomes.map(o => [o.status, o.deliveries[0].detail]), [['failed', '400']]);
});

test('APNs config comes from the environment with the sandbox host and the demo topic by default', () => {
  const config = apnsConfigFromEnv({ APNS_KEY_PATH: '/k.p8', APNS_KEY_ID: 'KEY', APNS_TEAM_ID: 'TEAM' });
  assert.deepEqual(config, { keyPath: '/k.p8', keyId: 'KEY', teamId: 'TEAM', topic: 'org.safeorbit.demo', host: 'https://api.sandbox.push.apple.com' });
  assert.equal(apnsConfigFromEnv({ APNS_ENVIRONMENT: 'production', APNS_TOPIC: 'x.y' }).host, 'https://api.push.apple.com');
  assert.equal(new ApnsSender(apnsConfigFromEnv({})).configured, false);
  assert.equal(new ApnsSender({ ...config, keyPath: '/dev/null' }).configured, false);  // an empty mount means unconfigured
});

test('APNs adapter signs an ES256 provider token, posts over HTTP/2 and reports Apple\'s answer', async () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const token = providerToken(privateKey, 'KEYID12345', 'TEAMID1234', 1_800_000_000);
  const [h, c, sig] = token.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(h, 'base64url').toString()), { alg: 'ES256', kid: 'KEYID12345' });
  assert.deepEqual(JSON.parse(Buffer.from(c, 'base64url').toString()), { iss: 'TEAMID1234', iat: 1_800_000_000 });
  assert.ok(verify('sha256', Buffer.from(`${h}.${c}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(sig, 'base64url')));

  const dir = mkdtempSync(join(tmpdir(), 'apns-test-'));
  const keyPath = join(dir, 'AuthKey_TEST.p8');
  writeFileSync(keyPath, privateKey.export({ type: 'pkcs8', format: 'pem' }));
  const seen: Array<{ headers: http2.IncomingHttpHeaders; body: string }> = [];
  const server = http2.createServer();  // plain-text HTTP/2 stands in for Apple; nothing leaves this machine
  server.on('stream', (stream, headers) => {
    let body = '';
    stream.on('data', d => { body += d; });
    stream.on('end', () => {
      seen.push({ headers, body });
      const bad = String(headers[':path']).endsWith('/bad');
      stream.respond({ ':status': bad ? 400 : 200, 'content-type': 'application/json' });
      stream.end(bad ? JSON.stringify({ reason: 'BadDeviceToken' }) : '');
    });
  });
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  let now = 1_800_000_000_000;
  const sender = new ApnsSender({ keyPath, keyId: 'KEYID12345', teamId: 'TEAMID1234', topic: 'org.safeorbit.demo',
    host: `http://127.0.0.1:${(server.address() as AddressInfo).port}` }, () => now);
  try {
    assert.equal(sender.configured, true);
    const message = riskPush('notifyHigh', { anomaly: 'wandering', minutes: 15 }, '3', 'Grandma');
    assert.deepEqual(await sender.send('abcd', message), { result: 'accepted', status: 200 });
    assert.deepEqual(await sender.send('bad', message), { result: 'rejected', status: 400, reason: 'BadDeviceToken' });
    now += 51 * 60_000;  // the cached token is refreshed after 50 minutes
    await sender.send('abcd', message);
    const [first, second, third] = seen;
    assert.equal(first.headers[':path'], '/3/device/abcd');
    assert.equal(first.headers['apns-topic'], 'org.safeorbit.demo');
    assert.equal(first.headers['apns-push-type'], 'alert');
    assert.equal(first.headers['apns-priority'], '10');
    assert.match(String(first.headers.authorization), /^bearer [\w-]+\.[\w-]+\.[\w-]+$/);
    assert.equal(second.headers.authorization, first.headers.authorization);
    assert.notEqual(third.headers.authorization, first.headers.authorization);
    assert.deepEqual(JSON.parse(first.body), message.payload);
  } finally {
    sender.close();
    await new Promise(resolve => server.close(resolve));
    rmSync(dir, { recursive: true, force: true });
  }
});
