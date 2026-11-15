import { BadRequestException, Body, Controller, Delete, Get, Headers, HttpCode, Param, Post, Put } from '@nestjs/common';
import { DeviceAuth } from './device-auth';
import { FamilyStore } from './family-store';
import { parseCreateFamily, parseJoinFamily, parsePushToken } from './family-validation';
import { InputError } from './validation';

function parsed<T>(work: () => T): T {
  try { return work(); } catch (error) {
    if (error instanceof InputError) throw new BadRequestException(error.message);
    throw error;
  }
}
@Controller('v1/family')
export class FamilyController {
  constructor(private readonly store: FamilyStore, private readonly auth: DeviceAuth) {}
  @Post() @HttpCode(200)
  create(@Body() body: unknown) { return this.store.create(parsed(() => parseCreateFamily(body))); }
  @Post('join') @HttpCode(200)
  join(@Body() body: unknown) { return this.store.join(parsed(() => parseJoinFamily(body))); }
  @Get('session')
  async session(@Headers('authorization') authorization?: string) { return this.store.session(await this.auth.require(authorization)); }
  @Get('members')
  async members(@Headers('authorization') authorization?: string) { return this.store.members(await this.auth.require(authorization, 'caregiver')); }
  @Delete('membership') @HttpCode(204)
  async leave(@Headers('authorization') authorization?: string) { await this.store.leave(await this.auth.require(authorization)); }
  @Delete('members/:id') @HttpCode(204)
  async remove(@Param('id') id: string, @Headers('authorization') authorization?: string) {
    await this.store.remove(await this.auth.require(authorization, 'caregiver'), id);
  }
  @Delete() @HttpCode(204)
  async delete(@Headers('authorization') authorization?: string) { await this.store.delete(await this.auth.require(authorization, 'caregiver')); }
  @Put('push-token') @HttpCode(204)
  async pushToken(@Body() body: unknown, @Headers('authorization') authorization?: string) {
    const device = await this.auth.require(authorization);
    await this.store.pushToken(device, parsed(() => parsePushToken(body)));
  }
}
