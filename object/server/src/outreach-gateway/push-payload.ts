import { ActionKind } from '../care-api/public';
import { PushMessage } from './push-sender';

// Caregiver notifications (product design 5.9). Text travels as localisation keys with arguments, so the
// phone shows its own language and the server never needs the reader's language (section 12). No
// coordinates or trail ever go into a payload (lock-screen privacy).
//
// Keys and their English text (the App's Localizable.xcstrings holds them):
//   PUSH_RISK_LOW_TITLE            "%@ may need help"                                          [callName]
//   PUSH_RISK_LOW_WANDERING_NAV    "Wandering for %@ minutes. Starting navigation home for her." [minutes]
//   PUSH_RISK_LOW_WANDERING        "Wandering for %@ minutes."                                 [minutes]
//   PUSH_RISK_LOW_DEVIATION_NAV    "Off her usual route for %@ minutes. Starting navigation home for her." [minutes]
//   PUSH_RISK_LOW_DEVIATION        "Off her usual route for %@ minutes."                       [minutes]
//   PUSH_RISK_HIGH_TITLE           "High risk: %@ needs you"                                    [callName]
//   PUSH_RISK_HIGH_WANDERING       "Still wandering after %@ minutes. Open to call her."        [minutes]
//   PUSH_RISK_HIGH_DEVIATION       "Still off her route after %@ minutes. Open to call her."    [minutes]
//   PUSH_RISK_RESOLVED_TITLE       "%@ is safe"                                                 [callName]
//   PUSH_RISK_RESOLVED_HOME        "She is back home. The risk is resolved."                    []
//   PUSH_RISK_RESOLVED_MET         "You've met her. The risk is resolved."                      []
export type PushKind = 'riskLow' | 'riskHigh' | 'riskResolved';
const KIND: Partial<Record<ActionKind, PushKind>> = { notifyLow: 'riskLow', notifyHigh: 'riskHigh', notifyResolved: 'riskResolved' };

export function riskPush(action: ActionKind, details: Record<string, any>, riskEventId: string, callName: string): PushMessage {
  const kind = KIND[action];
  if (!kind) throw new Error(`${action} is not a caregiver notification`);
  const anomaly = details.anomaly === 'deviation' ? 'DEVIATION' : 'WANDERING';
  const minutes = String(details.minutes ?? '');
  let alert: Record<string, unknown>;
  if (kind === 'riskLow') {
    alert = { 'title-loc-key': 'PUSH_RISK_LOW_TITLE', 'title-loc-args': [callName],
      'loc-key': `PUSH_RISK_LOW_${anomaly}${details.navigation ? '_NAV' : ''}`, 'loc-args': [minutes] };
  } else if (kind === 'riskHigh') {
    alert = { 'title-loc-key': 'PUSH_RISK_HIGH_TITLE', 'title-loc-args': [callName], 'loc-key': `PUSH_RISK_HIGH_${anomaly}`, 'loc-args': [minutes] };
  } else {
    alert = { 'title-loc-key': 'PUSH_RISK_RESOLVED_TITLE', 'title-loc-args': [callName],
      'loc-key': details.resolution === 'met' ? 'PUSH_RISK_RESOLVED_MET' : 'PUSH_RISK_RESOLVED_HOME', 'loc-args': [] };
  }
  const timeSensitive = kind === 'riskHigh';
  const threadId = `risk-${riskEventId}`;
  return {
    payload: {
      aps: { alert, sound: 'default', 'interruption-level': timeSensitive ? 'time-sensitive' : 'active', 'thread-id': threadId },
      kind, riskEventId,
    },
    timeSensitive, threadId,
  };
}
