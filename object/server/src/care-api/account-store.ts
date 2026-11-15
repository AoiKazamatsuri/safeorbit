import { BadRequestException, ConflictException, HttpException, Injectable, UnauthorizedException } from '@nestjs/common';
import { createHash, randomBytes, scrypt, timingSafeEqual } from 'node:crypto';
import { PoolClient } from 'pg';
import { CareStore } from './care-store';
import { DatabaseService } from './database.service';
import { FamilyStore } from './family-store';

export interface AccountSession { id: string; accountId: string; email: string }
const hash = (token: string) => createHash('sha256').update(token).digest('hex');
const derive = (password: string, salt: string): Promise<Buffer> => new Promise((resolve, reject) => {
  scrypt(password, salt, 64, { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 }, (error, key) => error ? reject(error) : resolve(key));
});
export async function passwordHash(password: string): Promise<string> {
  const salt = randomBytes(16).toString('hex');
  return `scrypt:${salt}:${(await derive(password, salt)).toString('hex')}`;
}
export async function passwordMatches(password: string, stored?: string): Promise<boolean> {
  const [, salt = '0'.repeat(32), digest = '0'.repeat(128)] = (stored ?? '').split(':');
  const actual = await derive(password, salt);
  const expected = Buffer.from(digest, 'hex');
  return expected.length === actual.length && timingSafeEqual(expected, actual) && stored !== undefined;
}
export function parseAccount(body: unknown, registering = false): { email: string; password: string } {
  const input = body as Record<string, unknown>;
  if (!input || typeof input !== 'object' || Array.isArray(input) || typeof input.email !== 'string'
    || typeof input.password !== 'string') throw new BadRequestException('Enter an email and password');
  const email = input.email.trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    || input.password.length < (registering ? 12 : 1) || Buffer.byteLength(input.password) > 1024) {
    throw new BadRequestException('Invalid email or password length');
  }
  return { email, password: input.password };
}

@Injectable()
export class AccountStore {
  private readonly attempts = new Map<string, { count: number; until: number }>();
  constructor(private readonly db: DatabaseService, private readonly care: CareStore, private readonly family: FamilyStore) {}

  limit(email: string, address: string, now = Date.now()): void {
    for (const [key, entry] of this.attempts) if (entry.until <= now) this.attempts.delete(key);
    const keys = [`email:${hash(email)}`, `address:${address}`];
    if (this.attempts.size + keys.filter(key => !this.attempts.has(key)).length > 10000) {
      throw new HttpException('Too many attempts; try again later', 429);
    }
    for (const [index, key] of keys.entries()) {
      const entry = this.attempts.get(key) ?? { count: 0, until: now + 5 * 60_000 };
      if (++entry.count > (index === 0 ? 10 : 60)) throw new HttpException('Too many attempts; try again later', 429);
      this.attempts.set(key, entry);
    }
  }

  async register(input: { email: string; password: string }, legacyToken?: string) {
    const encoded = await passwordHash(input.password);
    const accountToken = randomBytes(32).toString('base64url');
    let account: AccountSession;
    try {
      account = await this.db.transaction(async client => {
        const { rows: [created] } = await client.query('INSERT INTO caregiver_accounts (email,password_hash) VALUES ($1,$2) RETURNING id,email',
          [input.email, encoded]);
        if (legacyToken) {
          const { rows: [legacy] } = await client.query(`SELECT d.id,d.caregiver_id,d.elder_id FROM devices d JOIN caregivers c ON c.id = d.caregiver_id
            WHERE d.token_hash = $1 AND NOT d.is_demo AND d.role = 'caregiver' AND d.revoked_at IS NULL
              AND d.account_session_id IS NULL AND c.account_id IS NULL AND c.departed_at IS NULL FOR UPDATE OF c,d`, [hash(legacyToken)]);
          if (!legacy) throw new UnauthorizedException('This previous family session cannot be claimed');
          await client.query('UPDATE caregivers SET account_id = $2 WHERE id = $1', [legacy.caregiver_id, created.id]);
          await client.query('UPDATE devices SET revoked_at = now(),push_token = NULL WHERE caregiver_id = $1', [legacy.caregiver_id]);
        }
        return this.newSession(client, created.id, created.email, accountToken);
      });
    } catch (error) {
      if ((error as { code?: string }).code === '23505') throw new ConflictException('This email is already registered');
      if (['23503', '40001', '40P01'].includes((error as { code?: string }).code ?? '')) throw new ConflictException('The previous family session changed; try again');
      throw error;
    }
    return { accountToken, ...await this.response(account) };
  }

