import { Module } from '@nestjs/common';
import { ChatQueries } from './chat-queries';
import { CareEvents } from './care-events';
import { CareStore } from './care-store';
import {
  DevicesController, LocationsController, OutreachController, RiskEventsController, SafeZonesController,
} from './controllers';
import { DatabaseService } from './database.service';
import { DeviceAuth } from './device-auth';
import { AccountController } from './account-controller';
import { AccountStore } from './account-store';
import { FamilyController } from './family-controller';
import { FamilyStore } from './family-store';
import { HealthController } from './health.controller';
import { Records } from './records';
import { RecordsController } from './records-controller';
import { RiskRecords } from './risk-records';

@Module({
  controllers: [AccountController, FamilyController, RecordsController, HealthController, DevicesController, SafeZonesController, LocationsController, RiskEventsController, OutreachController],
  providers: [AccountStore, FamilyStore, ChatQueries, Records, DatabaseService, CareStore, RiskRecords, CareEvents, DeviceAuth],
  exports: [ChatQueries, DeviceAuth, Records, CareStore, RiskRecords, CareEvents],
})
export class CareApiModule {}
