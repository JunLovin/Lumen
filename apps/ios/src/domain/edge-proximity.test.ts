import { edgeProximity } from './edge-proximity';

describe('edgeProximity', () => {
  it('is zero outside the activation distance', () => {
    expect(edgeProximity(100, 390, 100)).toBe(0);
  });

  it('grows linearly toward the edge', () => {
    expect(edgeProximity(340, 390, 100)).toBeCloseTo(0.5);
  });

  it('is one at the edge and past it', () => {
    expect(edgeProximity(390, 390, 100)).toBe(1);
    expect(edgeProximity(420, 390, 100)).toBe(1);
  });
});
