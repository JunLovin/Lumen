export type PlacementSide = 'left' | 'right';

export type MeasuredSide = PlacementSide | 'center';

export type PlacementFailure =
  | 'link_down'
  | 'low_signal'
  | 'microphone_denied'
  | 'microphone_unavailable'
  | 'unknown';

export type PlacementMeasurement = {
  readonly tauMicroseconds: number;
  readonly levelDifferenceDecibels: number;
  readonly snrDecibels: number;
  readonly acceptedPairs: number;
  readonly side: MeasuredSide;
  readonly curve: readonly number[];
};

export type PlacementTrial = {
  readonly expected: PlacementSide;
  readonly measurement: PlacementMeasurement | null;
  readonly failure: PlacementFailure | null;
};

export type TrialSummary = {
  readonly total: number;
  readonly hits: number;
  readonly meetsCriterion: boolean;
};

const REQUIRED_TRIALS = 40;
const REQUIRED_HITS = 38;

export const summarizeTrials = (
  trials: readonly PlacementTrial[],
): TrialSummary => {
  const hits = trials.filter(
    trial => trial.measurement?.side === trial.expected,
  ).length;
  return {
    total: trials.length,
    hits,
    meetsCriterion: trials.length >= REQUIRED_TRIALS && hits >= REQUIRED_HITS,
  };
};
