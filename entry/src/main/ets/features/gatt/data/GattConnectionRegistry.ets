import { BleGattSession } from '../domain/BleGattSession';
import { GattCharacteristicNode, GattServiceNode } from '../domain/GattProfile';
import { GattSessionPhase } from '../domain/GattSessionPhase';

export class GattConnectionRegistry {
  private static readonly sessions: Map<string, BleGattSession> = new Map();

  static get(deviceId: string): BleGattSession | null {
    const found: BleGattSession | undefined = GattConnectionRegistry.sessions.get(deviceId);
    if (found === undefined) {
      return null;
    }
    return GattConnectionRegistry.clone(found);
  }

  static register(session: BleGattSession): void {
    GattConnectionRegistry.sessions.set(session.deviceId, GattConnectionRegistry.clone(session));
  }

  static setPhase(deviceId: string, phase: GattSessionPhase): void {
    const found: BleGattSession | undefined = GattConnectionRegistry.sessions.get(deviceId);
    if (found === undefined) {
      return;
    }
    found.phase = phase;
  }

  static connectedDeviceIds(): string[] {
    const ids: string[] = [];
    GattConnectionRegistry.sessions.forEach((session: BleGattSession, deviceId: string) => {
      if (session.phase === 'Connected') {
        ids.push(deviceId);
      }
    });
    return ids;
  }

  static clear(): void {
    GattConnectionRegistry.sessions.clear();
  }

  private static clone(session: BleGattSession): BleGattSession {
    const copy: BleGattSession = {
      deviceId: session.deviceId,
      phase: session.phase
    };
    if (session.mtu !== undefined) {
      copy.mtu = session.mtu;
    }
    if (session.services !== undefined) {
      copy.services = session.services.slice();
    }
    if (session.profile !== undefined) {
      copy.profile = GattConnectionRegistry.cloneProfile(session.profile);
    }
    return copy;
  }

  private static cloneProfile(profile: GattServiceNode[]): GattServiceNode[] {
    const copy: GattServiceNode[] = [];
    for (let i = 0; i < profile.length; i++) {
      const chars: GattCharacteristicNode[] = [];
      const source: GattCharacteristicNode[] = profile[i].characteristics;
      for (let j = 0; j < source.length; j++) {
        const item: GattCharacteristicNode = source[j];
        const cloned: GattCharacteristicNode = {
          serviceUuid: item.serviceUuid,
          characteristicUuid: item.characteristicUuid,
          canRead: item.canRead,
          canWrite: item.canWrite,
          canWriteNoResponse: item.canWriteNoResponse,
          canNotify: item.canNotify,
          canIndicate: item.canIndicate
        };
        chars.push(cloned);
      }
      const node: GattServiceNode = {
        serviceUuid: profile[i].serviceUuid,
        characteristics: chars
      };
      copy.push(node);
    }
    return copy;
  }
}
