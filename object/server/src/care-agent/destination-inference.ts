import { distanceMeters, GeoPoint, isValidPoint, PossibleDestination, SafeZone, StoredFix } from '../care-api/public';
import { Fix } from './trip-recognition';

const WINDOW_MS = 120_000;
const FRESH_MS = 45_000;
const MOVING_MS = 60_000;
const MIN_FIXES = 4;
const MIN_SPAN_MS = 20_000;
const MIN_PROGRESS = 35;
const CORRIDOR = 25;
const JITTER = 12;

// The risk window is the existing record of fixes accepted by the shared quality/ordering filter.
// Intersect it with this trip's trail: late inserts, rejected jumps and replay fixes cannot vote.
export function recentDestinationFixes(trail: StoredFix[], accepted: Fix[] | undefined, now: number): Fix[] {
  const latest = trail.at(-1)?.sampledAt.getTime();
  if (latest === undefined || latest > now || latest + FRESH_MS <= now || !Array.isArray(accepted)) return [];
  const live = new Set<number>();
  for (const point of trail) {
    const t = point.sampledAt.getTime();
    if (t < latest - WINDOW_MS) continue;
    if (point.historyReplay) live.clear();
    else live.add(t);
  }
  // Accuracy coarser than the corridor cannot distinguish adjacent paths even if fit for trip tracking.
  const fixes = accepted.filter(f => live.has(f.t) && isValidPoint(f) && (f.accuracy === null || f.accuracy <= CORRIDOR));
  return fixes.length >= MIN_FIXES && fixes.at(-1)!.t === latest ? fixes : [];
}

interface Route { zoneId: string; points: GeoPoint[] }
interface XY { x: number; y: number }
interface Segment { start: XY; dx: number; dy: number; length: number; offset: number }
interface Projection { along: number; distance: number; direction: number }
interface Track { zoneId: string; projections: Projection[] }

// Use a metre-scale tangent plane around home for these local walking routes. Precompute segment
// lengths once, retaining the cumulative distance from home even through bends in the road.
function segments(points: XY[]): Segment[] {
  let offset = 0;
  const result: Segment[] = [];
  for (let i = 1; i < points.length; i++) {
    const start = points[i - 1], dx = points[i].x - start.x, dy = points[i].y - start.y;
    const length = Math.hypot(dx, dy);
    if (length === 0) continue;
    result.push({ start, dx, dy, length, offset });
    offset += length;
  }
  return result;
}

function project(point: XY, line: Segment[]): Projection {
  let along = 0, distance = Infinity;
  for (const s of line) {
    const x = point.x - s.start.x, y = point.y - s.start.y;
    const part = Math.max(0, Math.min(1, (x * s.dx + y * s.dy) / (s.length * s.length)));
    const d = Math.hypot(x - part * s.dx, y - part * s.dy);
    if (d < distance) { distance = d; along = s.offset + part * s.length; }
  }
  return { along, distance, direction: 0 };
}

// Which directions on a competing route are still plausible at each fix? Direction stays unknown
// until the movement exceeds the jitter allowance, and resets on leaving the road or losing fixes.
function projectTrack(points: XY[], fixes: Fix[], line: Segment[]): Projection[] {
  let low = Infinity, high = -Infinity, direction = 0;
  return points.map((point, i) => {
    const p = project(point, line);
    if (p.distance > CORRIDOR * 2 || (i > 0 && fixes[i].t - fixes[i - 1].t >= FRESH_MS)) {
      low = Infinity; high = -Infinity; direction = 0;
    }
    if (p.distance <= CORRIDOR * 2) {
      if (p.along > low + JITTER) { direction = 1; low = p.along; high = p.along; }
      else if (p.along < high - JITTER) { direction = -1; high = p.along; low = p.along; }
      high = Math.max(high, p.along);
      low = Math.min(low, p.along);
    }
    return { ...p, direction };
  });
}

function validEndpoint(point: GeoPoint, zone: SafeZone): boolean {
  // Account for snapping to a nearby pedestrian road, but a large zone cannot legitimise a stale route.
  return isValidPoint(zone.center) && distanceMeters(point, zone.center) <= Math.min(zone.radiusMeters, 50);
}

