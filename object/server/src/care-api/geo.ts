// WGS-84 geometry shared by the care API and its consumers; short distances only.
export interface GeoPoint { latitude: number; longitude: number }

const EARTH_RADIUS_M = 6_371_008.8;
const rad = (deg: number) => (deg * Math.PI) / 180;

export function distanceMeters(a: GeoPoint, b: GeoPoint): number {
  const dLat = rad(b.latitude - a.latitude);
  const dLon = rad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function bearingDegrees(from: GeoPoint, to: GeoPoint): number {
  const y = Math.sin(rad(to.longitude - from.longitude)) * Math.cos(rad(to.latitude));
  const x = Math.cos(rad(from.latitude)) * Math.sin(rad(to.latitude))
    - Math.sin(rad(from.latitude)) * Math.cos(rad(to.latitude)) * Math.cos(rad(to.longitude - from.longitude));
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

export function isValidPoint(p: Partial<GeoPoint> | null | undefined): p is GeoPoint {
  return !!p && Number.isFinite(p.latitude) && Number.isFinite(p.longitude)
    && Math.abs(p.latitude!) <= 90 && Math.abs(p.longitude!) <= 180;
}

// Shortest distance from a point to a polyline, on a local flat projection around the point (fine for a few km).
export function distanceToPolylineMeters(p: GeoPoint, line: GeoPoint[]): number {
  if (!line.length) return Infinity;
  if (line.length === 1) return distanceMeters(p, line[0]);
  const kx = rad(1) * EARTH_RADIUS_M * Math.cos(rad(p.latitude));
  const ky = rad(1) * EARTH_RADIUS_M;
  const xy = (q: GeoPoint) => [(q.longitude - p.longitude) * kx, (q.latitude - p.latitude) * ky];
  let best = Infinity;
  for (let i = 1; i < line.length; i++) {
    const [ax, ay] = xy(line[i - 1]);
    const [bx, by] = xy(line[i]);
    const dx = bx - ax, dy = by - ay;
    const len2 = dx * dx + dy * dy;
    const f = len2 === 0 ? 0 : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / len2));
    best = Math.min(best, Math.hypot(ax + f * dx, ay + f * dy));
  }
  return best;
}
