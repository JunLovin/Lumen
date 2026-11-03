import {
  negotiateProtocolVersion,
  type ProtocolVersion,
  type ProtocolVersionMismatch,
} from '../domain/protocol-version';
import type { Result } from '../domain/result';
import type { RuntimeInfo, RuntimeInfoPort } from '../ports/runtime-info-port';

export type Diagnostics = RuntimeInfo & {
  readonly negotiation: Result<ProtocolVersion, ProtocolVersionMismatch>;
};

export type LoadDiagnostics = () => Diagnostics;

export const createLoadDiagnostics =
  (runtimeInfo: RuntimeInfoPort): LoadDiagnostics =>
  () => {
    const info = runtimeInfo.read();
    return {
      ...info,
      negotiation: negotiateProtocolVersion(
        info.scriptProtocolVersion,
        info.nativeProtocolVersion,
      ),
    };
  };
