import { ConflictException, ForbiddenException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';
import { PoolClient } from 'pg';
import { CareStore, Device } from './care-store';
import { DatabaseService } from './database.service';
import { CreateFamily, FamilyCredentials, JoinFamily } from './family-validation';
import { clearHouseholdData } from './schema';
import type { AccountSession } from './account-store';

const hash = (value: string) => createHash('sha256').update(value).digest('hex');
const fingerprint = (kind: string, input: CreateFamily | JoinFamily) => hash(JSON.stringify({ kind, ...input }));
const UUID = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;

@Injectable()
export class FamilyStore {
  constructor(private readonly db: DatabaseService, private readonly care: CareStore) {}

  async create(input: CreateFamily, account?: AccountSession) {
    const device = await this.enroll(input, 'create', async client => {
      const { rows: [elder] } = await client.query(
        'INSERT INTO elders (name, call_name, phone, timezone) VALUES ($1,$2,$3,$4) RETURNING id',
        [input.elder.name, input.elder.callName, input.elder.phone, input.elder.timezone]);
      await client.query('INSERT INTO families (elder_id, invite_code) VALUES ($1,$2)',
        [elder.id, Array.from(randomBytes(12), n => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[n & 31]).join('')]);
      const { rows: [caregiver] } = await client.query(
        'INSERT INTO caregivers (elder_id, name, phone, is_primary,account_id) VALUES ($1,$2,$3,true,$4) RETURNING id',
        [elder.id, input.caregiver.name, input.caregiver.phone, account?.accountId]);
      await client.query('INSERT INTO safe_zones (elder_id,name,is_home,latitude,longitude,radius_m) VALUES ($1,\'Home\',true,$2,$3,$4)',
        [elder.id, input.home.center.latitude, input.home.center.longitude, input.home.radiusMeters]);
      return this.insertDevice(client, input, 'caregiver', elder.id, caregiver.id, fingerprint('create', input), account);
    }, account);
    return { deviceToken: input.deviceToken, ...await this.session(device) };
  }

  async join(input: JoinFamily, account?: AccountSession) {
    const device = await this.enroll(input, 'join', async client => {
      const { rows: [family] } = await client.query(
        'SELECT elder_id FROM families WHERE invite_code = $1 AND NOT is_demo FOR UPDATE', [input.inviteCode]);
      if (!family) throw new NotFoundException('Invitation not found');
      let caregiverId: number | null = null;
      if (input.role === 'caregiver') {
        const { rows: [caregiver] } = await client.query(
          'INSERT INTO caregivers (elder_id,name,phone,is_primary,account_id) VALUES ($1,$2,$3,false,$4) RETURNING id',
          [family.elder_id, input.name, input.phone, account?.accountId]);
        caregiverId = caregiver.id;
      }
      return this.insertDevice(client, input, input.role, family.elder_id, caregiverId, fingerprint('join', input), account);
    }, account);
    return { deviceToken: input.deviceToken, ...await this.session(device) };
  }

  private async enroll(input: CreateFamily | JoinFamily, kind: string, work: (client: PoolClient) => Promise<Device>, account?: AccountSession): Promise<Device> {
    const isCaregiver = kind === 'create' || (input as JoinFamily).role === 'caregiver';
    if (isCaregiver && !account) throw new UnauthorizedException('Log in before joining a family');
    try {
      return await this.db.transaction(async client => {
        if (account && isCaregiver) {
          await client.query('SELECT id FROM caregiver_accounts WHERE id = $1 FOR UPDATE', [account.accountId]);
          const { rows: [session] } = await client.query('SELECT id FROM caregiver_sessions WHERE id = $1 AND account_id = $2 AND expires_at > now() FOR UPDATE', [account.id, account.accountId]);
          if (!session) throw new UnauthorizedException('This login session has expired');
        }
        // Serialize retries for one installation before taking a household lock. The unique indexes
        // remain the final arbiter across different installations and concurrent elder joins.
        await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 50))', [input.installationId]);
        const { rows: [old] } = await client.query('SELECT * FROM devices WHERE installation_id = $1 FOR UPDATE', [input.installationId]);
        if (old && !old.revoked_at) {
          if (old.is_demo || (isCaregiver && old.account_session_id !== account?.id) || old.token_hash !== hash(input.deviceToken) || old.enrollment_hash !== fingerprint(kind, input)) {
            throw new ConflictException('This installation has already joined a family');
          }
          return { id: old.id, role: old.role, elderId: old.elder_id, caregiverId: old.caregiver_id, isDemo: false };
        }
        if (old) {
          if (old.token_hash === hash(input.deviceToken)) throw new ConflictException('Use a new credential to join again');
          await client.query('DELETE FROM devices WHERE id = $1', [old.id]);
        }
        if (account && isCaregiver) {
          const { rows } = await client.query('SELECT id FROM caregivers WHERE account_id = $1 AND departed_at IS NULL', [account.accountId]);
          if (rows.length) throw new ConflictException('Leave your current family before joining another');
        }
        return work(client);
      });
    } catch (error) {
      if (['23505', '23503', '40001', '40P01'].includes((error as { code?: string }).code ?? '')) {
        throw new ConflictException('The family or installation changed; check your membership and try again');
      }
      throw error;
    }
  }

  private async insertDevice(client: PoolClient, input: FamilyCredentials, role: string, elderId: number, caregiverId: number | null, enrollmentHash: string, account?: AccountSession): Promise<Device> {
    const { rows: [row] } = await client.query(
      `INSERT INTO devices (installation_id, role, elder_id, caregiver_id, token_hash, enrollment_hash,account_session_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id,role`,
      [input.installationId, role, elderId, caregiverId, hash(input.deviceToken), enrollmentHash, account?.id ?? null]);
    return { id: row.id, role: row.role, elderId, caregiverId, isDemo: false };
  }

  private async member(device: Device, client?: PoolClient) {
    if (device.isDemo) throw new ForbiddenException('Demo phones do not have family memberships');
    const sql = `SELECT d.*, c.member_id,c.name AS member_name,c.phone AS member_phone, COALESCE(c.is_primary,false) AS is_primary FROM devices d
      JOIN families f ON f.elder_id = d.elder_id LEFT JOIN caregivers c ON c.id = d.caregiver_id
      WHERE d.id = $1 AND d.elder_id = $2 AND d.revoked_at IS NULL AND NOT f.is_demo
        AND (c.id IS NULL OR c.departed_at IS NULL)
        AND (d.account_session_id IS NULL OR EXISTS (SELECT 1 FROM caregiver_sessions s WHERE s.id = d.account_session_id AND s.expires_at > now()))`;
    const rows = client ? (await client.query(sql, [device.id, device.elderId])).rows : await this.db.query(sql, [device.id, device.elderId]);
    if (!rows[0]) throw new UnauthorizedException('Membership is no longer active');
    return rows[0];
  }

  async session(device: Device) {
    const member = await this.member(device);
    return { role: member.role, memberId: member.member_id ?? member.id, member: member.role === 'caregiver' ? { name: member.member_name, phone: member.member_phone } : undefined, isPrimary: member.is_primary, household: await this.care.household(device.elderId) };
  }

  async members(device: Device) {
    await this.member(device);
    if (device.role !== 'caregiver') throw new ForbiddenException('Only caregivers can view invitations');
    const [family] = await this.db.query('SELECT invite_code FROM families WHERE elder_id = $1 AND NOT is_demo', [device.elderId]);
    if (!family) throw new UnauthorizedException('Membership is no longer active');
    const members = await this.db.query(`SELECT member_id AS id,'caregiver' AS role,name,is_primary FROM caregivers
      WHERE elder_id = $1 AND departed_at IS NULL
      UNION ALL SELECT d.id,d.role,e.name,false AS is_primary FROM devices d JOIN elders e ON e.id = d.elder_id
      WHERE d.elder_id = $1 AND d.role = 'elder' AND d.revoked_at IS NULL ORDER BY role,id`, [device.elderId]);
    return { inviteCode: family.invite_code, members: members.map(m => ({ id: m.id, name: m.name, role: m.role, isPrimary: m.is_primary })) };
  }

  private async locked<T>(device: Device, work: (client: PoolClient, member: any) => Promise<T>): Promise<T> {
    try {
      return await this.db.transaction(async client => {
        await client.query('SELECT elder_id FROM families WHERE elder_id = $1 FOR UPDATE', [device.elderId]);
        return work(client, await this.member(device, client));
      });
    } catch (error) {
      if (['23503', '40001', '40P01'].includes((error as { code?: string }).code ?? '')) {
        throw new ConflictException('The family changed while processing this request; try again');
      }
      throw error;
    }
  }

  async leave(device: Device): Promise<void> {
    await this.locked(device, async (client, member) => {
      if (member.role === 'caregiver') {
        if (member.is_primary) {
          const { rows: [successor] } = await client.query(`SELECT id FROM caregivers
            WHERE elder_id = $1 AND id <> $2 AND departed_at IS NULL ORDER BY id LIMIT 1 FOR UPDATE`, [device.elderId, member.caregiver_id]);
          if (!successor) throw new ConflictException('Invite another caregiver before leaving the family');
          await client.query('UPDATE caregivers SET is_primary = false WHERE id = $1', [member.caregiver_id]);
          await client.query('UPDATE caregivers SET is_primary = true WHERE id = $1', [successor.id]);
          await client.query(`INSERT INTO caregiver_settings (caregiver_id,auto_navigation,low_risk_notifications,recovery_notifications,limited_monitoring_notifications)
            SELECT $2,auto_navigation,low_risk_notifications,recovery_notifications,limited_monitoring_notifications FROM caregiver_settings WHERE caregiver_id = $1
            ON CONFLICT (caregiver_id) DO UPDATE SET auto_navigation = EXCLUDED.auto_navigation,low_risk_notifications = EXCLUDED.low_risk_notifications,
              recovery_notifications = EXCLUDED.recovery_notifications,limited_monitoring_notifications = EXCLUDED.limited_monitoring_notifications,updated_at = now()`,
          [member.caregiver_id, successor.id]);
        }
        await this.revokeCaregiver(client, member.caregiver_id);
      } else await this.revoke(client, member.id);
    });
  }

  async remove(device: Device, id: string): Promise<void> {
    await this.locked(device, async (client, member) => {
      if (!member.is_primary) throw new ForbiddenException('Only the primary caregiver can remove members');
      if (!UUID.test(id)) throw new NotFoundException('Member not found');
      const { rows: [caregiver] } = await client.query('SELECT id,is_primary FROM caregivers WHERE member_id = $1 AND elder_id = $2 AND departed_at IS NULL', [id, device.elderId]);
      if (caregiver) {
        if (caregiver.is_primary) throw new ForbiddenException('Use Leave Family to transfer your responsibility');
        await this.revokeCaregiver(client, caregiver.id);
        return;
      }
      const { rows: [target] } = await client.query("SELECT id FROM devices WHERE id = $1 AND elder_id = $2 AND role = 'elder' AND revoked_at IS NULL", [id, device.elderId]);
      if (!target) throw new NotFoundException('Member not found');
      await this.revoke(client, id);
    });
  }

  private async revokeCaregiver(client: PoolClient, caregiverId: number): Promise<void> {
    await client.query('UPDATE caregivers SET departed_at = now(),is_primary = false WHERE id = $1', [caregiverId]);
    await client.query('UPDATE devices SET revoked_at = now(),push_token = NULL WHERE caregiver_id = $1', [caregiverId]);
  }

  private async revoke(client: PoolClient, id: string): Promise<void> {
    await client.query('UPDATE devices SET revoked_at = now(), push_token = NULL WHERE id = $1', [id]);
  }

  async delete(device: Device): Promise<void> {
    await this.locked(device, async (client, member) => {
      if (!member.is_primary) throw new ForbiddenException('Only the primary caregiver can delete the family');
      await clearHouseholdData(client, device.elderId);
      await client.query('DELETE FROM devices WHERE elder_id = $1', [device.elderId]);
      await client.query('DELETE FROM caregivers WHERE elder_id = $1', [device.elderId]);
      await client.query('DELETE FROM families WHERE elder_id = $1', [device.elderId]);
      await client.query('DELETE FROM elders WHERE id = $1', [device.elderId]);
    });
  }

  async pushToken(device: Device, token: string): Promise<void> {
    await this.locked(device, async client => {
      await client.query('UPDATE devices SET push_token = $2 WHERE id = $1', [device.id, token]);
    });
  }
}
