import {
  BadRequestException, Body, Controller, Delete, Get, Headers, HttpCode, NotFoundException, Param, Post, Put, Query,
  ServiceUnavailableException,
} from '@nestjs/common';
import { CareEvents } from './care-events';
import { CareStore } from './care-store';
import { DeviceAuth } from './device-auth';
import { buildSnapshot, LocationSnapshot, tripName } from './location-view';
import { RiskEventRecord, RiskRecords } from './risk-records';
import { buildRiskDetail, RiskEventDetail, riskSummary } from './risk-view';
import {
  InputError, parseActionResult, parseCallRecord, parseDeviceRegistration, parseLocationBatch, parseReferenceRoute,
  parseSafeZone, parseSettings,
} from './validation';

const TRAIL_LIMIT = 5000;
// A resolved risk event stays linked from the location snapshot this long (server time of its last change),
// so the caregiver can still open it from the person card and mark it as a false alarm.
export const RESOLVED_EVENT_WINDOW_SECONDS = 30 * 60;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function parsed<T>(parse: () => T): T {
  try { return parse(); } catch (error) {
    if (error instanceof InputError) throw new BadRequestException(error.message);
    throw error;
  }
}
function zoneId(id: string): string {
  if (!UUID.test(id)) throw new NotFoundException('Safe zone not found');
  return id;
}

@Controller('v1')
export class DevicesController {
  constructor(private readonly store: CareStore, private readonly auth: DeviceAuth) {}

  @Post('devices') @HttpCode(200)
  async register(@Body() body: unknown) {
    const { token, device } = await this.store.registerDevice(parsed(() => parseDeviceRegistration(body)));
    return { deviceToken: token, role: device.role, household: await this.store.household(device.elderId) };
  }

  @Get('household')
  async household(@Headers('authorization') authorization?: string) {
    return this.store.household((await this.auth.require(authorization)).elderId);
  }
}

@Controller('v1/safe-zones')
export class SafeZonesController {
  constructor(private readonly store: CareStore, private readonly risks: RiskRecords, private readonly auth: DeviceAuth) {}

  @Get()
  async list(@Headers('authorization') authorization?: string) {
    const { elderId } = await this.auth.require(authorization);
    const [zones, routed] = await Promise.all([this.store.safeZones(elderId), this.risks.zonesWithRoute(elderId)]);
    return zones.map(z => ({ ...z, hasReferenceRoute: routed.has(z.id) }));
  }

  // Planned walking route from home to this zone (WGS-84), replacing any earlier one.
  @Put(':id/route')
  async uploadRoute(@Param('id') id: string, @Body() body: unknown, @Headers('authorization') authorization?: string) {
    const device = await this.auth.require(authorization, 'caregiver');
    return this.risks.saveReferenceRoute(device.elderId, zoneId(id), parsed(() => parseReferenceRoute(body)));
  }

  @Post()
  async create(@Body() body: unknown, @Headers('authorization') authorization?: string) {
    const device = await this.auth.require(authorization, 'caregiver');
    return this.store.createSafeZone(device.elderId, parsed(() => parseSafeZone(body)));
  }

  @Put(':id')
  async update(@Param('id') id: string, @Body() body: unknown, @Headers('authorization') authorization?: string) {
    const device = await this.auth.require(authorization, 'caregiver');
    return this.store.updateSafeZone(device.elderId, zoneId(id), parsed(() => parseSafeZone(body)));
  }

  @Delete(':id') @HttpCode(204)
  async remove(@Param('id') id: string, @Headers('authorization') authorization?: string) {
    const device = await this.auth.require(authorization, 'caregiver');
    await this.store.deleteSafeZone(device.elderId, zoneId(id));
  }
}

@Controller('v1')
export class LocationsController {
  constructor(private readonly store: CareStore, private readonly risks: RiskRecords, private readonly auth: DeviceAuth,
    private readonly events: CareEvents) {}

  // Elder phone upload. The care agent evaluates the stored points before the reply, so the reply already
  // carries any action decided from them (pending actions for this phone, e.g. startNavigation).
  @Post('locations') @HttpCode(200)
  async upload(@Body() body: unknown, @Headers('authorization') authorization?: string, @Query('replay') replay?: string) {
    const device = await this.auth.require(authorization, 'elder');
    if (replay !== undefined && replay !== 'true' && replay !== 'false') throw new BadRequestException('replay must be true or false');
    const historical = replay === 'true';
    const now = Date.now();
    const batch = parsed(() => parseLocationBatch(body, now));
    if (historical && batch.points.some(p => p && p.sampledAt.getTime() >= now)) {
      throw new BadRequestException('Historical points must be in the past');
    }
    const statuses = await this.store.storePoints(device, batch, historical);
    if (historical || statuses.includes('accepted')) await this.events.publishLocationsStored({ elderId: device.elderId, replay: historical });
    return { results: statuses.map((status, index) => ({ index, status })), actions: historical ? [] : await this.risks.elderActions(device.elderId) };
  }

