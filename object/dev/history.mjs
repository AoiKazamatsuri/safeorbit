// One calendar month of deterministic, timestamped WGS-84 fixes for the recording demo (T39).
// History is generated from the same street vertices as the live demo; no pre-written risks or trips.
import { readFileSync } from 'node:fs';
import { buildTrack, demoRoute, routePrefix } from './tracks.mjs';

export function localDay(value, timezone) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(value);
}
export function addDays(day, count) {
  const date = new Date(day + 'T12:00:00Z');
  date.setUTCDate(date.getUTCDate() + count);
  return date.toISOString().slice(0, 10);
}
export function localInstant(day, hour, minute, timezone) {
  const target = Date.parse(`${day}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00Z`);
  let value = target;
  const formatter = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' });
  for (let i = 0; i < 4; i++) {
    const parts = Object.fromEntries(formatter.formatToParts(value).map(p => [p.type, p.value]));
    const shown = Date.parse(`${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}Z`);
    const delta = target - shown;
    value += delta;
    if (!delta) break;
  }
  return value;
}

export function historyTrack(kind) {
  const route = demoRoute();
  const home = route[0];
  if (kind === 'normal') return buildTrack([['dwell', 120], ['walk', route], ['dwell', 300], ['walk', [...route].reverse()], ['dwell', 240]]);
  const approach = routePrefix(route, 270);
  if (kind === 'wandering') {
    // Walk back and forth on a 24 m piece of the known street, rather than drawing a circle off-road.
    const start = approach.at(-1), end = routePrefix(route, 294).at(-1);
    const legs = [['dwell', 120], ['walk', approach]];
    for (let i = 0; i < 22; i++) legs.push(['walk', [start, end]], ['walk', [end, start]]);
    legs.push(['walk', [...approach].reverse()], ['dwell', 240]);
    return buildTrack(legs);
  }
  if (kind !== 'deviation') throw new Error(`Unknown history track: ${kind}`);
  // Continue east on Beijing West Road past the south turn onto Ninghai Road, then walk back.
  // This is a synthetic extension of the first street segment; replace it with the filming GPS trace.
  const cornerIndex = 3;
  const corner = route[cornerIndex];
  const east = { latitude: corner.latitude - 0.00013, longitude: corner.longitude + 0.0053 };
  const outward = [...route.slice(0, cornerIndex + 1), east];
  return buildTrack([['dwell', 120], ['walk', outward], ['walk', [...outward].reverse()], ['walk', [home, home]], ['dwell', 240]]);
}

export function generateHistory({ now = new Date(), timezone = JSON.parse(readFileSync(new URL('./demo-household.json', import.meta.url))).elder.timezone } = {}) {
  now = new Date(now);
  if (!Number.isFinite(now.getTime())) throw new Error('Invalid history clock');
  const end = localDay(now, timezone);
  const date = new Date(end + 'T12:00:00Z');
  const dayOfMonth = date.getUTCDate();
  date.setUTCDate(1);
  date.setUTCMonth(date.getUTCMonth() - 1);
  const last = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate();
  date.setUTCDate(Math.min(dayOfMonth, last));
  const from = date.toISOString().slice(0, 10);
  const days = [];
  for (let day = from; day < end; day = addDays(day, 1)) days.push(day);
  const outings = days.filter(day => new Date(day + 'T12:00:00Z').getUTCDay() !== 0);
  const trips = outings.map((day, index) => {
    const kind = index === outings.length - 1 || index === 5 || index === 14 ? 'deviation' : index === 9 || index === 19 ? 'wandering' : 'normal';
    const start = localInstant(day, 9, index % 3 * 5, timezone);
    const points = historyTrack(kind).map(({ offset, ...fix }) => ({ sampledAt: new Date(start + offset * 1000).toISOString(), ...fix }));
    if (Date.parse(points.at(-1).sampledAt) >= now.getTime()) throw new Error('History must finish before now');
    return { day, kind, points };
  });
  return { timezone, from, to: addDays(end, -1), trips };
}
