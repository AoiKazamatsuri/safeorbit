import { Module } from '@nestjs/common';
import { CareEvents } from './care-events';
import { CareStore } from './care-store';
import {
  DevicesController, LocationsController, OutreachController, RiskEventsController, SafeZonesController,
} from './controllers';
import { DatabaseService } from './database.service';
import { DeviceAuth } from './device-auth';
import { HealthController } from './health.controller';
import { Records } from './records';
import { RecordsController } from './records-controller';
import { RiskRecords } from './risk-records';

@Module({
  controllers: [RecordsController, HealthController, DevicesController, SafeZonesController, LocationsController, RiskEventsController, OutreachController],
  providers: [Records, DatabaseService, CareStore, RiskRecords, CareEvents, DeviceAuth],
  exports: [Records, CareStore, RiskRecords, CareEvents],
})
export class CareApiModule {}
