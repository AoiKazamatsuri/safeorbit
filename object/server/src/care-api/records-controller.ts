import { BadRequestException, Controller, Get, Headers, HttpException, Param, Query, ServiceUnavailableException } from '@nestjs/common';
import { DeviceAuth } from './device-auth';
import { Records } from './records';
import { InputError } from './validation';

@Controller('v1')
export class RecordsController {
  constructor(private readonly records: Records, private readonly auth: DeviceAuth) {}

  @Get('records')
  async calendar(@Query('month') month?: string, @Query('week') week?: string, @Headers('authorization') authorization?: string) {
    return this.validated(async () => {
      const { elderId } = await this.auth.require(authorization, 'caregiver');
      return this.records.calendar(elderId, month, week);
    });
  }
  @Get('trends')
  async trends(@Query('month') month?: string, @Headers('authorization') authorization?: string) {
    return this.validated(async () => {
      const { elderId } = await this.auth.require(authorization, 'caregiver');
      return this.records.trends(elderId, month);
    });
  }
  @Get('trips/:id')
  async detail(@Param('id') id: string, @Headers('authorization') authorization?: string) {
    return this.validated(async () => {
      const { elderId } = await this.auth.require(authorization, 'caregiver');
      return this.records.detail(elderId, id);
    });
  }
  private async validated<T>(work: () => Promise<T>): Promise<T> {
    try { return await work(); } catch (error) {
      if (error instanceof InputError) throw new BadRequestException(error.message);
      if (error instanceof HttpException) throw error;
      throw new ServiceUnavailableException('Records are temporarily unavailable');
    }
  }
}
