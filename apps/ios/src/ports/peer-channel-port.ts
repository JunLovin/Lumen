import type { DragFrame } from '../domain/drag-frame';
import type { PeerPlacement, PhoneEdge } from '../domain/peer-placement';

export interface PeerChannelPort {
  start(): void;
  isConnected(): Promise<boolean>;
  reconnect(): void;
  reportEdgeExit(edge: PhoneEdge): void;
  readPlacement(): Promise<PeerPlacement>;
  probeFileChannel(): Promise<boolean>;
  sendDragFrame(frame: DragFrame): void;
}
