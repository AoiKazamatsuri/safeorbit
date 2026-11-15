import { Body, Controller, Delete, Headers, HttpCode, Post, Req, UnauthorizedException } from '@nestjs/common';
import { AccountStore, parseAccount } from './account-store';

@Controller('v1/account')
export class AccountController {
  constructor(private readonly accounts: AccountStore) {}
  @Post('register') @HttpCode(200)
  async register(@Body() body: unknown, @Headers('authorization') authorization?: string, @Req() request?: { ip?: string }) {
    const input = parseAccount(body, true);
    this.accounts.limit(input.email, request?.ip ?? 'local');
    const legacy = authorization === undefined ? undefined : /^Bearer (\S+)$/.exec(authorization)?.[1];
    if (authorization !== undefined && !legacy) throw new UnauthorizedException('Invalid previous family session');
    return this.accounts.register(input, legacy);
  }
  @Post('login') @HttpCode(200)
  async login(@Body() body: unknown, @Req() request?: { ip?: string }) {
    const input = parseAccount(body);
    this.accounts.limit(input.email, request?.ip ?? 'local');
    return this.accounts.login(input);
  }
  @Post('session') @HttpCode(200)
  async session(@Headers('authorization') authorization?: string) { return this.accounts.response(await this.accounts.require(authorization)); }
  @Delete('session') @HttpCode(204)
  async logout(@Headers('authorization') authorization?: string) { await this.accounts.logout(await this.accounts.require(authorization)); }
}
