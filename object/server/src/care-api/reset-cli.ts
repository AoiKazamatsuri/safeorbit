import 'reflect-metadata';
import { CareStore, HouseholdSeed } from './care-store';
import { DatabaseService } from './database.service';
import { InputError, parseSafeZone } from './validation';

// Demo reset, run inside the care API so no other process writes the database:
//   node dist/src/care-api/reset-cli.js [--devices] < household.json
function text(value: unknown, field: string): string {
  if (typeof value !== 'string' || !value.trim()) throw new InputError(`${field} is required`);
  return value.trim();
}

export function parseSeed(raw: unknown): HouseholdSeed {
  const seed = raw as Record<string, any>;
  if (!seed || typeof seed !== 'object' || !Array.isArray(seed.safeZones)) throw new InputError('Seed must hold elder, caregiver and safeZones');
  return {
    elder: {
      name: text(seed.elder?.name, 'elder.name'), callName: text(seed.elder?.callName, 'elder.callName'),
      phone: text(seed.elder?.phone, 'elder.phone'), timezone: text(seed.elder?.timezone, 'elder.timezone'),
    },
    caregiver: { name: text(seed.caregiver?.name, 'caregiver.name'), phone: text(seed.caregiver?.phone, 'caregiver.phone') },
    safeZones: seed.safeZones.map(parseSafeZone),
  };
}

async function main(): Promise<void> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
  const seed = parseSeed(JSON.parse(Buffer.concat(chunks).toString('utf8')));
  const db = new DatabaseService();
  try {
    await db.onModuleInit();
    await new CareStore(db).reset(seed, { devices: process.argv.includes('--devices') });
    console.log(`Reset done: ${seed.safeZones.length} safe zones${process.argv.includes('--devices') ? ', phones unregistered' : ''}`);
  } finally { await db.onModuleDestroy(); }
}

if (require.main === module) {
  main().catch(error => { console.error('Reset failed:', (error as Error).message); process.exitCode = 1; });
}
