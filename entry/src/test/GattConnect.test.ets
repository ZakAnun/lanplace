import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { BleGattSession } from '../main/ets/features/gatt/domain/BleGattSession';
import {
  GATT_CONNECT_TIMEOUT_MS,
  GATT_ERROR_MAX_CONNECTIONS,
  GATT_ERROR_TIMEOUT,
  GattFacade,
  GattOperationError,
  gattErrorCode,
  gattFailureResource
} from '../main/ets/features/gatt/domain/GattFacade';
import { GattConnectionRegistry } from '../main/ets/features/gatt/data/GattConnectionRegistry';
import { DefaultGattFacade } from '../main/ets/features/gatt/data/DefaultGattFacade';
import { GattClock, IGattTransport, SystemGattClock } from '../main/ets/features/gatt/data/IGattTransport';
import { LogEvent, LogEventDomain } from '../main/ets/features/session-log/domain/LogEvent';
import { LogEventType } from '../main/ets/features/session-log/domain/LogEventType';
import { LogEventBus } from '../main/ets/features/session-log/domain/LogEventBus';
import { InMemoryLogStore } from '../main/ets/features/session-log/data/InMemoryLogStore';
import { resolveGattConnected } from '../main/ets/features/workbench/domain/WorkbenchShellState';

const DEVICE_ID: string = '11:22:33:44:55:66';
const SECOND_ID: string = 'AA:00:00:00:00:02';
const SERVICE_UUID: string = '0000180a-0000-1000-8000-00805f9b34fb';

type ClockFire = () => void;

class ManualGattClock implements GattClock {
  lastDelayMs: number = -1;
  timerCancelled: boolean = false;
  private pending: ClockFire | null = null;

  schedule(delayMs: number, onFire: ClockFire): number {
    this.lastDelayMs = delayMs;
    this.pending = onFire;
    this.timerCancelled = false;
    return 7;
  }

  cancel(_timerId: number): void {
    this.timerCancelled = true;
    this.pending = null;
  }

  fire(): void {
    const pending: ClockFire | null = this.pending;
    if (pending === null) {
      return;
    }
    this.pending = null;
    pending();
  }
}

class ScriptedGattTransport implements IGattTransport {
  mode: string;
  cancelled: boolean = false;
  disconnected: boolean = false;

  constructor(mode: string) {
    this.mode = mode;
  }

  connect(_deviceId: string): Promise<string[]> {
    if (this.mode === 'hang') {
      return new Promise<string[]>((_resolve: (value: string[]) => void): void => {
      });
    }
    if (this.mode === 'max') {
      return Promise.reject(new GattOperationError(GATT_ERROR_MAX_CONNECTIONS, 'max connections'));
    }
    const uuids: string[] = [SERVICE_UUID];
    return Promise.resolve(uuids);
  }

  disconnect(_deviceId: string): Promise<void> {
    this.disconnected = true;
    return Promise.resolve();
  }

  cancelConnect(_deviceId: string): void {
    this.cancelled = true;
  }
}

class BoundConnect {
  readonly transport: ScriptedGattTransport;
  readonly clock: ManualGattClock;
  readonly facade: DefaultGattFacade;

  constructor(mode: string) {
    this.transport = new ScriptedGattTransport(mode);
    this.clock = new ManualGattClock();
    this.facade = new DefaultGattFacade(this.transport, this.clock);
    GattFacade.bindFacade(this.facade);
  }
}

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, ms);
  });
}

function bleKey(deviceId: string): string {
  return `ble:${deviceId}`;
}

