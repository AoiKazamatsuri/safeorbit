import { Module } from '@nestjs/common';
import { CareApiModule } from '../care-api/public';
import { ApnsSender } from './apns-sender';
import { OutreachService } from './outreach.service';
import { PUSH_SENDER } from './push-sender';

@Module({
  imports: [CareApiModule],
  providers: [OutreachService, { provide: PUSH_SENDER, useFactory: () => ApnsSender.fromEnv() }],
})
export class OutreachGatewayModule {}
