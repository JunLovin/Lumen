import { TurboModuleRegistry, type TurboModule } from 'react-native';

export type NativePairArrival = {
  readonly tauMicroseconds: number;
  readonly levelDifferenceDecibels: number;
  readonly snrDecibels: number;
};

export type NativePlacementMeasurement = {
  readonly tauMicroseconds: number;
  readonly levelDifferenceDecibels: number;
  readonly snrDecibels: number;
  readonly acceptedPairs: number;
  readonly pairs: readonly NativePairArrival[];
  readonly curve: readonly number[];
};

export type NativePairingStatus = {
  readonly stage: string;
  readonly pattern?: readonly number[];
  readonly peerName?: string;
};

export type NativePlacementStatus = {
  readonly side: number;
  readonly confidence: number;
  readonly probabilities: readonly number[];
  readonly isDetached: boolean;
  readonly facingEdge: number;
  readonly locationFailure?: string;
  readonly locateMilliseconds?: number;
};

export interface Spec extends TurboModule {
  protocolVersion(): number;
  startLink(): void;
  linkStatus(): Promise<boolean>;
  pairingStatus(): Promise<NativePairingStatus>;
  forgetPairing(): void;
  reportEdgeExit(edge: number): void;
  placementStatus(): Promise<NativePlacementStatus>;
  reconnect(): void;
  probeFileChannel(): Promise<boolean>;
  sendDragFrame(
    session: number,
    sequence: number,
    ageMilliseconds: number,
    xMillimeters: number,
    yMillimeters: number,
    velocityX: number,
    velocityY: number,
    edgeProximity: number,
    objectWidth: number,
    objectHeight: number,
    rotation: number,
  ): void;
  measurePlacement(): Promise<NativePlacementMeasurement>;
  exportLastRecording(): Promise<string | null>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('LumenKit');
