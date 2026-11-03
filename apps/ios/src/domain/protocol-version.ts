import { err, ok, type Result } from './result';

export type ProtocolVersion = number;

export type ProtocolVersionMismatch = {
  readonly local: ProtocolVersion;
  readonly remote: ProtocolVersion;
};

export const negotiateProtocolVersion = (
  local: ProtocolVersion,
  remote: ProtocolVersion,
): Result<ProtocolVersion, ProtocolVersionMismatch> =>
  local === remote ? ok(local) : err({ local, remote });
