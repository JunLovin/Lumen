import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  assertValidTokens,
  renderSwift,
  renderTypeScript,
} from './generate.mjs';

const tokens = {
  motion: {
    springs: { lift: { response: 0.35, damping: 0.8 } },
    cycles: { glowBreath: { seconds: 3 } },
  },
  glow: {
    overlayWidthPoints: 160,
    bandFraction: 0.5,
    intensity: 1,
    flowSpeed: 0.3,
    noiseScale: 3,
    palette: {
      primary: [0, 0.5, 1],
      secondary: [1, 0, 0],
      highlight: [1, 1, 1],
    },
  },
  chirp: { defaultAmplitude: 0.25 },
  pairing: { ringCycleSeconds: 1.6, ringCount: 3, verificationPalette: [[1, 0, 0]] },
};

test('renders the same values for both platforms', () => {
  assert.match(renderTypeScript(tokens), /"response": 0\.35/);
  assert.match(
    renderSwift(tokens),
    /lift = SpringToken\(response: 0\.35, damping: 0\.8\)/,
  );
  assert.match(renderSwift(tokens), /glowBreathSeconds: Double = 3/);
  assert.match(
    renderSwift(tokens),
    /primary = ColorToken\(red: 0, green: 0\.5, blue: 1\)/,
  );
});

test('rejects a spring without positive damping', () => {
  const invalid = {
    ...tokens,
    motion: { springs: { lift: { response: 1, damping: 0 } }, cycles: {} },
  };
  assert.throws(() => assertValidTokens(invalid), /lift/);
});

test('rejects a color channel outside the unit range', () => {
  const invalid = {
    ...tokens,
    glow: { ...tokens.glow, palette: { primary: [0, 0, 2] } },
  };
  assert.throws(() => assertValidTokens(invalid), /primary/);
});
