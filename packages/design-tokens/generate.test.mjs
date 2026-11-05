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
};

test('renders the same values for both platforms', () => {
  assert.match(renderTypeScript(tokens), /"response": 0\.35/);
  assert.match(
    renderSwift(tokens),
    /lift = SpringToken\(response: 0\.35, damping: 0\.8\)/,
  );
  assert.match(renderSwift(tokens), /glowBreathSeconds: Double = 3/);
});

test('rejects a spring without positive damping', () => {
  const invalid = {
    motion: { springs: { lift: { response: 1, damping: 0 } }, cycles: {} },
  };
  assert.throws(() => assertValidTokens(invalid), /lift/);
});
