import { Module } from '@nestjs/common';
import { CareApiModule } from '../care-api/public';
import { ChatController } from './chat-controller';
import { ChatService } from './chat-service';
import { LanguageModel } from './language-model';
import { CareAgentRunner } from './care-agent.service';

@Module({ imports: [CareApiModule], controllers: [ChatController], providers: [CareAgentRunner, ChatService, LanguageModel] })
export class CareAgentModule {}
