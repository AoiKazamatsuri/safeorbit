import { ConflictException, ForbiddenException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';
import { PoolClient } from 'pg';
import { CareStore, Device } from './care-store';
import { DatabaseService } from './database.service';
import { CreateFamily, FamilyCredentials, JoinFamily } from './family-validation';
import { clearHouseholdData } from './schema';

const hash = (value: string) => createHash('sha256').update(value).digest('hex');
const fingerprint = (kind: string, input: CreateFamily | JoinFamily) => hash(JSON.stringify({ kind, ...input }));
const UUID = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;

@Injectable()
export class FamilyStore {
  constructor(private readonly db: DatabaseService, private readonly care: CareStore) {}

  async create(input: CreateFamily) {
    const device = await this.enroll(input, 'create', async client => {
      const { rows: [elder] } = await client.query(
        'INSERT INTO elders (name, call_name, phone, timezone) VALUES ($1,$2,$3,$4) RETURNING id',
        [input.elder.name, input.elder.callName, input.elder.phone, input.elder.timezone]);
      await client.query('INSERT INTO families (elder_id, invite_code) VALUES ($1,$2)',
        [elder.id, Array.from(randomBytes(12), n => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[n & 31]).join('')]);
      const { rows: [caregiver] } = await client.query(
        'INSERT INTO caregivers (elder_id, name, phone, is_primary) VALUES ($1,$2,$3,true) RETURNING id',
        [elder.id, input.caregiver.name, input.caregiver.phone]);
      await client.query('INSERT INTO safe_zones (elder_id,name,is_home,latitude,longitude,radius_m) VALUES ($1,\'Home\',true,$2,$3,$4)',
        [elder.id, input.home.center.latitude, input.home.center.longitude, input.home.radiusMeters]);
      return this.insertDevice(client, input, 'caregiver', elder.id, caregiver.id, fingerprint('create', input));
    });
    return { deviceToken: input.deviceToken, ...await this.session(device) };
  }

  async join(input: JoinFamily) {
    const device = await this.enroll(input, 'join', async client => {
      const { rows: [family] } = await client.query(
        'SELECT elder_id FROM families WHERE invite_code = $1 AND NOT is_demo FOR UPDATE', [input.inviteCode]);
      if (!family) throw new NotFoundException('Invitation not found');
      let caregiverId: number | null = null;
      if (input.role === 'caregiver') {
        const { rows: [caregiver] } = await client.query(
          'INSERT INTO caregivers (elder_id,name,phone,is_primary) VALUES ($1,$2,$3,false) RETURNING id',
          [family.elder_id, input.name, input.phone]);
        caregiverId = caregiver.id;
      }
      return this.insertDevice(client, input, input.role, family.elder_id, caregiverId, fingerprint('join', input));
    });
    return { deviceToken: input.deviceToken, ...await this.session(device) };
  }

  private async enroll(input: CreateFamily | JoinFamily, kind: string, work: (client: PoolClient) => Promise<Device>): Promise<Device> {
    try {
      return await this.db.transaction(async client => {
        // Serialize retries for one installation before taking a household lock. The unique indexes
        // remain the final arbiter across different installations and concurrent elder joins.
        await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 50))', [input.installationId]);
        const { rows: [old] } = await client.query('SELECT * FROM devices WHERE installation_id = $1 FOR UPDATE', [input.installationId]);
        if (old && !old.revoked_at) {
          if (old.is_demo || old.token_hash !== hash(input.deviceToken) || old.enrollment_hash !== fingerprint(kind, input)) {
            throw new ConflictException('This installation has already joined a family');
          }
          return { id: old.id, role: old.role, elderId: old.elder_id, caregiverId: old.caregiver_id, isDemo: false };
        }
        if (old) {
          if (old.token_hash === hash(input.deviceToken)) throw new ConflictException('Use a new credential to join again');
          await client.query('DELETE FROM devices WHERE id = $1', [old.id]);
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

  private async insertDevice(client: PoolClient, input: FamilyCredentials, role: string, elderId: number, caregiverId: number | null, enrollmentHash: string): Promise<Device> {
    const { rows: [row] } = await client.query(
      `INSERT INTO devices (installation_id, role, elder_id, caregiver_id, token_hash, enrollment_hash)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING id,role`,
      [input.installationId, role, elderId, caregiverId, hash(input.deviceToken), enrollmentHash]);
    return { id: row.id, role: row.role, elderId, caregiverId, isDemo: false };
  }

  private async member(device: Device, client?: PoolClient) {
    if (device.isDemo) throw new ForbiddenException('Demo phones do not have family memberships');
    const sql = `SELECT d.*, COALESCE(c.is_primary,false) AS is_primary FROM devices d
      JOIN families f ON f.elder_id = d.elder_id LEFT JOIN caregivers c ON c.id = d.caregiver_id
      WHERE d.id = $1 AND d.elder_id = $2 AND d.revoked_at IS NULL AND NOT f.is_demo`;
    const rows = client ? (await client.query(sql, [device.id, device.elderId])).rows : await this.db.query(sql, [device.id, device.elderId]);
    if (!rows[0]) throw new UnauthorizedException('Membership is no longer active');
    return rows[0];
  }

  async session(device: Device) {
    const member = await this.member(device);
    return { role: member.role, memberId: member.id, isPrimary: member.is_primary, household: await this.care.household(device.elderId) };
  }

  async members(device: Device) {
    await this.member(device);
    if (device.role !== 'caregiver') throw new ForbiddenException('Only caregivers can view invitations');
    const [family] = await this.db.query('SELECT invite_code FROM families WHERE elder_id = $1 AND NOT is_demo', [device.elderId]);
    if (!family) throw new UnauthorizedException('Membership is no longer active');
    const members = await this.db.query(`SELECT d.id,d.role,COALESCE(c.name,e.name) AS name,COALESCE(c.is_primary,false) AS is_primary
      FROM devices d JOIN elders e ON e.id = d.elder_id LEFT JOIN caregivers c ON c.id = d.caregiver_id
      WHERE d.elder_id = $1 AND d.revoked_at IS NULL ORDER BY d.created_at,d.id`, [device.elderId]);
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
      if (member.is_primary) throw new ForbiddenException('The primary caregiver must delete the family');
      await this.revoke(client, member.id);
    });
  }

  async remove(device: Device, id: string): Promise<void> {
    await this.locked(device, async (client, member) => {
      if (!member.is_primary) throw new ForbiddenException('Only the primary caregiver can remove members');
      if (!UUID.test(id)) throw new NotFoundException('Member not found');
      const { rows: [target] } = await client.query('SELECT id FROM devices WHERE id = $1 AND elder_id = $2 AND revoked_at IS NULL', [id, device.elderId]);
      if (!target) throw new NotFoundException('Member not found');
      if (id === member.id) throw new ForbiddenException('The primary caregiver must delete the family');
      await this.revoke(client, id);
    });
  }

  private async revoke(client: PoolClient, id: string): Promise<void> {
    // Preserve the member identity for earlier dispositions and reject automatic replay of enrollment.
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
