// Shared helpers for the replay and check scripts: talk to the care API as the two demo phones.
import { TRACKS } from './tracks.mjs';

export function demoApi(server = 'http://127.0.0.1:3000') {
  async function call(path, { method = 'GET', token, body, allow = [] } = {}) {
    const response = await fetch(server + path, {
      method, body: body && JSON.stringify(body),
      headers: { 'Content-Type': 'application/json', ...(token && { Authorization: `Bearer ${token}` }) },
    });
    const data = response.status === 204 ? null : await response.json();
    if (!response.ok && !allow.includes(response.status)) throw new Error(`${method} ${path} → ${response.status} ${JSON.stringify(data)}`);
    return { status: response.status, data };
  }
  const get = async (path, token) => (await call(path, { token })).data;

  async function phones() {
    const elder = (await call('/v1/devices', { method: 'POST', body: { role: 'elder', installationId: 'replay-elder-phone' } })).data;
    const caregiver = (await call('/v1/devices', { method: 'POST', body: { role: 'caregiver', installationId: 'replay-caregiver-phone' } })).data;
    return { elder: elder.deviceToken, caregiver: caregiver.deviceToken };
  }

  // Uploads a track as the elder phone would, timed to end now. Returns the actions seen in upload replies;
  // with answer = 'started' | 'failed' it reports each new navigation action back, like the App.
  async function replay(name, { token, batchSize = 12, stopAfter = Infinity, answer = null } = {}) {
    if (!TRACKS[name]) throw new Error(`Unknown track ${name}; known: ${Object.keys(TRACKS).join(', ')}`);
    const track = TRACKS[name]().filter(fix => fix.offset <= stopAfter);
    const start = Date.now() - 1000 - track.at(-1).offset * 1000;
    const tally = {};
    const actions = new Map();
    for (let i = 0; i < track.length; i += batchSize) {
      const points = track.slice(i, i + batchSize).map(({ offset, ...fix }) => ({ sampledAt: new Date(start + offset * 1000).toISOString(), ...fix }));
      const reply = (await call('/v1/locations', {
        method: 'POST', token, body: { points, batteryPercent: 80, locationPermission: 'always', preciseLocation: true },
      })).data;
      for (const { status } of reply.results) tally[status] = (tally[status] ?? 0) + 1;
      for (const action of reply.actions) {
        if (actions.has(action.id)) { actions.get(action.id).replies++; continue; }
        actions.set(action.id, { ...action, replies: 1, sampleTime: points.at(-1).sampledAt });
        if (answer) {
          await call(`/v1/actions/${action.id}/result`, { method: 'POST', token,
            body: answer === 'failed' ? { result: 'failed', reason: 'replayScript' } : { result: 'started' } });
        }
      }
    }
    return { track: name, points: track.length, startedAt: new Date(start).toISOString(), uploads: tally, actionsInReplies: [...actions.values()] };
  }

  // Waits until the outreach gateway has handled every notification (it runs after the reply).
  async function settled(caregiver, ids, timeoutMs = 8000) {
    const until = Date.now() + timeoutMs;
    for (;;) {
      const details = await Promise.all(ids.map(id => get(`/v1/risk-events/${id}`, caregiver)));
      const busy = details.some(d => d.actions.some(a => ['pending', 'sending'].includes(a.status) && a.type !== 'startNavigation'));
      if (!busy || Date.now() > until) return details;
      await new Promise(resolve => setTimeout(resolve, 300));
    }
  }

  // What the caregiver phone sees, plus the risk records behind it.
  async function report(caregiver, sinceIso) {
    const location = await get('/v1/location', caregiver);
    const trips = await get('/v1/trips?limit=3', caregiver);
    const events = (await get('/v1/risk-events?limit=20', caregiver)).filter(e => !sinceIso || e.anomalyStartedAt >= sinceIso).reverse();
    const details = await settled(caregiver, events.map(e => e.id));
    return {
      caregiverSees: {
        status: location.status, phase: location.phase, tripName: location.tripName, recordedAt: location.recordedAt,
        trailPoints: location.trail.length, batteryPercent: location.batteryPercent, riskLevel: location.riskLevel,
        riskHeadline: location.riskHeadline, riskEventId: location.riskEventId, riskEventStatus: location.riskEventStatus,
        agentStatus: location.agentStatus,
      },
      recentTrips: trips.map(t => ({ name: t.name, startedAt: t.startedAt, endedAt: t.endedAt, startKnown: t.startKnown })),
      riskEvents: details.map(d => ({
        id: d.id, anomaly: d.anomaly, level: d.level, status: d.status, resolution: d.resolution, falseAlarm: d.falseAlarm,
        anomalyStartedAt: d.anomalyStartedAt, headline: d.headline, trailPoints: d.trail.length,
        transitions: d.transitions.map(t => `${t.seq} ${t.kind} ${t.fromLevel ?? '-'}→${t.toLevel ?? '-'} @${t.at}`),
        actions: d.actions.map(a => ({ id: a.id, type: a.type, status: a.status, reason: a.reason, deliveries: a.deliveries.map(x => `${x.channel}:${x.result}`) })),
        help: d.help.map(h => h.text),
        explanation: d.explanation,
      })),
    };
  }

  return { call, get, phones, replay, report };
}
