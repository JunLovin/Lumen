import {
  calibrationFrom,
  classifySide,
  summarizeTrials,
  type PlacementMeasurement,
  type PlacementTrial,
} from './placement';

const measurement = (tauMicroseconds: number): PlacementMeasurement => ({
  tauMicroseconds,
  levelDifferenceDecibels: 5,
  snrDecibels: 30,
  acceptedPairs: 3,
  pairs: [],
  curve: [],
});

const trial = (
  measuredSide: PlacementTrial['measuredSide'],
): PlacementTrial => ({
  expected: 'left',
  measurement: null,
  measuredSide,
  failure: null,
});

const hit = trial('left');
const miss = trial('right');
const failed: PlacementTrial = { ...trial(null), failure: 'low_signal' };

describe('summarizeTrials', () => {
  it('meets the criterion at 38 of 40', () => {
    const trials = [...Array<PlacementTrial>(38).fill(hit), miss, miss];
    expect(summarizeTrials(trials)).toEqual({
      total: 40,
      hits: 38,
      meetsCriterion: true,
    });
  });

  it('does not meet it at 37 of 40', () => {
    const trials = [...Array<PlacementTrial>(37).fill(hit), miss, miss, miss];
    expect(summarizeTrials(trials).meetsCriterion).toBe(false);
  });

  it('does not meet it with too few trials', () => {
    expect(
      summarizeTrials(Array<PlacementTrial>(10).fill(hit)).meetsCriterion,
    ).toBe(false);
  });

  it('counts failed measurements as misses', () => {
    expect(summarizeTrials([failed]).hits).toBe(0);
  });
});

describe('calibrationFrom', () => {
  it('uses the median, ignoring an outlier', () => {
    const result = calibrationFrom([
      measurement(1000),
      measurement(1100),
      measurement(4000),
    ]);
    expect(result).toEqual({
      ok: true,
      value: { tauMicroseconds: 1100, levelDifferenceDecibels: 5, samples: 3 },
    });
  });

  it('fails without measurements', () => {
    expect(calibrationFrom([])).toEqual({ ok: false, error: 'low_signal' });
  });
});

describe('classifySide', () => {
  const calibration = {
    tauMicroseconds: 1000,
    levelDifferenceDecibels: 5,
    samples: 5,
  };

  it('removes the bias before reading the sign', () => {
    expect(classifySide(800, calibration)).toBe('right');
    expect(classifySide(1300, calibration)).toBe('left');
  });

  it('treats values near the calibration as center', () => {
    expect(classifySide(1050, calibration)).toBe('center');
  });
});
