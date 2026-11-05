import { springConfig } from './spring';

describe('springConfig', () => {
  it('converts response and damping ratio into physical values', () => {
    const config = springConfig({ response: 1, damping: 0.5 });
    expect(config.stiffness).toBeCloseTo(4 * Math.PI * Math.PI);
    expect(config.damping).toBeCloseTo(2 * Math.PI);
  });
});
