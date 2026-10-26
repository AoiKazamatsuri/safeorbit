import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { CareEvents, CareStore, SafeZone, StoredFix, TripChange } from '../care-api/public';
import { DEMO_TRIP_PARAMS, Fix, initialState, step, tick, TrackerState, TripEvent } from './trip-recognition';

const CHUNK = 2000;
const CLOCK_CHECK_MS = 30_000;  // engineering architecture section 8: timed check every 30 s

const toFix = (p: StoredFix): Fix => ({ t: p.sampledAt.getTime(), latitude: p.latitude, longitude: p.longitude, accuracy: p.accuracy });
const toChange = (e: TripEvent): TripChange =>
  e.type === 'started' ? { type: 'started', startedAt: new Date(e.startedAt), startKnown: e.startKnown, stops: e.stops }
    : e.type === 'ended' ? { type: 'ended', endedAt: new Date(e.endedAt), stops: e.stops }
      : { type: 'stops', stops: e.stops };

// Runs trip recognition on stored fixes in sample-time order; one queue keeps runs from overlapping.
@Injectable()
export class TripTracker implements OnModuleInit, OnModuleDestroy {
  private queue: Promise<void> = Promise.resolve();
  private timer?: NodeJS.Timeout;

  constructor(private readonly store: CareStore, private readonly events: CareEvents) {}

  onModuleInit(): void {
    this.events.onLocationsStored(({ elderId }) => this.enqueue(() => this.processFixes(elderId)));
    this.timer = setInterval(() => void this.enqueue(() => this.checkClock(Date.now())), CLOCK_CHECK_MS);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    clearInterval(this.timer);
  }

  private enqueue(work: () => Promise<void>): Promise<void> {
    const run = this.queue.then(work);
    this.queue = run.catch(error => console.error('Trip tracking failed:', (error as Error).message));
    return run;
  }

  async processFixes(elderId: number): Promise<void> {
    const zones = await this.store.safeZones(elderId);
    const record = await this.store.tracker(elderId);
    let state = (record?.state as TrackerState | undefined) ?? initialState();
    let through = record?.processedThrough ?? null;
    for (;;) {
      const fixes = await this.store.pointsAfter(elderId, through, CHUNK);
      if (!fixes.length) return;
      const changes: TripChange[] = [];
      for (const fix of fixes) {
        const result = step(state, toFix(fix), zones, DEMO_TRIP_PARAMS);
        state = result.state;
        changes.push(...result.events.map(toChange));
      }
      through = fixes[fixes.length - 1].sampledAt;
      await this.store.recordTracking(elderId, changes, { phase: state.phase, processedThrough: through, state });
      if (fixes.length < CHUNK) return;
    }
  }

  async checkClock(now: number): Promise<void> {
    for (const elderId of await this.store.trackedElderIds()) {
      const record = await this.store.tracker(elderId);
      if (!record) continue;
      const zones: SafeZone[] = await this.store.safeZones(elderId);
      const result = tick(record.state as TrackerState, now, zones, DEMO_TRIP_PARAMS);
      if (!result.events.length) continue;
      await this.store.recordTracking(elderId, result.events.map(toChange),
        { phase: result.state.phase, processedThrough: record.processedThrough, state: result.state });
    }
  }
}