  async login(input: { email: string; password: string }) {
    const [account] = await this.db.query('SELECT id,email,password_hash FROM caregiver_accounts WHERE email = $1', [input.email]);
    if (!await passwordMatches(input.password, account?.password_hash)) throw new UnauthorizedException('Email or password is incorrect');
    const accountToken = randomBytes(32).toString('base64url');
    const session = await this.db.transaction(client => this.newSession(client, account.id, account.email, accountToken));
    return { accountToken, ...await this.response(session) };
  }

  private async newSession(client: PoolClient, accountId: string, email: string, token: string): Promise<AccountSession> {
    const { rows: [row] } = await client.query('INSERT INTO caregiver_sessions (account_id,token_hash) VALUES ($1,$2) RETURNING id', [accountId, hash(token)]);
    return { id: row.id, accountId, email };
  }

  async require(authorization?: string): Promise<AccountSession> {
    const token = /^Bearer (\S+)$/.exec(authorization ?? '')?.[1];
    if (!token) throw new UnauthorizedException('Log in to your account');
    const [row] = await this.db.query(`SELECT s.id,s.account_id,a.email FROM caregiver_sessions s
      JOIN caregiver_accounts a ON a.id = s.account_id WHERE s.token_hash = $1 AND s.expires_at > now()`, [hash(token)]);
    if (!row) throw new UnauthorizedException('This login session has expired');
    return { id: row.id, accountId: row.account_id, email: row.email };
  }

  async response(account: AccountSession) {
    const deviceToken = randomBytes(32).toString('base64url');
    const device = await this.db.transaction(async client => {
      // Account locks serialize enrollment and restoration; the family lock then serializes leave/delete.
      await client.query('SELECT id FROM caregiver_accounts WHERE id = $1 FOR UPDATE', [account.accountId]);
      const { rows: [session] } = await client.query('SELECT id FROM caregiver_sessions WHERE id = $1 AND account_id = $2 AND expires_at > now() FOR UPDATE', [account.id, account.accountId]);
      if (!session) throw new UnauthorizedException('This login session has expired');
      const { rows: [member] } = await client.query('SELECT id,elder_id FROM caregivers WHERE account_id = $1 AND departed_at IS NULL', [account.accountId]);
      if (!member) return null;
      await client.query('SELECT elder_id FROM families WHERE elder_id = $1 FOR UPDATE', [member.elder_id]);
      const { rows: [active] } = await client.query('SELECT id FROM caregivers WHERE id = $1 AND departed_at IS NULL', [member.id]);
      if (!active) return null;
      // Only one family credential per login; rotating it never reconnects an old family's token.
      const { rows: [previous] } = await client.query('SELECT push_token FROM devices WHERE account_session_id = $1 AND revoked_at IS NULL', [account.id]);
      await client.query('DELETE FROM devices WHERE account_session_id = $1', [account.id]);
      const { rows: [row] } = await client.query(`INSERT INTO devices (installation_id,role,elder_id,caregiver_id,token_hash,account_session_id,push_token)
        VALUES ($1,'caregiver',$2,$3,$4,$5,$6) RETURNING id`, [`account-${account.id}`, member.elder_id, member.id, hash(deviceToken), account.id, previous?.push_token ?? null]);
      return { id: row.id, role: 'caregiver' as const, elderId: member.elder_id, caregiverId: member.id, isDemo: false };
    });
    return { accountId: account.accountId, email: account.email,
      family: device ? { deviceToken, ...await this.family.session(device) } : null };
  }

  async logout(account: AccountSession): Promise<void> {
    // ON DELETE CASCADE revokes only the family credentials belonging to this login.
    await this.db.query('DELETE FROM caregiver_sessions WHERE id = $1 AND account_id = $2', [account.id, account.accountId]);
  }
}
