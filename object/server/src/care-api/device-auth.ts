import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { CareStore, Device } from './care-store';
import { DeviceRole } from './validation';

// No accounts in the Demo (T37): a phone registers its role once and sends the device token as a bearer token.
@Injectable()
export class DeviceAuth {
  constructor(private readonly store: CareStore) {}

  async require(authorization: string | undefined, role?: DeviceRole): Promise<Device> {
    const token = /^Bearer (\S+)$/.exec(authorization ?? '')?.[1];
    const device = token ? await this.store.deviceByToken(token) : null;
    if (!device) throw new UnauthorizedException('Register this phone first');
    if (role && device.role !== role) throw new ForbiddenException(`Only the ${role} phone can do this`);
    return device;
  }
}
