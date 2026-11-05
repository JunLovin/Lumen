import type { ProtocolVersion } from '../domain/protocol-version';

export type RuntimeInfo = {
  readonly scriptProtocolVersion: ProtocolVersion;
  readonly nativeProtocolVersion: ProtocolVersion;
  readonly isHermes: boolean;
  readonly isNewArchitecture: boolean;
};

export interface RuntimeInfoPort {
  read(): RuntimeInfo;
}
