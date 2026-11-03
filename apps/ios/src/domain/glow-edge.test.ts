import { activeEdge, glowPolicy } from './glow-edge';

describe('glowPolicy', () => {
  it('follows the bands of the plan', () => {
    expect(glowPolicy(0.8)).toBe('anticipate');
    expect(glowPolicy(0.5)).toBe('whenCompatible');
    expect(glowPolicy(0.49)).toBe('followFinger');
  });
});

describe('activeEdge', () => {
  it('uses the known edge at high confidence', () => {
    expect(activeEdge(0.9, 'right', 'left')).toBe('right');
  });

  it('only glows on a compatible edge at medium confidence', () => {
    expect(activeEdge(0.6, 'right', 'right')).toBe('right');
    expect(activeEdge(0.6, 'right', 'left')).toBeNull();
  });

  it('follows the finger at low confidence or without a known edge', () => {
    expect(activeEdge(0.2, 'right', 'left')).toBe('left');
    expect(activeEdge(0.9, null, 'left')).toBe('left');
  });
});
