import {
  BadRequestException, Body, Controller, Delete, Get, Headers, HttpCode, NotFoundException, Param, Post, Put, Query,
} from '@nestjs/common';
import { CareEvents } from './care-events';
import { CareStore } from './care-store';
import { DeviceAuth } from './device-auth';
import { buildSnapshot, LocationSnapshot, tripName } from './location-view';
import { InputError, parseDeviceRegistration, parseLocationBatch, parseSafeZone } from './validation';

const TRAIL_LIMIT = 5000;
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
  constructor(private readonly store: CareStore, private readonly auth: DeviceAuth) {}

  @Get()
  async list(@Headers('authorization') authorization?: string) {
    return this.store.safeZones((await this.auth.require(authorization)).elderId);
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
  constructor(private readonly store: CareStore, private readonly auth: DeviceAuth, private readonly events: CareEvents) {}

  // Elder phone upload; pending actions ride on the reply (none until T38).
  @Post('locations') @HttpCode(200)
  async upload(@Body() body: unknown, @Headers('authorization') authorization?: string) {
    const device = await this.auth.require(authorization, 'elder');
    const statuses = await this.store.storePoints(device, parsed(() => parseLocationBatch(body)));
    if (statuses.includes('accepted')) await this.events.publishLocationsStored({ elderId: device.elderId });
    return { results: statuses.map((status, index) => ({ index, status })), actions: [] };
  }

  @Get('location')
  async current(@Headers('authorization') authorization?: string): Promise<LocationSnapshot> {
    const { elderId } = await this.auth.require(authorization, 'caregiver');
    const latest = await this.store.latestPoints(elderId, 2);
    if (!latest.length) throw new NotFoundException('No location has been reported yet');
    const [tracker, trip, zones, phone] = await Promise.all([
      this.store.tracker(elderId), this.store.activeTrip(elderId), this.store.safeZones(elderId), this.store.elderDevice(elderId),
    ]);
    return buildSnapshot({
      latest, phase: tracker?.phase ?? 'unknown', tripStops: trip?.stops ?? null,
      trail: trip ? await this.store.pointsSince(elderId, trip.startedAt, TRAIL_LIMIT) : [],
      zones, batteryPercent: phone?.batteryPercent ?? null,
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
