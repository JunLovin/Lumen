import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Hello, ProtocolVersion } from '@lumen/protocol';

const fixture = (name: string) =>
  new Uint8Array(
    readFileSync(join(__dirname, '../../../../fixtures/protocol', name)),
  );

describe('protocol fixtures', () => {
  it('round-trips Hello', () => {
    const bytes = fixture('hello.bin');
    const hello = Hello.decode(bytes);

    expect(hello.protocolVersion).toBe(
      ProtocolVersion.PROTOCOL_VERSION_CURRENT,
    );
    expect(Array.from(hello.deviceIdHash)).toEqual([0xde, 0xad, 0xbe, 0xef]);
    expect(Array.from(Hello.encode(hello).finish())).toEqual(Array.from(bytes));
  });
});
