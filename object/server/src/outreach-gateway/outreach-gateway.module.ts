import { Module } from '@nestjs/common';
import { CareApiModule } from '../care-api/public';

@Module({ imports: [CareApiModule] })
export class OutreachGatewayModule {}
