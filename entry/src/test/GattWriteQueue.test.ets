import { describe, it, expect } from '@ohos/hypium';
import { GATT_MAX_WRITE_QUEUE } from '../main/ets/features/gatt/domain/BleGattSession';
import { GattWriteQueue } from '../main/ets/features/gatt/domain/GattWriteQueue';

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, ms);
  });
}

export default function gattWriteQueueTest() {
  describe('GattWriteQueue', () => {
    it('runsOneWriteAtATime', 0, async (): Promise<void> => {
      const queue: GattWriteQueue = new GattWriteQueue();
      let started: number = 0;
      let releaseFirst: () => void = (): void => {
      };
      const first: Promise<void> = queue.enqueue((): Promise<void> => {
        started++;
        return new Promise<void>((resolve: () => void): void => {
          releaseFirst = resolve;
        });
      });
      const second: Promise<void> = queue.enqueue((): Promise<void> => {
        started++;
        return Promise.resolve();
      });
      await delay(20);
      expect(started).assertEqual(GATT_MAX_WRITE_QUEUE);
      expect(queue.inFlight()).assertEqual(GATT_MAX_WRITE_QUEUE);
      releaseFirst();
      await first;
      await second;
      expect(started).assertEqual(2);
      expect(queue.inFlight()).assertEqual(0);
    });

    it('continuesQueueAfterWriteFailure', 0, async (): Promise<void> => {
      const queue: GattWriteQueue = new GattWriteQueue();
      let secondStarted: boolean = false;
      const first: Promise<void> = queue.enqueue((): Promise<void> => {
        return Promise.reject(new Error('write failed'));
      });
      const second: Promise<void> = queue.enqueue((): Promise<void> => {
        secondStarted = true;
        return Promise.resolve();
      });
      let firstFailed: boolean = false;
      try {
        await first;
      } catch (_err) {
        firstFailed = true;
      }
      await second;
      expect(firstFailed).assertTrue();
      expect(secondStarted).assertTrue();
      expect(queue.inFlight()).assertEqual(0);
    });

    it('dropSkipsQueuedWorkAndStartsFresh', 0, async (): Promise<void> => {
      const queue: GattWriteQueue = new GattWriteQueue();
      let started: number = 0;
      let releaseFirst: () => void = (): void => {
      };
      const first: Promise<void> = queue.enqueue((): Promise<void> => {
        started++;
        return new Promise<void>((resolve: () => void): void => {
          releaseFirst = resolve;
        });
      });
      let secondStarted: boolean = false;
      const second: Promise<void> = queue.enqueue((): Promise<void> => {
        secondStarted = true;
        started++;
        return Promise.resolve();
      });
      await delay(20);
      expect(started).assertEqual(1);
      queue.drop();
      releaseFirst();
      let secondDropped: boolean = false;
      try {
        await second;
      } catch (_err) {
        secondDropped = true;
      }
      await first;
      expect(secondDropped).assertTrue();
      expect(secondStarted).assertFalse();
      const third: Promise<void> = queue.enqueue((): Promise<void> => {
        started++;
        return Promise.resolve();
      });
      await third;
      expect(started).assertEqual(2);
      expect(queue.inFlight()).assertEqual(0);
    });
  });
}
