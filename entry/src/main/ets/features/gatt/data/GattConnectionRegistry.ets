import { BleGattSession } from '../domain/BleGattSession';
import { GattCharacteristicNode, GattServiceNode } from '../domain/GattProfile';
import { GattPhaseListener, GattSessionPhase } from '../domain/GattSessionPhase';

export class GattConnectionRegistry {
  private static readonly sessions: Map<string, BleGattSession> = new Map();
  private static readonly phaseListeners: GattPhaseListener[] = [];

  static get(deviceId: string): BleGattSession | null {
    const found: BleGattSession | undefined = GattConnectionRegistry.sessions.get(deviceId);
    if (found === undefined) {
      return null;
    }
    return GattConnectionRegistry.clone(found);
  }

  static register(session: BleGattSession): void {
    const stored: BleGattSession = GattConnectionRegistry.clone(session);
    GattConnectionRegistry.sessions.set(stored.deviceId, stored);
    GattConnectionRegistry.emitPhase(stored.deviceId, stored.phase);
  }

  static setPhase(deviceId: string, phase: GattSessionPhase): void {
    const found: BleGattSession | undefined = GattConnectionRegistry.sessions.get(deviceId);
    if (found === undefined) {
      return;
    }
    found.phase = phase;
    GattConnectionRegistry.emitPhase(deviceId, phase);
  }

  static subscribePhase(listener: GattPhaseListener): void {
    GattConnectionRegistry.phaseListeners.push(listener);
  }

  static unsubscribePhase(listener: GattPhaseListener): void {
    const next: GattPhaseListener[] = [];
    for (let i = 0; i < GattConnectionRegistry.phaseListeners.length; i++) {
      if (GattConnectionRegistry.phaseListeners[i] !== listener) {
        next.push(GattConnectionRegistry.phaseListeners[i]);
      }
    }
    GattConnectionRegistry.phaseListeners.length = 0;
    for (let i = 0; i < next.length; i++) {
      GattConnectionRegistry.phaseListeners.push(next[i]);
    }
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
    GattConnectionRegistry.phaseListeners.length = 0;
  }

  private static emitPhase(deviceId: string, phase: GattSessionPhase): void {
    const snapshot: GattPhaseListener[] = [];
    for (let i = 0; i < GattConnectionRegistry.phaseListeners.length; i++) {
      snapshot.push(GattConnectionRegistry.phaseListeners[i]);
    }
    for (let i = 0; i < snapshot.length; i++) {
      snapshot[i](deviceId, phase);
    }
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
