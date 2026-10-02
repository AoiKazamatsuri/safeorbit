import { Module } from '@nestjs/common';
import { CareApiModule } from './care-api/public';
import { CareAgentModule } from './care-agent/care-agent.module';
import { OutreachGatewayModule } from './outreach-gateway/outreach-gateway.module';

@Module({ imports: [CareApiModule, CareAgentModule, OutreachGatewayModule] })
export class AppModule {}
