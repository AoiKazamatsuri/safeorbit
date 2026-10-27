// Uploads a demo track as the elder phone would, timed to end now, then prints what the caregiver phone sees
// and the risk records behind it (risk events, transitions, actions and deliveries). Run from the repository
// root after a reset:
//   node object/dev/replay-track.mjs [home-market-home|home-wander-home|home-deviation-home]
//     [--server http://127.0.0.1:3000] [--batch 12] [--stop-after <seconds>] [--answer started|failed]
// --stop-after cuts the track, e.g. 1000 stops home-market-home at the market, 1500 stops home-wander-home in high risk.
// --answer reports each navigation action back as the App would; without it actions stay unanswered.
import { demoApi } from './demo-api.mjs';

const argv = process.argv.slice(2);
const option = (name, fallback) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : fallback; };
const name = argv.find(a => !a.startsWith('--') && !argv[argv.indexOf(a) - 1]?.startsWith('--')) ?? 'home-market-home';
const api = demoApi(option('--server', 'http://127.0.0.1:3000'));
const tokens = await api.phones();
const replayed = await api.replay(name, {
  token: tokens.elder, batchSize: Number(option('--batch', '12')), stopAfter: Number(option('--stop-after', 'Infinity')),
  answer: option('--answer', null),
});
console.log(JSON.stringify({ ...replayed, ...(await api.report(tokens.caregiver, replayed.startedAt)) }, null, 2));
