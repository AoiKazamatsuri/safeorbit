// One calendar month of deterministic, timestamped WGS-84 fixes for the recording demo (T39).
// History follows the demo streets and varies the walk for each day.
import { readFileSync } from 'node:fs';
import { buildTrack, demoRoute, distance, offset, routePrefix, TRACKS } from './tracks.mjs';

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

// Pause along the street without changing the intersection vertices or the destination.
function walkWithPause(route, meters, seconds) {
  const approach = routePrefix(route, meters);
  return [['walk', approach], ['dwell', seconds], ['walk', [approach.at(-1), ...route.slice(approach.length - 1)]]];
}

function varyWalk(fixes, seed) {
  let elapsed = 0;
  return fixes.map((fix, index) => {
    if (fix.speed === 0) {
      elapsed += 5;
      return { ...fix, offset: elapsed };
    }
    const phase = index * 0.19 + seed;
    const interval = 5 + Math.round(1.3 * Math.sin(phase) + 0.7 * Math.sin(index * 0.41));
    elapsed += interval;
    const along = fix.course * Math.PI / 180;
    const meters = 3.4 + 1.4 * Math.sin(phase) + 0.9 * Math.sin(index * 0.47 + seed);
    // Opposite headings use opposite sides of the same street. Ease onto the
    // street when leaving a stop and back to the surveyed point when arriving.
    const isStopBoundary = !fixes[index - 1]?.speed || !fixes[index + 1]?.speed;
    const sway = isStopBoundary ? 0 : meters;
    const point = offset(fix, Math.cos(along) * sway, -Math.sin(along) * sway);
    const stride = index === 0 ? 0 : distance(fix, fixes[index - 1]);
    return { ...fix, latitude: +point.latitude.toFixed(7), longitude: +point.longitude.toFixed(7),
      offset: elapsed, speed: +(stride / interval).toFixed(2) };
  });
}

export function historyTrack(kind, seed = 0) {
  const route = demoRoute();
  if (kind === 'normal') {
    const toMarket = walkWithPause(route, 174 + seed % 93, 10 + seed % 4 * 5);
    const toHome = walkWithPause([...route].reverse(), 209 + seed % 81, 10 + seed % 3 * 5);
    return varyWalk(buildTrack([['dwell', 120], ...toMarket, ['dwell', 300], ...toHome, ['dwell', 240]]), seed);
  }
  if (kind === 'wandering') {
    return varyWalk(TRACKS['home-wander-home'](), seed);
  }
  if (kind !== 'deviation') throw new Error(`Unknown history track: ${kind}`);
  // Continue east on Beijing West Road past the south turn onto Ninghai Road, then walk back.
  // This is a synthetic extension of the first street segment; replace it with the filming GPS trace.
  const cornerIndex = 3;
  const corner = route[cornerIndex];
  const east = { latitude: corner.latitude - 0.00013, longitude: corner.longitude + 0.0053 };
  const outward = [...route.slice(0, cornerIndex + 1), east];
  return varyWalk(buildTrack([['dwell', 120], ['walk', outward], ['dwell', 10], ['walk', [...outward].reverse()], ['dwell', 240]]), seed);
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
    const seed = Number(day.replaceAll('-', '').slice(4));
    const points = historyTrack(kind, seed).map(({ offset, ...fix }) => ({ sampledAt: new Date(start + offset * 1000).toISOString(), ...fix }));
    if (Date.parse(points.at(-1).sampledAt) >= now.getTime()) throw new Error('History must finish before now');
    return { day, kind, points };
  });
  return { timezone, from, to: addDays(end, -1), trips };
}
