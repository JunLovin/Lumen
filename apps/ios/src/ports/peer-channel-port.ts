import type { PeerPlacement, PhoneEdge } from '../domain/peer-placement';

export interface PeerChannelPort {
  start(): void;
  isConnected(): Promise<boolean>;
  reconnect(): void;
  reportEdgeExit(edge: PhoneEdge): void;
  readPlacement(): Promise<PeerPlacement>;
  probeFileChannel(): Promise<boolean>;
  sendTuning(name: string, value: number): void;
  readTuning(): Promise<Readonly<Record<string, number>>>;
  hasSeenOnboarding(): boolean;
  markOnboardingSeen(): void;
}
