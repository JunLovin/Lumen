import type { PeerChannelPort } from '../ports/peer-channel-port';
import NativeLumenKit from './native/NativeLumenKit';

export const createNativePeerChannelAdapter = (): PeerChannelPort => ({
  start: () => NativeLumenKit.startLink(),
  isConnected: () => NativeLumenKit.linkStatus(),
  reconnect: () => NativeLumenKit.reconnect(),
  probeFileChannel: () => NativeLumenKit.probeFileChannel(),
  sendDragFrame: frame =>
    NativeLumenKit.sendDragFrame(
      frame.session,
      frame.sequence,
      frame.ageMilliseconds,
      frame.xMillimeters,
      frame.yMillimeters,
      frame.velocityX,
      frame.velocityY,
      frame.edgeProximity,
      frame.objectWidthMillimeters,
      frame.objectHeightMillimeters,
      frame.rotationRadians,
    ),
});
