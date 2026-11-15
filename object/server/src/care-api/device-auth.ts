import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { CareStore, Device } from './care-store';
import { DeviceRole } from './validation';

// Resolve role and household only from an active server-side credential.
@Injectable()
export class DeviceAuth {
  constructor(private readonly store: CareStore) {}

  async require(authorization: string | undefined, role?: DeviceRole, allowLegacyCaregiver = false): Promise<Device> {
    const token = /^Bearer (\S+)$/.exec(authorization ?? '')?.[1];
    const device = token ? await this.store.deviceByToken(token) : null;
    if (!device) throw new UnauthorizedException('Join a family before using this phone');
    if (device.role === 'caregiver' && !device.isDemo && !device.accountSessionId && !allowLegacyCaregiver) {
      throw new UnauthorizedException('Create an account to restore this family membership');
    }
    if (role && device.role !== role) throw new ForbiddenException(`Only the ${role} phone can do this`);
    return device;
  }
}
