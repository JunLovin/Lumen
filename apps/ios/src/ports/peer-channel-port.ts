import type { DragFrame } from '../domain/drag-frame';

export interface PeerChannelPort {
  start(): void;
  isConnected(): Promise<boolean>;
  reconnect(): void;
  probeFileChannel(): Promise<boolean>;
  sendDragFrame(frame: DragFrame): void;
}
