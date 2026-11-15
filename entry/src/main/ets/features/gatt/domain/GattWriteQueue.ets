export class GattWriteQueue {
  private tail: Promise<void> = Promise.resolve();
  private active: number = 0;
  private generation: number = 0;

  enqueue(work: () => Promise<void>): Promise<void> {
    const ticket: number = this.generation;
    const run: Promise<void> = this.tail.then((): Promise<void> => {
      if (ticket !== this.generation) {
        return Promise.reject(new Error('dropped'));
      }
      this.active++;
      let pending: Promise<void>;
      try {
        pending = work();
      } catch (err) {
        this.active--;
        return Promise.reject(err);
      }
      return pending.then((): void => {
        if (ticket === this.generation) {
          this.active--;
        }
      }).catch((err: Object): Promise<void> => {
        if (ticket === this.generation) {
          this.active--;
        }
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

  drop(): void {
    this.generation++;
    this.tail = Promise.resolve();
    this.active = 0;
  }

  inFlight(): number {
    return this.active;
  }
}
