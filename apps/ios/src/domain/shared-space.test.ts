import fc from 'fast-check';
import { phoneToWorld, worldToPhone, type SharedSpace } from './shared-space';

const space = (edgeFacingMac: SharedSpace['edgeFacingMac']): SharedSpace => ({
  edgeFacingMac,
  screenWidthPoints: 390,
  pointsPerMillimeter: 6,
});

describe('SharedSpace', () => {
  it('puts the edge facing the Mac at world zero', () => {
    expect(phoneToWorld({ x: 390, y: 60 }, space('right'))).toEqual({
      x: 0,
      y: 10,
    });
    expect(phoneToWorld({ x: 0, y: 60 }, space('left')).x).toBeCloseTo(0);
  });

  it('makes moving toward the Mac positive on both sides', () => {
    expect(phoneToWorld({ x: 420, y: 0 }, space('right')).x).toBe(5);
    expect(phoneToWorld({ x: -30, y: 0 }, space('left')).x).toBe(5);
  });

  it('round-trips any point', () => {
    fc.assert(
      fc.property(
        fc.double({ min: -1000, max: 1000, noNaN: true }),
        fc.double({ min: -1000, max: 1000, noNaN: true }),
        fc.constantFrom<SharedSpace['edgeFacingMac']>('left', 'right'),
        fc.double({ min: 1, max: 10, noNaN: true }),
        (x, y, edgeFacingMac, pointsPerMillimeter) => {
          const current: SharedSpace = {
            edgeFacingMac,
            screenWidthPoints: 390,
            pointsPerMillimeter,
          };
          const result = worldToPhone(phoneToWorld({ x, y }, current), current);
          expect(result.x).toBeCloseTo(x, 6);
          expect(result.y).toBeCloseTo(y, 6);
        },
      ),
    );
  });
});
