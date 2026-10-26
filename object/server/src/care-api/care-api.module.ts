import { Module } from '@nestjs/common';
import { CareEvents } from './care-events';
import { CareStore } from './care-store';
import { DevicesController, LocationsController, SafeZonesController } from './controllers';
import { DatabaseService } from './database.service';
import { DeviceAuth } from './device-auth';
import { HealthController } from './health.controller';

@Module({
  controllers: [HealthController, DevicesController, SafeZonesController, LocationsController],
  providers: [DatabaseService, CareStore, CareEvents, DeviceAuth],
  exports: [CareStore, CareEvents],
})
export class CareApiModule {}