  @Get('location')
  async current(@Headers('authorization') authorization?: string): Promise<LocationSnapshot> {
    const { elderId } = await this.auth.require(authorization, 'caregiver');
    const latest = await this.store.latestPoints(elderId, 2);
    if (!latest.length) throw new NotFoundException('No location has been reported yet');
    const [tracker, trip, zones, phone, risk, riskFreeTrips] = await Promise.all([
      this.store.tracker(elderId), this.store.activeTrip(elderId), this.store.safeZones(elderId), this.store.elderDevice(elderId),
      this.risks.currentRiskEvent(elderId, RESOLVED_EVENT_WINDOW_SECONDS), this.risks.riskFreeTripCount(elderId),
    ]);
    return buildSnapshot({
      latest, phase: tracker?.phase ?? 'unknown', tripStops: trip?.stops ?? null,
      trail: trip ? await this.store.pointsSince(elderId, trip.startedAt, TRAIL_LIMIT) : [],
      zones, batteryPercent: phone?.batteryPercent ?? null, risk, riskFreeTrips, now: new Date(),
    });
  }

  @Get('trips')
  async trips(@Query('limit') limit?: string, @Headers('authorization') authorization?: string) {
    const { elderId } = await this.auth.require(authorization, 'caregiver');
    const count = Math.min(Math.max(Number.parseInt(limit ?? '20', 10) || 20, 1), 100);
    return (await this.store.trips(elderId, count)).map(t => ({
      id: t.id, name: tripName(t.stops), stops: t.stops, startKnown: t.startKnown,
      startedAt: t.startedAt.toISOString(), endedAt: t.endedAt?.toISOString() ?? null,
    }));
  }
}

@Controller('v1/risk-events')
export class RiskEventsController {
  constructor(private readonly store: CareStore, private readonly risks: RiskRecords, private readonly auth: DeviceAuth,
    private readonly events: CareEvents) {}

  @Get()
  async list(@Query('limit') limit?: string, @Headers('authorization') authorization?: string) {
    const { elderId } = await this.auth.require(authorization, 'caregiver');
    const count = Math.min(Math.max(Number.parseInt(limit ?? '20', 10) || 20, 1), 100);
    return (await this.risks.riskEvents(elderId, count)).map(riskSummary);
  }

  @Get(':id')
  async detail(@Param('id') id: string, @Headers('authorization') authorization?: string): Promise<RiskEventDetail> {
    const { elderId } = await this.auth.require(authorization, 'caregiver');
    return this.view(elderId, await this.risks.riskEvent(elderId, id));
  }

  // "We've Met": resolves at once, also while the elder phone is offline. The care agent writes the resolution.
  @Post(':id/met') @HttpCode(200)
  async met(@Param('id') id: string, @Headers('authorization') authorization?: string): Promise<RiskEventDetail> {
    const device = await this.auth.require(authorization, 'caregiver');
    const event = await this.risks.submitMet(device.elderId, id, device.id);
    await this.events.publishDispositionSubmitted({ elderId: device.elderId, riskEventId: event.id, kind: 'met' });
    const after = await this.risks.riskEvent(device.elderId, event.id);
    if (after.status !== 'resolved') throw new ServiceUnavailableException('The risk could not be resolved; try again');
    return this.view(device.elderId, after);
  }

  // Only after the risk is resolved (409 before). Marking twice is harmless.
  @Post(':id/false-alarm') @HttpCode(200)
  async falseAlarm(@Param('id') id: string, @Headers('authorization') authorization?: string): Promise<RiskEventDetail> {
    const device = await this.auth.require(authorization, 'caregiver');
    const { event, changed } = await this.risks.markFalseAlarm(device.elderId, id, device.id);
    if (changed) await this.events.publishDispositionSubmitted({ elderId: device.elderId, riskEventId: event.id, kind: 'falseAlarm' });
    return this.view(device.elderId, event);
  }

  private async view(elderId: number, event: RiskEventRecord): Promise<RiskEventDetail> {
    const trip = event.tripId ? await this.store.trip(elderId, event.tripId) : null;
    const from = trip?.startedAt ?? new Date(event.anomalyStartedAt.getTime() - 5 * 60_000);
    const to = trip ? trip.endedAt : event.resolvedAt;
    const [activity, trail, [latest]] = await Promise.all([
      this.risks.activity(event.id), this.store.pointsBetween(elderId, from, to, TRAIL_LIMIT), this.store.latestPoints(elderId, 1),
    ]);
    return buildRiskDetail({ event, activity, latest: latest ?? null, trail });
  }
}

@Controller('v1')
export class OutreachController {
  constructor(private readonly risks: RiskRecords, private readonly auth: DeviceAuth) {}

  // Elder phone's answer to an action from an upload reply.
  @Post('actions/:id/result') @HttpCode(200)
  async actionResult(@Param('id') id: string, @Body() body: unknown, @Headers('authorization') authorization?: string) {
    const device = await this.auth.require(authorization, 'elder');
    const { result, reason } = parsed(() => parseActionResult(body));
    return this.risks.recordActionResult(device.elderId, id, result, reason);
  }

  // "Call" pressed on the caregiver phone; linked to the given risk event, else to the active one.
  @Post('calls') @HttpCode(201)
  async call(@Body() body: unknown, @Headers('authorization') authorization?: string) {
    const device = await this.auth.require(authorization, 'caregiver');
    return this.risks.recordCall(device.elderId, device.id, parsed(() => parseCallRecord(body)).riskEventId);
  }

  @Get('caregiver-settings')
  async settings(@Headers('authorization') authorization?: string) {
    return this.risks.settings((await this.auth.require(authorization, 'caregiver')).elderId);
  }

  @Put('caregiver-settings')
  async saveSettings(@Body() body: unknown, @Headers('authorization') authorization?: string) {
    const device = await this.auth.require(authorization, 'caregiver');
    return this.risks.saveSettings(device.elderId, parsed(() => parseSettings(body)));
  }
}
