// Writes the demo tracks listed in GPX_TRACKS as Xcode location files (WGS-84) under object/dev/tracks/:
//   node object/dev/export-gpx.mjs
// In Xcode: run on the elder phone, then Debug > Simulate Location > <track>.
import { mkdirSync, writeFileSync } from 'node:fs';
import { GPX_TRACKS, TRACKS, toGpx } from './tracks.mjs';

const dir = new URL('./tracks/', import.meta.url);
mkdirSync(dir, { recursive: true });
for (const name of GPX_TRACKS) {
  const track = TRACKS[name]();
  writeFileSync(new URL(`${name}.gpx`, dir), toGpx(name, track));
  console.log(`${name}.gpx: ${track.length} points, ${Math.round(track.at(-1).offset / 60)} min`);
}
