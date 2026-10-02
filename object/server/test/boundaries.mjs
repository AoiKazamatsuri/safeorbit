import { writeFileSync, unlinkSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
const file = 'src/care-agent/__boundary_probe.ts';
for (const [source, expected] of [
  ["import { Pool } from 'pg'; export const probe = Pool;", 'only-care-api-accesses-database'],
  ["import { DatabaseService } from '../care-api/database.service'; export const probe = DatabaseService;", 'consumers-use-only-care-api-public'],
]) {
  let created = false;
  try {
    writeFileSync(file, source, { flag: 'wx' });
    created = true;
    const result = spawnSync('node_modules/.bin/depcruise', ['--config', '.dependency-cruiser.cjs', 'src'], { encoding: 'utf8' });
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.ok(result.stdout.includes(expected), result.stdout);
    console.log('Rejected: ' + expected);
  } finally { if (created) unlinkSync(file); }
}
