import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Datagram, Hello, ProtocolVersion } from './generated/lumen.ts';

const directory = fileURLToPath(new URL('../../fixtures/protocol/', import.meta.url));
const deviceIdHash = new Uint8Array([0xde, 0xad, 0xbe, 0xef]);

const hello = {
  protocolVersion: ProtocolVersion.PROTOCOL_VERSION_CURRENT,
  deviceIdHash,
};

const datagrams = {
  'datagram-hello': { hello },
  'datagram-clock-ping': { clockPing: { originNs: 1_000 } },
  'datagram-clock-pong': {
    clockPong: { originNs: 1_000, receiveNs: 2_000, transmitNs: 3_000 },
  },
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
  'datagram-play-chirp-pair': { playChirpPair: { requestId: 9 } },
  'datagram-acoustic-report': {
    acousticReport: {
      requestId: 9,
      tauUs: -640.5,
      levelDifferenceDb: -3.5,
      snrDb: 18.25,
      acceptedPairs: 3,
    },
  },
};

mkdirSync(directory, { recursive: true });
writeFileSync(`${directory}hello.bin`, Hello.encode(hello).finish());
for (const [name, datagram] of Object.entries(datagrams)) {
  writeFileSync(`${directory}${name}.bin`, Datagram.encode(datagram).finish());
}
