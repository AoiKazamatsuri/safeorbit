import { createPrivateKey, KeyObject, sign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import http2 from 'node:http2';
import { PushMessage, PushResult, PushSender } from './push-sender';

// Apple Push Notification service adapter (C2 edge 13): token-based auth with an ES256 JWT signed by the
// .p8 key, HTTP/2 from Node's built-in modules. Configuration comes only from the environment:
//   APNS_KEY_PATH, APNS_KEY_ID, APNS_TEAM_ID   the key file and its ids (all three needed)
//   APNS_TOPIC                                  the App's bundle id, default org.safeorbit.demo
//   APNS_ENVIRONMENT                            development (default, sandbox host) or production
// Unconfigured, it sends nothing and reports configured = false. Key material is never logged.
export const APNS_HOSTS = { development: 'https://api.sandbox.push.apple.com', production: 'https://api.push.apple.com' };
const TOKEN_TTL_MS = 50 * 60_000;     // Apple accepts a token for an hour and refuses refreshes more often than every 20 minutes
const REQUEST_TIMEOUT_MS = 10_000;

export interface ApnsConfig { keyPath: string | null; keyId: string | null; teamId: string | null; topic: string; host: string }

export function apnsConfigFromEnv(env: NodeJS.ProcessEnv = process.env): ApnsConfig {
  const value = (name: string) => (env[name]?.trim() ? env[name]!.trim() : null);
  const environment = value('APNS_ENVIRONMENT') === 'production' ? 'production' : 'development';
  return {
    keyPath: value('APNS_KEY_PATH'), keyId: value('APNS_KEY_ID'), teamId: value('APNS_TEAM_ID'),
    topic: value('APNS_TOPIC') ?? 'org.safeorbit.demo', host: APNS_HOSTS[environment],
  };
}

const b64url = (data: Buffer | string) => Buffer.from(data).toString('base64url');

export function providerToken(key: KeyObject, keyId: string, teamId: string, issuedAtSeconds: number): string {
  const input = `${b64url(JSON.stringify({ alg: 'ES256', kid: keyId }))}.${b64url(JSON.stringify({ iss: teamId, iat: issuedAtSeconds }))}`;
  const signature = sign('sha256', Buffer.from(input), { key, dsaEncoding: 'ieee-p1363' });
  return `${input}.${b64url(signature)}`;
}

export class ApnsSender implements PushSender {
  private key: KeyObject | null | undefined;
  private token: { value: string; at: number } | null = null;
  private session: http2.ClientHttp2Session | null = null;

  constructor(private readonly config: ApnsConfig, private readonly clock: () => number = Date.now) {}

  static fromEnv(): ApnsSender {
    const sender = new ApnsSender(apnsConfigFromEnv());
    console.log(sender.configured ? `APNs configured (${sender.config.host})` : 'APNs not configured: notifications are recorded as notConfigured');
    return sender;
  }

  get configured(): boolean {
    return !!(this.config.keyId && this.config.teamId && this.loadKey());
  }

  private loadKey(): KeyObject | null {
    if (this.key !== undefined) return this.key;
    this.key = null;
    if (!this.config.keyPath) return null;
    try {
      const pem = readFileSync(this.config.keyPath);
      if (pem.length) this.key = createPrivateKey(pem);
    } catch {
      console.error('APNs key at APNS_KEY_PATH could not be read or parsed');
    }
    return this.key;
  }

  private bearer(): string {
    const now = this.clock();
    if (!this.token || now - this.token.at >= TOKEN_TTL_MS) {
      this.token = { value: providerToken(this.loadKey()!, this.config.keyId!, this.config.teamId!, Math.floor(now / 1000)), at: now };
    }
    return this.token.value;
  }

  private connection(): http2.ClientHttp2Session {
    if (this.session && !this.session.closed && !this.session.destroyed) return this.session;
    const session = http2.connect(this.config.host);
    session.on('error', () => { if (this.session === session) this.session = null; });
    session.on('close', () => { if (this.session === session) this.session = null; });
    session.on('goaway', () => { if (this.session === session) this.session = null; });
    session.unref();
    this.session = session;
    return session;
  }

  async send(deviceToken: string, message: PushMessage): Promise<PushResult> {
    if (!this.configured) return { result: 'error', reason: 'notConfigured' };
    const first = await this.post(deviceToken, message);
    if (first.status === 403 && first.reason === 'ExpiredProviderToken') {
      this.token = null;
      return this.post(deviceToken, message);
    }
    return first;
  }

  private post(deviceToken: string, message: PushMessage): Promise<PushResult> {
    return new Promise(resolve => {
      let settled = false;
      const done = (r: PushResult) => { if (!settled) { settled = true; resolve(r); } };
      try {
        const headers: http2.OutgoingHttpHeaders = {
          ':method': 'POST', ':path': `/3/device/${deviceToken}`,
          authorization: `bearer ${this.bearer()}`, 'apns-topic': this.config.topic, 'apns-push-type': 'alert',
          'apns-priority': '10', 'apns-expiration': String(Math.floor(this.clock() / 1000) + 3600),
          'content-type': 'application/json',
        };
        const request = this.connection().request(headers);
        let status = 0;
        let body = '';
        request.setEncoding('utf8');
        request.setTimeout(REQUEST_TIMEOUT_MS, () => { request.close(http2.constants.NGHTTP2_CANCEL); done({ result: 'error', reason: 'timeout' }); });
        request.on('response', h => { status = Number(h[':status']); });
        request.on('data', chunk => { body += chunk; });
        request.on('end', () => {
          if (status === 200) return done({ result: 'accepted', status });
          let reason: string | undefined;
          try { reason = JSON.parse(body).reason; } catch { reason = undefined; }
          done({ result: 'rejected', status, reason });
        });
        request.on('error', error => done({ result: 'error', reason: error.message }));
        request.end(JSON.stringify(message.payload));
      } catch (error) {
        done({ result: 'error', reason: (error as Error).message });
      }
    });
  }

  close(): void {
    this.session?.close();
    this.session = null;
  }
}
