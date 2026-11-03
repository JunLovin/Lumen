import { err, ok, type Result } from './result';

export type PlacementSide = 'left' | 'right';

export type MeasuredSide = PlacementSide | 'center';

export const PLACEMENT_FAILURES = [
  'link_down',
  'low_signal',
  'microphone_denied',
  'microphone_unavailable',
  'unknown',
] as const;

export type PlacementFailure = (typeof PLACEMENT_FAILURES)[number];

export type PairArrival = {
  readonly tauMicroseconds: number;
  readonly levelDifferenceDecibels: number;
  readonly snrDecibels: number;
};

export type PlacementMeasurement = PairArrival & {
  readonly acceptedPairs: number;
  readonly pairs: readonly PairArrival[];
  readonly curve: readonly number[];
};

export type PlacementCalibration = {
  readonly tauMicroseconds: number;
  readonly levelDifferenceDecibels: number;
  readonly samples: number;
};

export type PlacementTrial = {
  readonly expected: PlacementSide;
  readonly measurement: PlacementMeasurement | null;
  readonly measuredSide: MeasuredSide | null;
  readonly failure: PlacementFailure | null;
};

export type TrialSummary = {
  readonly total: number;
  readonly hits: number;
  readonly meetsCriterion: boolean;
};

const REQUIRED_TRIALS = 40;
const REQUIRED_HITS = 38;
const CENTER_BAND_MICROSECONDS = 100;

const median = (values: readonly number[]): number | undefined => {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  const upper = sorted[middle];
  const lower = sorted[middle - 1];
  if (upper === undefined) {
    return undefined;
  }
  return sorted.length % 2 === 0 && lower !== undefined
    ? (lower + upper) / 2
    : upper;
};

export const calibrationFrom = (
  measurements: readonly PlacementMeasurement[],
): Result<PlacementCalibration, PlacementFailure> => {
  const tau = median(
    measurements.map(measurement => measurement.tauMicroseconds),
  );
  const level = median(
    measurements.map(measurement => measurement.levelDifferenceDecibels),
  );
  return tau === undefined || level === undefined
    ? err('low_signal')
    : ok({
        tauMicroseconds: tau,
        levelDifferenceDecibels: level,
        samples: measurements.length,
      });
};

export const classifySide = (
  tauMicroseconds: number,
  calibration: PlacementCalibration,
): MeasuredSide => {
  const relative = tauMicroseconds - calibration.tauMicroseconds;
  if (Math.abs(relative) < CENTER_BAND_MICROSECONDS) {
    return 'center';
  }
  return relative < 0 ? 'right' : 'left';
};

export const summarizeTrials = (
  trials: readonly PlacementTrial[],
): TrialSummary => {
  const hits = trials.filter(
    trial => trial.measuredSide === trial.expected,
  ).length;
  return {
    total: trials.length,
    hits,
    meetsCriterion: trials.length >= REQUIRED_TRIALS && hits >= REQUIRED_HITS,
  };
};