export default function gattConnectTest() {
  describe('GattConnect', () => {
    beforeEach(() => {
      GattConnectionRegistry.clear();
      LogEventBus.bindStore(new InMemoryLogStore());
      GattFacade.resetFacade();
    });

    it('timeoutConstantIsThirtySeconds', 0, () => {
      expect(GATT_CONNECT_TIMEOUT_MS).assertEqual(30000);
      expect(GATT_ERROR_TIMEOUT).assertEqual(-100);
    });

    it('maps2900006ToMaxConnectionsResource', 0, () => {
      expect(GATT_ERROR_MAX_CONNECTIONS).assertEqual(2900006);
      expect(gattFailureResource(2900006)).assertEqual('toast_gatt_max_connections');
      expect(gattFailureResource(GATT_ERROR_MAX_CONNECTIONS)).assertEqual('toast_gatt_max_connections');
      expect(gattFailureResource(2900099)).assertEqual('toast_action_failed');
      expect(gattFailureResource(GATT_ERROR_TIMEOUT)).assertEqual('toast_action_failed');
    });

    it('systemClockInvokesCallbackAfterDelay', 0, async (): Promise<void> => {
      const clock: SystemGattClock = new SystemGattClock();
      let fired: boolean = false;
      clock.schedule(20, (): void => {
        fired = true;
      });
      await delay(80);
      expect(fired).assertTrue();
    });

    it('systemClockCancelStopsPendingCallback', 0, async (): Promise<void> => {
      const clock: SystemGattClock = new SystemGattClock();
      let fired: boolean = false;
      const timerId: number = clock.schedule(20, (): void => {
        fired = true;
      });
      clock.cancel(timerId);
      await delay(80);
      expect(fired).assertFalse();
    });

    it('queryConnectedWhenRegistryPhaseIsConnected', 0, () => {
      GattConnectionRegistry.register({ deviceId: DEVICE_ID, phase: 'Connected' });
      const bound: BoundConnect = new BoundConnect('ok');
      expect(bound.facade.isConnected(DEVICE_ID)).assertTrue();
      expect(GattFacade.isConnected(DEVICE_ID)).assertTrue();
      expect(resolveGattConnected(bleKey(DEVICE_ID))).assertTrue();
      expect(resolveGattConnected('lan:host:192.168.1.8')).assertFalse();
      expect(resolveGattConnected('ble:')).assertFalse();
    });

    it('queryFalseWhileConnectingOrUnbound', 0, () => {
      GattConnectionRegistry.register({ deviceId: DEVICE_ID, phase: 'Connecting' });
      const bound: BoundConnect = new BoundConnect('ok');
      expect(bound.facade.isConnected(DEVICE_ID)).assertFalse();
      expect(resolveGattConnected(bleKey(DEVICE_ID))).assertFalse();
      GattFacade.resetFacade();
      GattConnectionRegistry.register({ deviceId: DEVICE_ID, phase: 'Connected' });
      expect(resolveGattConnected(bleKey(DEVICE_ID))).assertFalse();
    });

    it('connectRegistersConnectedAndAppendsGattConnect', 0, async (): Promise<void> => {
      const bound: BoundConnect = new BoundConnect('ok');
      await bound.facade.connect(DEVICE_ID);
      const found: BleGattSession | null = GattConnectionRegistry.get(DEVICE_ID);
      expect(found !== null).assertTrue();
      const session: BleGattSession = found as BleGattSession;
      expect(session.phase).assertEqual('Connected');
      expect(session.services !== undefined).assertTrue();
      const services: string[] = session.services as string[];
      expect(services.length).assertEqual(1);
      expect(services[0]).assertEqual(SERVICE_UUID);
      expect(bound.clock.timerCancelled).assertTrue();
      expect(bound.transport.cancelled).assertFalse();
      expect(GattFacade.isConnected(DEVICE_ID)).assertTrue();
      expect(resolveGattConnected(bleKey(DEVICE_ID))).assertTrue();
      const domainBle: LogEventDomain = 'ble';
      const logs: LogEvent[] = LogEventBus.query(bleKey(DEVICE_ID), domainBle);
      expect(logs.length).assertEqual(1);
      expect(logs[0].type).assertEqual(LogEventType.GATT_CONNECT);
      expect(logs[0].domain).assertEqual(domainBle);
      expect(logs[0].deviceKey).assertEqual(bleKey(DEVICE_ID));
      expect(logs[0].message).assertEqual('connected');
      expect(logs[0].ts > 0).assertTrue();
    });

    it('secondConnectKeepsFirstSession', 0, async (): Promise<void> => {
      const bound: BoundConnect = new BoundConnect('ok');
      await bound.facade.connect(DEVICE_ID);
      await bound.facade.connect(SECOND_ID);
      expect(GattFacade.isConnected(DEVICE_ID)).assertTrue();
      expect(GattFacade.isConnected(SECOND_ID)).assertTrue();
    });

    it('connectTimesOutAtThirtySecondsAndCancelsTransport', 0, async (): Promise<void> => {
      const bound: BoundConnect = new BoundConnect('hang');
      let failed: boolean = false;
      const pending: Promise<void> = bound.facade.connect(DEVICE_ID).then((): void => {
        return;
      }).catch((err: Object): void => {
        failed = true;
        expect(gattErrorCode(err)).assertEqual(GATT_ERROR_TIMEOUT);
      });
      expect(bound.clock.lastDelayMs).assertEqual(30000);
      expect(GattFacade.isConnected(DEVICE_ID)).assertFalse();
      bound.clock.fire();
      await pending;
      expect(failed).assertTrue();
      expect(bound.transport.cancelled).assertTrue();
      expect(GattFacade.isConnected(DEVICE_ID)).assertFalse();
      const found: BleGattSession | null = GattConnectionRegistry.get(DEVICE_ID);
      expect(found !== null).assertTrue();
      expect((found as BleGattSession).phase).assertEqual('Disconnected');
      const domainBle: LogEventDomain = 'ble';
      const logs: LogEvent[] = LogEventBus.query(bleKey(DEVICE_ID), domainBle);
      expect(logs.length).assertEqual(1);
      expect(logs[0].type).assertEqual(LogEventType.GATT_ERROR);
      expect(logs[0].domain).assertEqual(domainBle);
    });

    it('connect2900006RejectsWithoutConnectedPhase', 0, async (): Promise<void> => {
      const bound: BoundConnect = new BoundConnect('max');
      let failed: boolean = false;
      try {
        await bound.facade.connect(DEVICE_ID);
      } catch (err) {
        failed = true;
        const code: number = gattErrorCode(err as Object);
        expect(code).assertEqual(2900006);
        expect(gattFailureResource(code)).assertEqual('toast_gatt_max_connections');
      }
      expect(failed).assertTrue();
      expect(bound.transport.cancelled).assertFalse();
      expect(GattFacade.isConnected(DEVICE_ID)).assertFalse();
      const domainBle: LogEventDomain = 'ble';
      const logs: LogEvent[] = LogEventBus.query(bleKey(DEVICE_ID), domainBle);
      let connectLogs: number = 0;
      for (let i = 0; i < logs.length; i++) {
        if (logs[i].type === LogEventType.GATT_CONNECT) {
          connectLogs++;
        }
      }
      expect(connectLogs).assertEqual(0);
      expect(logs.length).assertEqual(1);
      expect(logs[0].type).assertEqual(LogEventType.GATT_ERROR);
    });

    it('disconnectClearsConnectedPhaseAndAppendsGattDisconnect', 0, async (): Promise<void> => {
      const bound: BoundConnect = new BoundConnect('ok');
      GattConnectionRegistry.register({ deviceId: DEVICE_ID, phase: 'Connected' });
      await bound.facade.disconnect(DEVICE_ID);
      expect(bound.transport.disconnected).assertTrue();
      const found: BleGattSession | null = GattConnectionRegistry.get(DEVICE_ID);
      expect(found !== null).assertTrue();
      expect((found as BleGattSession).phase).assertEqual('Disconnected');
      expect(GattFacade.isConnected(DEVICE_ID)).assertFalse();
      const domainBle: LogEventDomain = 'ble';
      const logs: LogEvent[] = LogEventBus.query(bleKey(DEVICE_ID), domainBle);
      expect(logs.length).assertEqual(1);
      expect(logs[0].type).assertEqual(LogEventType.GATT_DISCONNECT);
      expect(logs[0].domain).assertEqual(domainBle);
      expect(logs[0].message).assertEqual('disconnected');
    });
  });
}
