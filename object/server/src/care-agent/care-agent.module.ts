import { Module } from '@nestjs/common';
import { CareApiModule } from '../care-api/public';
import { TripTracker } from './trip-tracker.service';

@Module({ imports: [CareApiModule], providers: [TripTracker] })
export class CareAgentModule {}
