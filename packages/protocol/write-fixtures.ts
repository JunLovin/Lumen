import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  ControlMessage,
  Datagram,
  Hello,
  PairingMessage,
  ProtocolVersion,
} from './generated/lumen.ts';

const directory = fileURLToPath(
  new URL('../../fixtures/protocol/', import.meta.url),
);
const deviceIdHash = new Uint8Array([0xde, 0xad, 0xbe, 0xef]);

const hello = {
  protocolVersion: ProtocolVersion.PROTOCOL_VERSION_CURRENT,
  deviceIdHash,
};

const bytes = (...values: number[]) => new Uint8Array(values);

const datagrams = {
  'datagram-hello': { hello },
  'datagram-drag-frame': {
    dragFrame: {
      session: 7,
      sequence: 42,
      timestampNs: 123_456_789,
      xMm: 12.5,
      yMm: -3.25,
      velocityXMmS: 100.5,
      velocityYMmS: -50.25,
      edgeProximity: 0.75,
      objectWidthMm: 40,
      objectHeightMm: 30,
      rotationRad: 0.5,
    },
  },
};

const controlMessages = {
  'control-hello': { hello },
  'control-session-key': {
    sessionKey: { x25519Public: bytes(1, 2), signature: bytes(3, 4) },
  },
  'control-session-ready': { sessionReady: { realtimePort: 5000, filePort: 5001 } },
  'control-incompatible-version': {
    incompatibleVersion: { supported: ProtocolVersion.PROTOCOL_VERSION_CURRENT },
  },
  'control-clock-ping': { clockPing: { originNs: 1_000 } },
  'control-clock-pong': {
    clockPong: { originNs: 1_000, receiveNs: 2_000, transmitNs: 3_000 },
  },
  'control-play-chirp-pair': { playChirpPair: { requestId: 9 } },
  'control-acoustic-report': {
    acousticReport: {
      requestId: 9,
      tauUs: -640.5,
      levelDifferenceDb: -3.5,
      snrDb: 18.25,
      acceptedPairs: 3,
    },
  },
};

const pairingMessages = {
  'pairing-commit': { commit: { commitment: bytes(1, 2, 3) } },
  'pairing-key': { key: { x25519Public: bytes(4, 5), nonce: bytes(6, 7) } },
  'pairing-sealed': { sealed: { sealedBox: bytes(8, 9) } },
  'pairing-confirmed': { confirmed: { confirmation: bytes(10, 11) } },
};

mkdirSync(directory, { recursive: true });
writeFileSync(`${directory}hello.bin`, Hello.encode(hello).finish());
for (const [name, message] of Object.entries(datagrams)) {
  writeFileSync(`${directory}${name}.bin`, Datagram.encode(message).finish());
}
for (const [name, message] of Object.entries(controlMessages)) {
  writeFileSync(`${directory}${name}.bin`, ControlMessage.encode(message).finish());
}
for (const [name, message] of Object.entries(pairingMessages)) {
  writeFileSync(`${directory}${name}.bin`, PairingMessage.encode(message).finish());
}
