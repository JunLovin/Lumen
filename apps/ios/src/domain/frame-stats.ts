export type FrameStats = {
  readonly frames: number;
  readonly dropped: number;
  readonly averageFps: number;
  readonly p95IntervalMilliseconds: number;
};

const DROPPED_FRAME_FACTOR = 1.5;

export const summarizeFrames = (
  intervalsMilliseconds: readonly number[],
  targetIntervalMilliseconds: number,
): FrameStats | null => {
  const sorted = [...intervalsMilliseconds].sort((a, b) => a - b);
  const total = sorted.reduce((sum, interval) => sum + interval, 0);
  const p95 = sorted[Math.round((sorted.length - 1) * 0.95)];
  if (p95 === undefined || total === 0) {
    return null;
  }
  return {
    frames: sorted.length,
    dropped: sorted.filter(
      interval => interval > targetIntervalMilliseconds * DROPPED_FRAME_FACTOR,
    ).length,
    averageFps: (sorted.length * 1000) / total,
    p95IntervalMilliseconds: p95,
  };
};
