import { negotiateProtocolVersion } from './protocol-version';

describe('negotiateProtocolVersion', () => {
  it('succeeds with the same version', () => {
    expect(negotiateProtocolVersion(1, 1)).toEqual({ ok: true, value: 1 });
  });

  it('reports both versions on mismatch', () => {
    expect(negotiateProtocolVersion(1, 2)).toEqual({
      ok: false,
      error: { local: 1, remote: 2 },
    });
  });
});
