import { Injectable } from '@nestjs/common';

// Event port owned by the care API; consumers subscribe, so the care API never imports them (C2 edges 7, 10).
export interface LocationsStored { elderId: number; replay?: boolean }
export interface DispositionSubmitted { elderId: number; riskEventId: string; kind: 'met' | 'falseAlarm' }
export type StateChangeType = 'snapshot' | 'risk' | 'action';
export interface StateChanged { elderId: number; seq: number; type: StateChangeType }
type Handler<T> = (event: T) => Promise<void>;

@Injectable()
export class CareEvents {
  private readonly locations: Handler<LocationsStored>[] = [];
  private readonly dispositions: Handler<DispositionSubmitted>[] = [];
  private readonly states: Handler<StateChanged>[] = [];

  onLocationsStored(handler: Handler<LocationsStored>): void { this.locations.push(handler); }
  onDispositionSubmitted(handler: Handler<DispositionSubmitted>): void { this.dispositions.push(handler); }
  onStateChanged(handler: Handler<StateChanged>): void { this.states.push(handler); }

  // Awaited: the upload reply carries actions decided from the points it stored.
  // A failing subscriber must not fail the upload that stored the points.
  async publishLocationsStored(event: LocationsStored): Promise<void> {
    if (event.replay) {
      for (const handler of this.locations) await handler(event);
    } else await deliver(this.locations, event, 'Location');
  }

  // Awaited: "We've Met" answers once the care agent has written the resolution.
  async publishDispositionSubmitted(event: DispositionSubmitted): Promise<void> {
    await deliver(this.dispositions, event, 'Disposition');
  }

  // Not awaited by writers: sending notifications must never hold up the care agent or an HTTP reply.
  publishStateChanged(event: StateChanged): void {
    setImmediate(() => void deliver(this.states, event, 'State change'));
  }
}

async function deliver<T>(handlers: Handler<T>[], event: T, label: string): Promise<void> {
  for (const handler of handlers) {
    try { await handler(event); } catch (error) { console.error(`${label} subscriber failed:`, (error as Error).message); }
  }
}
