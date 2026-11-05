import { summarizeFrames } from './frame-stats';

describe('summarizeFrames', () => {
  it('has no stats without frames', () => {
    expect(summarizeFrames([], 16.67)).toBeNull();
  });

  it('counts intervals well past the target as dropped', () => {
    const stats = summarizeFrames([16.67, 16.67, 33.34, 16.67], 16.67);
    expect(stats?.frames).toBe(4);
    expect(stats?.dropped).toBe(1);
    expect(stats?.p95IntervalMilliseconds).toBe(33.34);
  });

  it('derives the average frame rate', () => {
    expect(summarizeFrames([10, 10], 10)?.averageFps).toBeCloseTo(100);
  });
});
