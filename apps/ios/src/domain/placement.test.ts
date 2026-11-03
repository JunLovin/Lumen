import { summarizeTrials, type PlacementTrial } from './placement';

const measured = (side: 'left' | 'right' | 'center') => ({
  tauMicroseconds: 0,
  levelDifferenceDecibels: 0,
  snrDecibels: 30,
  acceptedPairs: 3,
  side,
  curve: [],
});

const hit: PlacementTrial = {
  expected: 'left',
  measurement: measured('left'),
  failure: null,
};
const miss: PlacementTrial = {
  expected: 'left',
  measurement: measured('right'),
  failure: null,
};
const failed: PlacementTrial = {
  expected: 'left',
  measurement: null,
  failure: 'low_signal',
};

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
