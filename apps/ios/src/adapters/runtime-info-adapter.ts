import { ProtocolVersion } from '@lumen/protocol';
import type { RuntimeInfoPort } from '../ports/runtime-info-port';
import NativeLumenKit from './native/NativeLumenKit';

export const createRuntimeInfoAdapter = (): RuntimeInfoPort => ({
  read: () => ({
    scriptProtocolVersion: ProtocolVersion.PROTOCOL_VERSION_CURRENT,
    nativeProtocolVersion: NativeLumenKit.protocolVersion(),
    isHermes: 'HermesInternal' in globalThis,
    isNewArchitecture: 'nativeFabricUIManager' in globalThis,
  }),
});
