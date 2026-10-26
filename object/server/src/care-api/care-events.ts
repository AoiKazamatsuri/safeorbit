import { Injectable } from '@nestjs/common';

// Event port owned by the care API; consumers subscribe, so the care API never imports them (C2 edge 7).
export interface LocationsStored { elderId: number }
type Handler = (event: LocationsStored) => Promise<void>;

@Injectable()
export class CareEvents {
  private readonly handlers: Handler[] = [];

  onLocationsStored(handler: Handler): void {
    this.handlers.push(handler);
  }

  // A failing subscriber must not fail the upload that stored the points.
  async publishLocationsStored(event: LocationsStored): Promise<void> {
    for (const handler of this.handlers) {
      try { await handler(event); } catch (error) { console.error('Location subscriber failed:', (error as Error).message); }
    }
  }
}
