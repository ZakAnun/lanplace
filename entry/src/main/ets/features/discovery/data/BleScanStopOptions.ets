export interface BleScanStopOptions {
  emitUpdate?: boolean;
  notifyComplete?: boolean;
}

export const BLE_SCAN_STOP_QUIET: BleScanStopOptions = {
  emitUpdate: false,
  notifyComplete: false
};

export const BLE_SCAN_STOP_WITH_COMPLETE: BleScanStopOptions = {
  emitUpdate: true,
  notifyComplete: true
};
