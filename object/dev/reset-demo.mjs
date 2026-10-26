// Demo reset: back to the seeded household with no trips or locations. Run from the repository root:
//   node object/dev/reset-demo.mjs            reset the backend running in Docker
//   node object/dev/reset-demo.mjs --devices  also forget registered phones
//   node object/dev/reset-demo.mjs --local    reset through a backend run with `npm run start:dev`
import { existsSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const repo = fileURLToPath(new URL('../../', import.meta.url));
const { note, ...seed } = JSON.parse(readFileSync(new URL('./demo-household.json', import.meta.url), 'utf8'));
// Real phone numbers for recording stay in the ignored server/.env; values are never printed.
const envFile = new URL('../server/.env', import.meta.url);
const env = existsSync(envFile)
  ? Object.fromEntries(readFileSync(envFile, 'utf8').split('\n').map(l => /^([A-Z0-9_]+)=(.*)$/.exec(l.trim())).filter(Boolean).map(m => [m[1], m[2]]))
  : {};
if (env.DEMO_ELDER_PHONE) seed.elder.phone = env.DEMO_ELDER_PHONE;
if (env.DEMO_CAREGIVER_PHONE) seed.caregiver.phone = env.DEMO_CAREGIVER_PHONE;

const extra = process.argv.includes('--devices') ? ['--devices'] : [];
const [command, args] = process.argv.includes('--local')
  ? ['node', ['--env-file=object/server/.env', 'object/server/dist/src/care-api/reset-cli.js', ...extra]]
  : ['sh', ['object/dev/compose.sh', 'exec', '-T', 'server', 'node', 'dist/src/care-api/reset-cli.js', ...extra]];
const result = spawnSync(command, args, { cwd: repo, input: JSON.stringify(seed), stdio: ['pipe', 'inherit', 'inherit'] });
console.log(`Phone numbers: elder ${env.DEMO_ELDER_PHONE ? 'from server/.env' : 'fictional'}, caregiver ${env.DEMO_CAREGIVER_PHONE ? 'from server/.env' : 'fictional'}`);
process.exitCode = result.status ?? 1;
