import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Pool } from 'pg';

@Injectable()
export class DatabaseService implements OnModuleDestroy {
  private readonly pool = new Pool({
    host: process.env.POSTGRES_HOST ?? '127.0.0.1',
    port: Number(process.env.POSTGRES_PORT ?? 5432),
    user: process.env.POSTGRES_USER ?? 'safeorbit',
    password: process.env.POSTGRES_PASSWORD,
    database: process.env.POSTGRES_DB ?? 'safeorbit',
    connectionTimeoutMillis: 3000,
    query_timeout: 3000,
    max: 5,
  });

  async check(): Promise<void> {
    await this.pool.query('SELECT PostGIS_Version()');
  }

  async onModuleDestroy(): Promise<void> {
    await this.pool.end();
  }
}
