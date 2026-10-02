import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { DatabaseService } from './database.service';

@Controller('health')
export class HealthController {
  constructor(private readonly database: DatabaseService) {}

  @Get()
  health(): { status: string } {
    return { status: 'ok' };
  }

  @Get('ready')
  async ready(): Promise<{ status: string; database: string }> {
    try {
      await this.database.check();
      return { status: 'ok', database: 'postgis' };
    } catch {
      throw new ServiceUnavailableException('Database is not ready');
    }
  }
}
