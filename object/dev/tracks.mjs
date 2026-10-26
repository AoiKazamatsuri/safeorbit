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

// legs: ['walk', polyline] walks the polyline from its first point; ['dwell', seconds] stays put.
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
};
