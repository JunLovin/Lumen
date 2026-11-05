import { patchTokens, readTokenValue } from './motion-tuning';

const tokens = { glow: { intensity: 1, palette: [1, 2] }, motion: {} };

describe('motion tuning', () => {
  it('reads numeric tokens by path', () => {
    expect(readTokenValue(tokens, 'glow.intensity')).toBe(1);
    expect(readTokenValue(tokens, 'glow.palette')).toBeNull();
    expect(readTokenValue(tokens, 'missing.value')).toBeNull();
  });

  it('patches values without touching the rest', () => {
    expect(patchTokens(tokens, { 'glow.intensity': 2 })).toEqual({
      glow: { intensity: 2, palette: [1, 2] },
      motion: {},
    });
    expect(tokens.glow.intensity).toBe(1);
  });
});
