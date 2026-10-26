import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Pool, PoolClient, QueryResultRow } from 'pg';
import { SCHEMA_SQL } from './schema';

export function createPool(): Pool {
  return new Pool({
    host: process.env.POSTGRES_HOST ?? '127.0.0.1',
    port: Number(process.env.POSTGRES_PORT ?? 5432),
    user: process.env.POSTGRES_USER ?? 'safeorbit',
    password: process.env.POSTGRES_PASSWORD,
    database: process.env.POSTGRES_DB ?? 'safeorbit',
    connectionTimeoutMillis: 3000,
    query_timeout: 15000,
    max: 5,
  });
}

// Serialises concurrent schema runs (server start and the reset command).
export async function applySchema(client: Pool | PoolClient): Promise<void> {
  await client.query('SELECT pg_advisory_lock(37037)');
  try { await client.query(SCHEMA_SQL); } finally { await client.query('SELECT pg_advisory_unlock(37037)'); }
}

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly pool = createPool();

  async onModuleInit(): Promise<void> {
    // Keep starting when the database is down so /health/ready can report it.
    try { const client = await this.pool.connect(); try { await applySchema(client); } finally { client.release(); } }
    catch (error) { console.error('Schema not applied:', (error as Error).message); }
  }

  async check(): Promise<void> {
    await this.pool.query('SELECT PostGIS_Version()');
  }

  async query<T extends QueryResultRow>(text: string, values: unknown[] = []): Promise<T[]> {
    return (await this.pool.query<T>(text, values)).rows;
  }

  async transaction<T>(work: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await work(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally { client.release(); }
  }

  async onModuleDestroy(): Promise<void> {
    await this.pool.end();
  }
}
