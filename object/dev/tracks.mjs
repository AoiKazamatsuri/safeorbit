// Timed WGS-84 tracks for the demo: used by replay-track.mjs, later also exported as Xcode GPX files.
import { readFileSync } from 'node:fs';

const R = 6371008.8;
const rad = d => (d * Math.PI) / 180;
export function distance(a, b) {
  const h = Math.sin(rad(b.latitude - a.latitude) / 2) ** 2
    + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(rad(b.longitude - a.longitude) / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}
function bearing(a, b) {
  const y = Math.sin(rad(b.longitude - a.longitude)) * Math.cos(rad(b.latitude));
  const x = Math.cos(rad(a.latitude)) * Math.sin(rad(b.latitude)) - Math.sin(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.cos(rad(b.longitude - a.longitude));
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

export const demoRoute = () => JSON.parse(readFileSync(new URL('./demo-route.json', import.meta.url), 'utf8')).points;

// A point moved east and north by the given metres.
export function offset(p, east, north) {
  return { latitude: p.latitude + north / 111320, longitude: p.longitude + east / (111320 * Math.cos(rad(p.latitude))) };
}

// The first `meters` of a polyline, ending exactly at that distance.
export function routePrefix(line, meters) {
  const out = [line[0]];
  let left = meters;
  for (let i = 1; i < line.length; i++) {
    const d = distance(line[i - 1], line[i]);
    if (d >= left) {
      const f = left / d;
      out.push({ latitude: line[i - 1].latitude + (line[i].latitude - line[i - 1].latitude) * f,
        longitude: line[i - 1].longitude + (line[i].longitude - line[i - 1].longitude) * f });
      return out;
    }
    out.push(line[i]); left -= d;
  }
  return out;
}

// legs: ['walk', polyline] walks the polyline from its first point; ['dwell', seconds] stays put;
// ['loop', { seconds, radius }] walks round a small circle that starts and ends where she stands.
// Returns one fix every stepSeconds, offsets in seconds from the track start.
export function buildTrack(legs, { stepSeconds = 5, speedMps = 1.0, accuracy = 8 } = {}) {
  const fixes = [];
  let clock = 0;
  let at = legs.find(([kind]) => kind === 'walk')?.[1][0];  // a leading dwell waits where the first walk begins
  const emit = (p, speed, course) => {
    clock += stepSeconds;
    fixes.push({ offset: clock, latitude: +p.latitude.toFixed(7), longitude: +p.longitude.toFixed(7), accuracy, speed, course });
  };
  for (const [kind, arg] of legs) {
    if (kind === 'dwell') {
      for (let s = stepSeconds; s <= arg; s += stepSeconds) emit(at, 0, null);
      continue;
    }
    if (kind === 'loop') {
      const c = at, r = arg.radius;
      for (let s = stepSeconds; s <= arg.seconds; s += stepSeconds) {
        const a = (s * speedMps) / r;  // the circle's centre is r metres west of the start
        emit(offset(c, r * (Math.cos(a) - 1), r * Math.sin(a)), speedMps, Math.round((((-a * 180) / Math.PI) % 360 + 360) % 360));
      }
      continue;
    }
    // Evenly spaced along the polyline, so corners are walked rather than cut.
    const cumulative = [0];
    for (let i = 1; i < arg.length; i++) cumulative.push(cumulative[i - 1] + distance(arg[i - 1], arg[i]));
    const total = cumulative.at(-1), stride = stepSeconds * speedMps;
    let segment = 1;
    for (let s = stride; s < total + stride; s += stride) {
      const d = Math.min(s, total);
      while (segment < arg.length - 1 && cumulative[segment] < d) segment++;
      const from = arg[segment - 1], to = arg[segment];
      const f = (d - cumulative[segment - 1]) / ((cumulative[segment] - cumulative[segment - 1]) || 1);
      emit({ latitude: from.latitude + (to.latitude - from.latitude) * f, longitude: from.longitude + (to.longitude - from.longitude) * f },
        speedMps, Math.round(bearing(from, to)));
    }
    at = arg.at(-1);
  }
  return fixes;
}

export const TRACKS = {
  // Scene "normal trip": settle at home, walk to the market, shop, walk back, settle at home.
  'home-market-home': () => {
    const route = demoRoute();
    return buildTrack([['dwell', 120], ['walk', route], ['dwell', 300], ['walk', [...route].reverse()], ['dwell', 240]]);
  },
  // Scenes "low risk", "high risk", "risk resolved": walk 300 m of the market route, wander in a 12 m loop
  // for 17 minutes (low risk at 7, high at 15 minutes from the start of the wandering), walk back home and
  // settle 240 s (resolved 180 s after she is well inside home). About 33 minutes.
  'home-wander-home': () => {
    const part = routePrefix(demoRoute(), 300);
    return buildTrack([['dwell', 120], ['walk', part], ['loop', { seconds: 17 * 60, radius: 12 }], ['walk', [...part].reverse()], ['dwell', 240]]);
  },
  // Replay check only (not exported): leaves the market route northwards, stays more than 80 m off it for
  // about 11 minutes (low risk, reason deviation; not long enough for high), then walks straight home.
  'home-deviation-home': () => {
    const route = demoRoute();
    const a = routePrefix(route, 150).at(-1);
    const b = offset(a, 0, 200), c = offset(b, 300, 0);
    return buildTrack([['dwell', 120], ['walk', routePrefix(route, 150)], ['walk', [a, b, c, route[0]]], ['dwell', 240]]);
  },
};

// Tracks written as Xcode GPX files by export-gpx.mjs; the rest are for replay-track.mjs only.
export const GPX_TRACKS = ['home-market-home', 'home-wander-home'];

// Xcode plays a GPX file at the pace of its <time> stamps; the base date is arbitrary.
export function toGpx(name, track, base = Date.UTC(2026, 0, 1)) {
  const points = track.map(f =>
    `  <wpt lat="${f.latitude}" lon="${f.longitude}"><time>${new Date(base + f.offset * 1000).toISOString().replace('.000Z', 'Z')}</time></wpt>`);
  return `<?xml version="1.0" encoding="UTF-8"?>\n<gpx version="1.1" creator="SafeOrbit object/dev/tracks.mjs">\n  <metadata><name>${name}</name></metadata>\n${points.join('\n')}\n</gpx>\n`;
}
