import 'reflect-metadata';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { NestFactory } from '@nestjs/core';
import { Module } from '@nestjs/common';
import { HealthController } from '../src/care-api/health.controller';
import { DatabaseService } from '../src/care-api/database.service';

let databaseAvailable = true;
@Module({ controllers: [HealthController], providers: [
  { provide: DatabaseService, useValue: { check: async () => {
    if (!databaseAvailable) throw new Error('Connection failed');
  } } },
] })
class TestModule {}

test('HTTP health distinguishes process health from database readiness', async () => {
  const app = await NestFactory.create(TestModule, { logger: false });
  await app.listen(0, '127.0.0.1');
  const base = await app.getUrl();
  try {
    assert.deepEqual(await (await fetch(base + '/health')).json(), { status: 'ok' });
    assert.equal((await fetch(base + '/health/ready')).status, 200);
    databaseAvailable = false;
    assert.equal((await fetch(base + '/health/ready')).status, 503);
    assert.equal((await fetch(base + '/health')).status, 200);
  } finally { await app.close(); }
});
