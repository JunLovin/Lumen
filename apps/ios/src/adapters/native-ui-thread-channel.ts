import type { UIThreadChannelPort } from '../ports/ui-thread-channel-port';
import NativeLumenKit from './native/NativeLumenKit';

export const createNativeUIThreadChannel = (): UIThreadChannelPort => {
  NativeLumenKit.protocolVersion();
  return (
    globalThis as unknown as { __lumenUIThreadChannel: UIThreadChannelPort }
  ).__lumenUIThreadChannel;
};
