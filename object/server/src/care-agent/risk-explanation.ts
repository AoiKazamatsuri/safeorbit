import { RiskActivity, RiskEventRecord } from '../care-api/public';

// Event explanation in the agent's first-person voice (product design 3.6). A fixed template for now;
// sub-task four replaces it with the cloud LLM behind the same call. It describes behaviour only.
export function explainRisk(event: RiskEventRecord, activity: RiskActivity, callName: string): string {
  const parts: string[] = [];
  const first = activity.observations.find(o => o.key === event.key) ?? activity.observations[0];
  const f = first?.features ?? {};
  if (event.anomaly === 'wandering') {
    parts.push(f.pathMeters !== undefined
      ? `I noticed ${callName} walked about ${f.pathMeters} m in ${Math.round((f.windowSeconds ?? 300) / 60)} minutes but ended up only ${Math.max(f.netMeters ?? 0, 1)} m from where that stretch began, so I treated it as wandering.`
      : `I noticed ${callName} was walking in circles, so I treated it as wandering.`);
  } else {
    const far = f.maxDistanceMeters ?? f.distanceMeters;
    parts.push(`I noticed ${callName} stayed more than ${f.thresholdMeters ?? 80} m from her usual route for over 5 minutes${far ? ` (up to ${far} m)` : ''}, so I treated it as being off route.`);
  }
  const opened = activity.transitions.find(t => t.kind === 'opened');
  const escalated = activity.transitions.find(t => t.kind === 'escalated');
  const resolved = activity.transitions.find(t => t.kind === 'resolved');
  const navigation = activity.actions.filter(a => a.kind === 'startNavigation');
  const lastNavigation = navigation.at(-1);
  const low = activity.actions.find(a => a.kind === 'notifyLow');
  if (opened) {
    const help = [
      lastNavigation && lastNavigation.status !== 'skipped' ? 'asked her phone to start navigation home' : null,
      low && low.status !== 'skipped' ? 'notified you' : null,
    ].filter(Boolean);
    parts.push(`After ${opened.detail?.minutes ?? 7} minutes I raised a low risk${help.length === 2 ? `, ${help[0]} and ${help[1]}` : help.length ? ` and ${help[0]}` : ''}.`);
  }
  if (lastNavigation?.status === 'started') parts.push('Navigation home started on her phone.');
  else if (lastNavigation?.status === 'failed') parts.push('Navigation could not start on her phone.');
  else if (lastNavigation?.status === 'expired' || navigation.length > 1) parts.push('Her phone did not answer the navigation request in time, so I sent it again.');
  if (escalated) parts.push(`It kept going, so at ${escalated.detail?.minutes ?? 15} minutes I raised it to high risk and sent you an urgent alert.`);
  if (activity.calls.length) parts.push(activity.calls.length === 1 ? 'You called her.' : `You called her ${activity.calls.length} times.`);
  if (resolved) {
    parts.push(resolved.detail?.resolution === 'met'
      ? 'You confirmed you had met her, so I closed the risk.'
      : 'She got back home and stayed there for 3 minutes, so I closed the risk.');
  } else parts.push('I am still watching.');
  return parts.join(' ');
}
