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
