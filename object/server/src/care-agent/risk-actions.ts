import { ActionWrite, CaregiverSettings } from '../care-api/public';
import { RiskOutput } from './risk-rules';

// Outreach decisions (engineering architecture section 8 step 5, product design 3.4). Pure: each risk
// transition maps to fixed actions with an idempotency key, so reprocessing never acts twice.
// Low: start navigation home on the elder phone (unless switched off) and a normal notification
// (unless switched off). High: a time-sensitive alert, which cannot be switched off. Resolved: a
// normal notification (unless switched off); pending navigation is withdrawn by the store.
// Actions switched off are still recorded, as skipped, so the event page can say what did not happen.
export const NAVIGATION_TTL_SECONDS = 120;

export function planActions(outputs: RiskOutput[], settings: CaregiverSettings): ActionWrite[] {
  const actions: ActionWrite[] = [];
  for (const o of outputs) {
    if (o.type === 'observation') continue;
    const decidedAt = new Date(o.at);
    if (o.type === 'opened') {
      actions.push({
        riskKey: o.key, kind: 'startNavigation', target: 'elder', idempotencyKey: `${o.key}:startNavigation:1`,
        status: settings.autoNavigation ? 'pending' : 'skipped', reason: settings.autoNavigation ? null : 'autoNavigationOff',
        details: { seq: 1 }, decidedAt, expiresInSeconds: settings.autoNavigation ? NAVIGATION_TTL_SECONDS : null,
      });
      actions.push({
        riskKey: o.key, kind: 'notifyLow', target: 'caregivers', idempotencyKey: `${o.key}:notifyLow`,
        status: settings.lowRiskNotifications ? 'pending' : 'skipped', reason: settings.lowRiskNotifications ? null : 'lowRiskNotificationsOff',
        details: { anomaly: o.anomaly, minutes: o.minutes, navigation: settings.autoNavigation }, decidedAt, expiresInSeconds: null,
      });
    } else if (o.type === 'escalated') {
      actions.push({
        riskKey: o.key, kind: 'notifyHigh', target: 'caregivers', idempotencyKey: `${o.key}:notifyHigh`, status: 'pending', reason: null,
        details: { anomaly: o.anomaly, minutes: o.minutes }, decidedAt, expiresInSeconds: null,
      });
    } else if (o.type === 'resolved') {
      actions.push({
        riskKey: o.key, kind: 'notifyResolved', target: 'caregivers', idempotencyKey: `${o.key}:notifyResolved`,
        status: settings.recoveryNotifications ? 'pending' : 'skipped', reason: settings.recoveryNotifications ? null : 'recoveryNotificationsOff',
        details: { anomaly: o.anomaly, resolution: o.resolution }, decidedAt, expiresInSeconds: null,
      });
    }
  }
  return actions;
}

export interface NavigationRecord { seq: number; status: string; expiresAt: Date | null }

// Re-evaluation of a navigation action (section 8: valid 120 s, re-evaluated on expiry). While the risk is
// active and auto navigation is on, a request that lapsed without any answer from the elder phone is
// replaced by a fresh one, but only while her phone is reporting (newest fix fresh). An answered request
// ("started" or "failed") is final: on failure the App has already shown its fallback notification.
export function navigationReissue(latest: NavigationRecord | null, now: number,
  opts: { riskActive: boolean; autoNavigation: boolean; fixFresh: boolean }): { expire: boolean; issueSeq: number | null } {
  const none = { expire: false, issueSeq: null };
  if (!latest || !opts.riskActive) return none;
  const lapsedNow = (latest.status === 'pending' || latest.status === 'delivered')
    && latest.expiresAt !== null && latest.expiresAt.getTime() <= now;
  if (!lapsedNow && latest.status !== 'expired') return none;
  return { expire: lapsedNow, issueSeq: opts.autoNavigation && opts.fixFresh ? latest.seq + 1 : null };
}

export function navigationAction(riskKey: string, seq: number, at: number): ActionWrite {
  return {
    riskKey, kind: 'startNavigation', target: 'elder', idempotencyKey: `${riskKey}:startNavigation:${seq}`, status: 'pending',
    reason: null, details: { seq }, decidedAt: new Date(at), expiresInSeconds: NAVIGATION_TTL_SECONDS,
  };
}
