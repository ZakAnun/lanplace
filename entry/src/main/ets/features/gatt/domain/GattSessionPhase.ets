export type GattSessionPhase = 'Disconnected' | 'Connecting' | 'Connected' | 'Lost';

export type GattPhaseListener = (deviceId: string, phase: GattSessionPhase) => void;
