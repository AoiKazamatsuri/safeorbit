import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const repo = fileURLToPath(new URL('../../', import.meta.url));
let failures = 0;
function check(name, command, args, accept = result => result.status === 0) {
  const result = spawnSync(command, args, { cwd: repo, encoding: 'utf8', timeout: 30000 });
  const ok = accept(result);
  console.log(`${ok ? 'OK' : 'FAIL'} ${name}`);
  if (!ok) { failures++; console.error(result.error?.message ?? result.stderr.trim() ?? 'Check failed'); }
}
const [major, minor] = process.versions.node.split('.').map(Number);
console.log(`${major >= 22 && major < 27 && (major !== 22 || minor >= 6) ? 'OK' : 'FAIL'} Node ${process.versions.node}`);
if (!(major >= 22 && major < 27 && (major !== 22 || minor >= 6))) failures++;
check('Task queue protection', 'sh', ['object/dev/queue.sh', 'doctor'], result => {
  try { const d = JSON.parse(result.stdout); return result.status === 0 && d.protection === 'ready' && d.protocol === 2; } catch { return false; }
});
check('Xcode', 'xcodebuild', ['-version']);
check('iPhone simulator', 'xcrun', ['simctl', 'list', 'devices', 'available', '-j'], result => {
  try { return result.status === 0 && Object.values(JSON.parse(result.stdout).devices).flat().some(d => d.isAvailable && d.name.startsWith('iPhone')); } catch { return false; }
});
const docker = '/Applications/Docker.app/Contents/Resources/bin/docker';
check('Docker Engine', existsSync(docker) ? docker : 'docker', ['info', '--format', '{{.ServerVersion}}']);
check('Compose configuration', 'sh', ['object/dev/compose.sh', 'config', '--quiet']);
for (const path of ['object/ios/SafeOrbit.xcodeproj/project.pbxproj', 'object/server/.env', 'object/server/node_modules/@nestjs/core/package.json', 'object/server/node_modules/dependency-cruiser/package.json', 'object/dev/node_modules/xcode/package.json']) {
  const ok = existsSync(repo + path);
  console.log(`${ok ? 'OK' : 'FAIL'} ${path}`); if (!ok) failures++;
}
if (process.argv.includes('--running')) {
  // Read only the port, never print local credentials.
  const env = readFileSync(repo + 'object/server/.env', 'utf8');
  const port = env.match(/^PORT=(\d+)$/m)?.[1] ?? '3000';
  try {
    const response = await fetch(`http://127.0.0.1:${port}/health/ready`, { signal: AbortSignal.timeout(5000) });
    const result = await response.json();
    const ok = response.ok && result.status === 'ok' && result.database === 'postgis';
    console.log(`${ok ? 'OK' : 'FAIL'} Server and PostGIS readiness`); if (!ok) failures++;
  } catch (error) { console.log('FAIL Server and PostGIS readiness: ' + error.message); failures++; }
}
console.log(failures === 0 ? 'Environment ready' : `${failures} environment check(s) failed`);
process.exitCode = failures ? 1 : 0;
