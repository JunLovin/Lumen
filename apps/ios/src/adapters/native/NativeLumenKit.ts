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

export type NativeLibraryAsset = {
  readonly id: string;
  readonly width: number;
  readonly height: number;
  readonly mediaType: string;
};

export type NativeReceivedFile = {
  readonly name: string;
  readonly uri: string;
  readonly isDirectory: boolean;
  readonly byteCount: number;
};

export type NativeInbox = {
  readonly files: readonly NativeReceivedFile[];
  readonly receivedBytes: number;
  readonly totalBytes: number;
};

export interface Spec extends TurboModule {
  deviceModel(): string;
  libraryAccess(): string;
  requestLibraryAccess(): Promise<string>;
  fetchLibraryAssets(
    offset: number,
    limit: number,
  ): Promise<readonly NativeLibraryAsset[]>;
  loadThumbnail(assetId: string, size: number): Promise<string | null>;
  manageLimitedLibrary(): void;
  pickFilesToSend(): void;
  listReceivedFiles(): Promise<NativeInbox>;
  deleteReceivedFile(name: string): void;
  beginDrag(
    session: number,
    assetId: string,
    phoneHeightMillimeters: number,
  ): Promise<number[]>;
  sendTuning(name: string, value: number): void;
  // Codegen accepts a free-form map only under this spelling.
  // eslint-disable-next-line @typescript-eslint/no-wrapper-object-types
  readTuning(): Promise<Object>;
  hasSeenOnboarding(): boolean;
  markOnboardingSeen(): void;
  protocolVersion(): number;
  startLink(): void;
  linkStatus(): Promise<boolean>;
  pairingStatus(): Promise<NativePairingStatus>;
  forgetPairing(): void;
  reportEdgeExit(edge: number): void;
  placementStatus(): Promise<NativePlacementStatus>;
  reconnect(): void;
  probeFileChannel(): Promise<boolean>;
  measurePlacement(): Promise<NativePlacementMeasurement>;
  exportLastRecording(): Promise<string | null>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('LumenKit');
