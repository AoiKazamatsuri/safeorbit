import { Module } from '@nestjs/common';
import { CareApiModule } from '../care-api/public';
import { CareAgentRunner } from './care-agent.service';

@Module({ imports: [CareApiModule], providers: [CareAgentRunner] })
export class CareAgentModule {}
