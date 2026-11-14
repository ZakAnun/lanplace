export class GattWriteQueue {
  private tail: Promise<void> = Promise.resolve();
  private active: number = 0;

  enqueue(work: () => Promise<void>): Promise<void> {
    const run: Promise<void> = this.tail.then((): Promise<void> => {
      this.active++;
      let pending: Promise<void>;
      try {
        pending = work();
      } catch (err) {
        this.active--;
        return Promise.reject(err);
      }
      return pending.then((): void => {
        this.active--;
      }).catch((err: Object): Promise<void> => {
        this.active--;
        return Promise.reject(err);
      });
    });
    this.tail = run.then((): void => {
      return;
    }, (): void => {
      return;
    });
    return run;
  }

  inFlight(): number {
    return this.active;
  }
}
