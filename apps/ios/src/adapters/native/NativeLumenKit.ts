import { TurboModuleRegistry, type TurboModule } from 'react-native';

export type NativePlacementMeasurement = {
  readonly tauMicroseconds: number;
  readonly levelDifferenceDecibels: number;
  readonly snrDecibels: number;
  readonly acceptedPairs: number;
  readonly side: string;
  readonly curve: readonly number[];
};

export interface Spec extends TurboModule {
  protocolVersion(): number;
  startLink(): void;
  linkStatus(): Promise<boolean>;
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
