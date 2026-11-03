import { createLoadDiagnostics } from './load-diagnostics';

const fakeRuntimeInfo = (nativeProtocolVersion: number) => ({
  read: () => ({
    scriptProtocolVersion: 1,
    nativeProtocolVersion,
    isHermes: true,
    isNewArchitecture: true,
  }),
});

describe('loadDiagnostics', () => {
  it('reports agreement between the script and native layers', () => {
    const load = createLoadDiagnostics(fakeRuntimeInfo(1));
    expect(load().negotiation).toEqual({ ok: true, value: 1 });
  });

  it('reports a native layer built from another protocol', () => {
    const load = createLoadDiagnostics(fakeRuntimeInfo(2));
    expect(load().negotiation).toEqual({
      ok: false,
      error: { local: 1, remote: 2 },
    });
  });
});