function supports(track: Track, sign: number, tracks: Track[], homeId: string, fixes: Fix[], xy: XY[], now: number): number | undefined {
  const target = sign === 1 ? track.zoneId : homeId;
  const projections = track.projections;
  let first = fixes.length;
  let laterMinimum = Infinity;

  // Only the contiguous, distinguishable suffix can support the current direction. As soon as
  // another destination fits again, earlier evidence cannot carry a guess through the common road.
  for (let i = fixes.length - 1; i >= 0; i--) {
    const p = projections[i], along = sign * p.along;
    if (p.distance > CORRIDOR || along > laterMinimum + JITTER) break;
    if (i + 1 < fixes.length) {
      const next = projections[i + 1];
      const step = Math.hypot(xy[i + 1].x - xy[i].x, xy[i + 1].y - xy[i].y);
      // At a self-intersection the nearest projection may jump between distant parts of the route.
      if (fixes[i + 1].t - fixes[i].t >= FRESH_MS || Math.abs(next.along - p.along) > 1.6 * step + JITTER) break;
    }
    const ambiguous = tracks.some(other => {
      if (other === track) return false;
      const rival = other.projections[i];
      if (rival.distance > CORRIDOR * 2 || rival.distance > p.distance + Math.max(JITTER, fixes[i].accuracy ?? 0)) return false;
      return (rival.direction >= 0 && other.zoneId !== target) || (rival.direction <= 0 && homeId !== target);
    });
    if (ambiguous) break;
    laterMinimum = Math.min(laterMinimum, along);
    first = i;
  }

  const last = fixes.length - 1;
  if (fixes.length - first < MIN_FIXES) return;

  // Compare movement in metre-sized steps to suppress stationary jitter without requiring a
  // full step between individual GPS reports. A transverse crossing travels mostly across the road.
  let anchor = first, steps = 0, lastMove = fixes[first].t;
  for (let i = first + 1; i <= last; i++) {
    const advance = sign * (projections[i].along - projections[anchor].along);
    const displacement = Math.hypot(xy[i].x - xy[anchor].x, xy[i].y - xy[anchor].y);
    if (displacement > JITTER && advance < 0.85 * displacement) {
      first = i; anchor = i; steps = 0; lastMove = fixes[i].t;
      continue;
    }
    if (advance < JITTER) continue;
    steps++;
    anchor = i;
    lastMove = fixes[i].t;
  }
  const progress = sign * (projections[last].along - projections[first].along);
  if (fixes.length - first < MIN_FIXES || steps < 2 || progress < MIN_PROGRESS || lastMove - fixes[first].t < MIN_SPAN_MS) return;
  const expires = Math.min(fixes[last].t + FRESH_MS, lastMove + MOVING_MS);
  return expires > now ? expires : undefined;
}

export function inferDestination(fixes: Fix[], zones: SafeZone[], routes: Route[], now: number): PossibleDestination | undefined {
  const home = zones.find(z => z.isHome);
  if (!home || !isValidPoint(home.center) || fixes.length < MIN_FIXES) return;
  const latScale = Math.PI / 180 * 6_371_008.8;
  const lonScale = latScale * Math.cos(home.center.latitude * Math.PI / 180);
  const local = (p: GeoPoint): XY => ({ x: (p.longitude - home.center.longitude) * lonScale, y: (p.latitude - home.center.latitude) * latScale });
  const xy = fixes.map(local);
  const tracks: Track[] = [];
  for (const { zoneId, points } of routes) {
    const zone = zones.find(z => z.id === zoneId && !z.isHome);
    if (!zone || !Array.isArray(points) || points.length < 2 || !points.every(isValidPoint)) continue;
    if (!validEndpoint(points[0], home) || !validEndpoint(points[points.length - 1], zone)) continue;
    const line = segments(points.map(local));
    if (!line.length) continue;
    tracks.push({ zoneId, projections: projectTrack(xy, fixes, line) });
  }
  const destinations = new Map<string, number>();
  for (const track of tracks) {
    for (const sign of [1, -1]) {
      const expires = supports(track, sign, tracks, home.id, fixes, xy, now);
      if (expires === undefined) continue;
      const id = sign === 1 ? track.zoneId : home.id;
      destinations.set(id, Math.max(expires, destinations.get(id) ?? 0));
    }
  }
  if (destinations.size !== 1) return;
  const [[zoneId, expires]] = destinations;
  return { zoneId, expiresAt: new Date(expires).toISOString() };
}
