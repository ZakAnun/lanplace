import { BleGattSession } from '../domain/BleGattSession';
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
    return copy;
  }
}
