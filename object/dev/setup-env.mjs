import { randomBytes } from 'node:crypto';
import { existsSync, writeFileSync } from 'node:fs';
const file = new URL('../server/.env', import.meta.url);
if (existsSync(file)) {
  console.log('Existing server/.env preserved');
} else {
  writeFileSync(file, [
    'PORT=3000', 'POSTGRES_HOST=127.0.0.1', 'POSTGRES_PORT=5432',
    'POSTGRES_USER=safeorbit', 'POSTGRES_DB=safeorbit',
    'POSTGRES_PASSWORD=' + randomBytes(24).toString('hex'), '',
  ].join('\n'), { flag: 'wx', mode: 0o600 });
  console.log('Created local server/.env with a random database password');
}
