import { Module } from '@nestjs/common';
import { CareEvents } from './care-events';
import { CareStore } from './care-store';
import {
  DevicesController, LocationsController, OutreachController, RiskEventsController, SafeZonesController,
} from './controllers';
import { DatabaseService } from './database.service';
import { DeviceAuth } from './device-auth';
import { HealthController } from './health.controller';
import { RiskRecords } from './risk-records';

@Module({
  controllers: [HealthController, DevicesController, SafeZonesController, LocationsController, RiskEventsController, OutreachController],
  providers: [DatabaseService, CareStore, RiskRecords, CareEvents, DeviceAuth],
  exports: [CareStore, RiskRecords, CareEvents],
})
export class CareApiModule {}
