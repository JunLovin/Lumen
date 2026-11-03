import { useCallback, useRef, useState } from 'react';
import { useFrameCallback, useSharedValue } from 'react-native-reanimated';
import { scheduleOnRN } from 'react-native-worklets';
import { summarizeFrames, type FrameStats } from '../../domain/frame-stats';

const BATCH_SIZE = 30;
const TARGET_INTERVAL_MILLISECONDS = 1000 / 60;

export const useFrameMeter = () => {
  const [stats, setStats] = useState<FrameStats | null>(null);
  const intervals = useRef<number[]>([]);
  const batch = useSharedValue<number[]>([]);

  const report = useCallback((values: number[]) => {
    intervals.current = [...intervals.current, ...values];
    setStats(summarizeFrames(intervals.current, TARGET_INTERVAL_MILLISECONDS));
  }, []);

  const reset = useCallback(() => {
    intervals.current = [];
    setStats(null);
  }, []);

  useFrameCallback(info => {
    const interval = info.timeSincePreviousFrame;
    if (interval === null) {
      return;
    }
    const pending = [...batch.value, interval];
    if (pending.length < BATCH_SIZE) {
      batch.value = pending;
      return;
    }
    batch.value = [];
    scheduleOnRN(report, pending);
  });

  return { stats, reset };
};
