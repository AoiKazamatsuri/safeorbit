import { BadRequestException, Body, Controller, Headers, HttpCode, HttpException, Post, ServiceUnavailableException } from '@nestjs/common';
import { DeviceAuth } from '../care-api/public';
import { ChatService } from './chat-service';
@Controller('v1/agent')
export class ChatController {
  constructor(private readonly auth: DeviceAuth, private readonly chat: ChatService) {}
  @Post('chat') @HttpCode(200)
  async answer(@Body() body: any, @Headers('authorization') authorization?: string) {
    try {
      const { elderId } = await this.auth.require(authorization, 'caregiver');
      if (!body || typeof body.question !== 'string' || !body.question.trim() || body.question.trim().length > 1000 || !['zh', 'en'].includes(body.language) || typeof body.allowTripHistory !== 'boolean') throw new BadRequestException('Invalid chat request');
      return await this.chat.answer(elderId, body.question.trim(), body.language, body.allowTripHistory);
    } catch (error) {
      if (error instanceof HttpException) throw error;
      throw new ServiceUnavailableException('Chat is temporarily unavailable');
    }
  }
}
