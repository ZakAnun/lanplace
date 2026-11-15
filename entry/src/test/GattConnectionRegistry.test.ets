import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { BleGattSession, GATT_MAX_WRITE_QUEUE } from '../main/ets/features/gatt/domain/BleGattSession';
import { GattSessionPhase } from '../main/ets/features/gatt/domain/GattSessionPhase';
import { GattConnectionRegistry } from '../main/ets/features/gatt/data/GattConnectionRegistry';

function sessionOf(deviceId: string, phase: GattSessionPhase, mtu?: number, services?: string[]): BleGattSession {
  const session: BleGattSession = {
    deviceId: deviceId,
    phase: phase
  };
  if (mtu !== undefined) {
    session.mtu = mtu;
  }
  if (services !== undefined) {
    session.services = services.slice();
  }
  return session;
}

function containsId(ids: string[], deviceId: string): boolean {
  return ids.indexOf(deviceId) >= 0;
}

export default function gattConnectionRegistryTest() {
  describe('GattConnectionRegistry', () => {
    beforeEach(() => {
      GattConnectionRegistry.clear();
    });

    it('writeQueueConstantIsOne', 0, () => {
      expect(GATT_MAX_WRITE_QUEUE).assertEqual(1);
    });

    it('getUnknownDeviceIdReturnsNull', 0, () => {
      expect(GattConnectionRegistry.get('AA:BB:CC:DD:EE:FF') === null).assertTrue();
    });

    it('registerThenGetReturnsSameDeviceIdAndPhase', 0, () => {
      const phase: GattSessionPhase = 'Connecting';
      GattConnectionRegistry.register(sessionOf('11:22:33:44:55:66', phase));
      const found: BleGattSession | null = GattConnectionRegistry.get('11:22:33:44:55:66');
      expect(found !== null).assertTrue();
      const session: BleGattSession = found as BleGattSession;
      expect(session.deviceId).assertEqual('11:22:33:44:55:66');
      expect(session.phase).assertEqual(phase);
    });

    it('multipleDeviceIdsCoexistInRegistry', 0, () => {
      GattConnectionRegistry.register(sessionOf('AA:00:00:00:00:01', 'Connecting'));
      GattConnectionRegistry.register(sessionOf('AA:00:00:00:00:02', 'Disconnected'));
      const first: BleGattSession | null = GattConnectionRegistry.get('AA:00:00:00:00:01');
      const second: BleGattSession | null = GattConnectionRegistry.get('AA:00:00:00:00:02');
      expect(first !== null).assertTrue();
      expect(second !== null).assertTrue();
      expect((first as BleGattSession).phase).assertEqual('Connecting');
      expect((second as BleGattSession).phase).assertEqual('Disconnected');
    });

    it('registerSameDeviceIdReplacesSession', 0, () => {
      GattConnectionRegistry.register(sessionOf('BB:00:00:00:00:01', 'Connecting', 23));
      GattConnectionRegistry.register(sessionOf('BB:00:00:00:00:01', 'Connected', 185));
      const found: BleGattSession | null = GattConnectionRegistry.get('BB:00:00:00:00:01');
      expect(found !== null).assertTrue();
      const session: BleGattSession = found as BleGattSession;
      expect(session.phase).assertEqual('Connected');
      expect(session.mtu).assertEqual(185);
    });

    it('setPhaseUpdatesExistingSession', 0, () => {
      GattConnectionRegistry.register(sessionOf('CC:00:00:00:00:01', 'Connecting'));
      GattConnectionRegistry.setPhase('CC:00:00:00:00:01', 'Connected');
      const found: BleGattSession | null = GattConnectionRegistry.get('CC:00:00:00:00:01');
      expect(found !== null).assertTrue();
      expect((found as BleGattSession).phase).assertEqual('Connected');
    });

    it('setPhasePreservesMtuAndServices', 0, () => {
      const uuids: string[] = ['0000180a-0000-1000-8000-00805f9b34fb'];
      GattConnectionRegistry.register(sessionOf('CC:00:00:00:00:02', 'Connecting', 247, uuids));
      GattConnectionRegistry.setPhase('CC:00:00:00:00:02', 'Lost');
      const found: BleGattSession | null = GattConnectionRegistry.get('CC:00:00:00:00:02');
      expect(found !== null).assertTrue();
      const session: BleGattSession = found as BleGattSession;
      expect(session.phase).assertEqual('Lost');
      expect(session.mtu).assertEqual(247);
      expect(session.services !== undefined).assertTrue();
      expect((session.services as string[]).length).assertEqual(1);
      expect((session.services as string[])[0]).assertEqual('0000180a-0000-1000-8000-00805f9b34fb');
    });

    it('setPhaseOnUnknownDeviceIdIsNoOp', 0, () => {
      GattConnectionRegistry.setPhase('00:00:00:00:00:00', 'Connected');
      expect(GattConnectionRegistry.get('00:00:00:00:00:00') === null).assertTrue();
      expect(GattConnectionRegistry.connectedDeviceIds().length).assertEqual(0);
    });

    it('connectedDeviceIdsReturnsOnlyConnectedPhase', 0, () => {
      GattConnectionRegistry.register(sessionOf('DD:00:00:00:00:01', 'Connected'));
      GattConnectionRegistry.register(sessionOf('DD:00:00:00:00:02', 'Connecting'));
      GattConnectionRegistry.register(sessionOf('DD:00:00:00:00:03', 'Disconnected'));
      GattConnectionRegistry.register(sessionOf('DD:00:00:00:00:04', 'Lost'));
      const ids: string[] = GattConnectionRegistry.connectedDeviceIds();
      expect(ids.length).assertEqual(1);
      expect(ids[0]).assertEqual('DD:00:00:00:00:01');
    });

    it('connectedDeviceIdsAllowsMultipleConnectedSessions', 0, () => {
      GattConnectionRegistry.register(sessionOf('EE:00:00:00:00:01', 'Connected'));
      GattConnectionRegistry.register(sessionOf('EE:00:00:00:00:02', 'Connected'));
      GattConnectionRegistry.register(sessionOf('EE:00:00:00:00:03', 'Connecting'));
      const ids: string[] = GattConnectionRegistry.connectedDeviceIds();
      expect(ids.length).assertEqual(2);
      expect(containsId(ids, 'EE:00:00:00:00:01')).assertTrue();
      expect(containsId(ids, 'EE:00:00:00:00:02')).assertTrue();
      expect(containsId(ids, 'EE:00:00:00:00:03')).assertFalse();
    });

    it('setPhaseConnectedAddsDeviceToConnectedIds', 0, () => {
      GattConnectionRegistry.register(sessionOf('FF:00:00:00:00:01', 'Connecting'));
      expect(GattConnectionRegistry.connectedDeviceIds().length).assertEqual(0);
      GattConnectionRegistry.setPhase('FF:00:00:00:00:01', 'Connected');
      const ids: string[] = GattConnectionRegistry.connectedDeviceIds();
      expect(ids.length).assertEqual(1);
      expect(ids[0]).assertEqual('FF:00:00:00:00:01');
    });
  });
}
