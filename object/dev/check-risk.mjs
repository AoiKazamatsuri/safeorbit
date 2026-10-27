// Live check of the risk flow against a running backend (task T38 acceptance A3). It resets the demo several
// times (registered phones are kept) and leaves it reset after one normal trip. Run from the repository root:
//   node object/dev/check-risk.mjs [--server http://127.0.0.1:3000] [--local] [--apns-configured] [--with-reissue]
// --local resets a backend run with `npm run start:dev`; --apns-configured expects real deliveries instead of
// "notConfigured" (and then sends real notifications to registered caregiver phones); --with-reissue waits about
// 2.5 minutes to see an unanswered navigation request expire and be issued again.
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { demoApi } from './demo-api.mjs';

const argv = process.argv.slice(2);
const option = (name, fallback) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : fallback; };
const repo = fileURLToPath(new URL('../../', import.meta.url));
const api = demoApi(option('--server', 'http://127.0.0.1:3000'));
const apnsConfigured = argv.includes('--apns-configured');
let failures = 0;

function check(name, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? `: ${detail}` : ''}`);
  if (!ok) failures++;
}
function reset() {
  const result = spawnSync('node', ['object/dev/reset-demo.mjs', ...(argv.includes('--local') ? ['--local'] : [])], { cwd: repo, encoding: 'utf8' });
  if (result.status !== 0) throw new Error(`Reset failed: ${result.stderr}`);
}
const count = (actions, type) => actions.filter(a => a.type === type).length;
const kinds = detail => detail.transitions.map(t => `${t.kind}:${t.toLevel ?? t.fromLevel}`).join(' ');
const pushResults = detail => detail.actions.filter(a => a.type !== 'startNavigation' && a.status !== 'skipped').flatMap(a => a.deliveries.map(d => d.result));
const expectedPush = apnsConfigured ? r => r === 'accepted' : r => r === 'notConfigured';

async function scenario(title, track, options = {}) {
  console.log(`\n== ${title}`);
  reset();
  const tokens = await api.phones();
  if (options.settings) await api.call('/v1/caregiver-settings', { method: 'PUT', token: tokens.caregiver, body: options.settings });
  const replayed = await api.replay(track, { token: tokens.elder, stopAfter: options.stopAfter });
  const report = await api.report(tokens.caregiver, replayed.startedAt);
  const details = await Promise.all(report.riskEvents.map(e => api.get(`/v1/risk-events/${e.id}`, tokens.caregiver)));
  console.log(JSON.stringify({ uploads: replayed.uploads, caregiverSees: report.caregiverSees, riskEvents: report.riskEvents }, null, 2));
  return { tokens, replayed, report, details };
}

// 1. Wandering: low -> high -> resolved at home, every action and notification once.
{
  const { tokens, replayed, report, details } = await scenario('home-wander-home: wandering', 'home-wander-home');
  const [d] = details;
  check('one risk event', details.length === 1, `${details.length}`);
  check('wandering: low, then high, then resolved', d && kinds(d) === 'opened:warning escalated:high resolved:high', d && kinds(d));
  check('resolved by settling at home', d?.resolution === 'home');
  check('actions once each', d && ['startNavigation', 'notifyLow', 'notifyHigh', 'notifyResolved'].every(t => count(d.actions, t) === 1),
    d?.actions.map(a => `${a.type}:${a.status}`).join(' '));
  const nav = d?.actions.find(a => a.type === 'startNavigation');
  check('navigation reached the elder phone in an upload reply, once', replayed.actionsInReplies.length === 1 && replayed.actionsInReplies[0].id === nav?.id,
    replayed.actionsInReplies.map(a => `${a.id} in ${a.replies} replies`).join(', '));
  check('unanswered navigation withdrawn on resolution', nav?.status === 'cancelled', nav?.status);
  check(`notifications ${apnsConfigured ? 'accepted by APNs' : 'recorded as notConfigured'}`, pushResults(d).length === 3 && pushResults(d).every(expectedPush), pushResults(d).join(' '));
  check('a behaviour observation tied to the event', d?.observations.length === 1 && d.observations[0].kind === 'wandering');
  check('snapshot back to normal, event still linked', report.caregiverSees.riskLevel === 'normal' && report.caregiverSees.riskEventId === d?.id
    && report.caregiverSees.riskEventStatus === 'resolved');
  check('trip Home–Out–Home ended; not counted as risk-free', report.recentTrips[0]?.name === 'Home–Out–Home' && report.recentTrips[0].endedAt
    && report.caregiverSees.agentStatus === 'Learning daily routes (0/5 trips)', `${report.recentTrips[0]?.name}, ${report.caregiverSees.agentStatus}`);
  check('explanation written', typeof d?.explanation === 'string' && d.explanation.length > 40, d?.explanation);
  const marked = await api.call(`/v1/risk-events/${d.id}/false-alarm`, { method: 'POST', token: tokens.caregiver });
  check('Mark as False Alarm accepted after resolution', marked.status === 200 && marked.data.falseAlarm === true && !marked.data.canMarkFalseAlarm);
}

// 2. Deviation: low risk with reason deviation, resolved at home, never high.
{
  const { details } = await scenario('home-deviation-home: off route', 'home-deviation-home');
  const [d] = details;
  check('one risk event, reason deviation', details.length === 1 && d.anomaly === 'deviation', d?.anomaly);
  check('deviation: low, then resolved (no high)', d && kinds(d) === 'opened:warning resolved:warning', d && kinds(d));
  check('deviation actions once each', d && ['startNavigation', 'notifyLow', 'notifyResolved'].every(t => count(d.actions, t) === 1) && count(d.actions, 'notifyHigh') === 0);
}

// 3. Switches off: no navigation and no low-risk or recovery notification; the risk itself is unchanged.
{
  const off = { autoNavigation: false, lowRiskNotifications: false, recoveryNotifications: false };
  const { tokens, replayed, details } = await scenario('home-deviation-home with switches off', 'home-deviation-home', { settings: off });
  const [d] = details;
  check('settings stored', JSON.stringify(await api.get('/v1/caregiver-settings', tokens.caregiver))
    === JSON.stringify({ autoNavigation: false, lowRiskNotifications: false, recoveryNotifications: false, limitedMonitoringNotifications: true }));
  check('no navigation in upload replies', replayed.actionsInReplies.length === 0);
  check('navigation and notifications skipped', d && d.actions.every(a => a.status === 'skipped'), d?.actions.map(a => `${a.type}:${a.status}`).join(' '));
  check('the risk still opened and resolved', d && kinds(d) === 'opened:warning resolved:warning');
}

// 4. High risk still active: False Alarm refused, a call recorded, We've Met resolves at once.
{
  const { tokens, report, details } = await scenario('home-wander-home stopped in high risk', 'home-wander-home', { stopAfter: 1500 });
  const [d] = details;
  check('active high risk shown', report.caregiverSees.riskLevel === 'high' && /^Wandering for \d+ minutes$/.test(report.caregiverSees.riskHeadline ?? ''),
    `${report.caregiverSees.riskLevel} / ${report.caregiverSees.riskHeadline}`);
  const early = await api.call(`/v1/risk-events/${d.id}/false-alarm`, { method: 'POST', token: tokens.caregiver, allow: [409] });
  check('Mark as False Alarm refused before resolution (409)', early.status === 409, JSON.stringify(early.data));
  if (argv.includes('--with-reissue')) {
    console.log('Waiting 150 s for the unanswered navigation request to expire and be issued again...');
    await new Promise(resolve => setTimeout(resolve, 150_000));
    const later = await api.get(`/v1/risk-events/${d.id}`, tokens.caregiver);
    const navs = later.actions.filter(a => a.type === 'startNavigation');
    check('expired navigation re-issued once', navs.length === 2 && navs[0].status === 'expired' && ['pending', 'delivered'].includes(navs[1].status),
      navs.map(a => `${a.id}:${a.status}`).join(' '));
  }
  const call = await api.call('/v1/calls', { method: 'POST', token: tokens.caregiver, body: { riskEventId: d.id } });
  check('call recorded', call.status === 201 && call.data.riskEventId === d.id);
  const t0 = Date.now();
  const met = await api.call(`/v1/risk-events/${d.id}/met`, { method: 'POST', token: tokens.caregiver });
  check("We've Met resolves immediately", met.status === 200 && met.data.status === 'resolved' && met.data.resolution === 'met', `${Date.now() - t0} ms`);
  const again = await api.call(`/v1/risk-events/${d.id}/met`, { method: 'POST', token: tokens.caregiver, allow: [409] });
  check("We've Met twice is refused (409)", again.status === 409);
  const final = (await api.report(tokens.caregiver, null)).riskEvents.find(e => e.id === d.id);
  const detail = await api.get(`/v1/risk-events/${d.id}`, tokens.caregiver);
  check('resolved notification once, pending navigation withdrawn', count(detail.actions, 'notifyResolved') === 1
    && detail.actions.filter(a => a.type === 'startNavigation').every(a => ['cancelled', 'expired'].includes(a.status)), final.actions.map(a => `${a.type}:${a.status}`).join(' '));
  check('timeline has the call and the resolution', detail.timeline.some(i => i.kind === 'familyCalled') && detail.timeline.at(-1).kind === 'resolved');
  const late = detail.actions.filter(a => a.type === 'startNavigation').at(-1);  // the one withdrawn at resolution
  const answer = await api.call(`/v1/actions/${late.id}/result`, { method: 'POST', token: tokens.elder, body: { result: 'started' }, allow: [409] });
  check('a withdrawn navigation request answers 409', answer.status === 409);
  const marked = await api.call(`/v1/risk-events/${d.id}/false-alarm`, { method: 'POST', token: tokens.caregiver });
  check('Mark as False Alarm accepted after resolution', marked.status === 200 && marked.data.falseAlarm === true);
}

// 5. A normal trip stays normal and counts towards learning the routes.
{
  const { report, details } = await scenario('home-market-home: normal trip', 'home-market-home');
  check('no risk events', details.length === 0);
  check('trip named Home–Market–Home', report.recentTrips[0]?.name === 'Home–Market–Home' && !!report.recentTrips[0].endedAt);
  check('agent status counts it', report.caregiverSees.agentStatus === 'Learning daily routes (1/5 trips)', report.caregiverSees.agentStatus);
  check('risk normal', report.caregiverSees.riskLevel === 'normal' && report.caregiverSees.riskEventId === null);
}

console.log(failures ? `\n${failures} check(s) failed` : '\nAll risk checks passed');
process.exitCode = failures ? 1 : 0;
