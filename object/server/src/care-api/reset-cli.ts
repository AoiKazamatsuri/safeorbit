import 'reflect-metadata';
import { CareStore, HouseholdSeed } from './care-store';
import { GeoPoint } from './geo';
import { DatabaseService } from './database.service';
import { InputError, parseReferenceRoute, parseSafeZone } from './validation';

// Demo reset, run inside the care API so no other process writes the database:
//   node dist/src/care-api/reset-cli.js [--devices] < household.json
// The seed may carry referenceRoutes: { "<zone name>": [WGS-84 points] } for preset zones (T38).
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
    referenceRoutes: parseRoutes(seed.referenceRoutes, seed.safeZones.map((z: any) => String(z?.name ?? '').trim())),
  };
}

function parseRoutes(raw: unknown, zoneNames: string[]): Record<string, GeoPoint[]> {
  if (raw === undefined || raw === null) return {};
  if (typeof raw !== 'object' || Array.isArray(raw)) throw new InputError('referenceRoutes must map zone names to points');
  return Object.fromEntries(Object.entries(raw).map(([name, points]) => {
    if (!zoneNames.includes(name)) throw new InputError(`referenceRoutes names an unknown zone: ${name}`);
    return [name, parseReferenceRoute({ points })];
  }));
}

async function main(): Promise<void> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
  const seed = parseSeed(JSON.parse(Buffer.concat(chunks).toString('utf8')));
  const db = new DatabaseService();
  try {
    await db.onModuleInit();
    await new CareStore(db).reset(seed, { devices: process.argv.includes('--devices') });
    const routes = Object.keys(seed.referenceRoutes ?? {});
    console.log(`Reset done: ${seed.safeZones.length} safe zones, reference route${routes.length === 1 ? '' : 's'}: ${routes.join(', ') || 'none'}`
      + `${process.argv.includes('--devices') ? ', phones unregistered' : ''}`);
  } finally { await db.onModuleDestroy(); }
}

if (require.main === module) {
  main().catch(error => { console.error('Reset failed:', (error as Error).message); process.exitCode = 1; });
}
