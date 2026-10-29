// Demo reset: back to the seeded household with no trips, locations or risk records, and the preset
// "Market" zone given demo-route.json as its reference route (it was never created on a phone, so no
// route was planned for it). Run from the repository root:
//   node object/dev/reset-demo.mjs            reset the backend running in Docker
//   node object/dev/reset-demo.mjs --devices  also forget registered phones
//   node object/dev/reset-demo.mjs --history  reset and ingest one historical month, ready to record
//   node object/dev/reset-demo.mjs --local    reset through a backend run with `npm run start:dev`
import { existsSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { replayHistory } from './replay-history.mjs';

const repo = fileURLToPath(new URL('../../', import.meta.url));
const { note, ...seed } = JSON.parse(readFileSync(new URL('./demo-household.json', import.meta.url), 'utf8'));
const ROUTED_ZONE = 'Market';
if (!seed.safeZones.some(z => z.name === ROUTED_ZONE)) throw new Error(`demo-household.json has no ${ROUTED_ZONE} zone for demo-route.json`);
seed.referenceRoutes = { [ROUTED_ZONE]: JSON.parse(readFileSync(new URL('./demo-route.json', import.meta.url), 'utf8')).points };
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
if (process.exitCode === 0 && process.argv.includes('--history')) {
  const at = process.argv.indexOf('--server');
  const server = at >= 0 ? process.argv[at + 1] : 'http://127.0.0.1:3000';
  try {
    console.log(JSON.stringify(await replayHistory({ server, onTrip: trip => console.log(`${trip.day} ${trip.kind}: ${trip.points.length} fixes`) }), null, 2));
  } catch (error) { console.error('History replay failed:', error.message); process.exitCode = 1; }
}
