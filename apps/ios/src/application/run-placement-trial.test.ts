import type {
  PlacementFailure,
  PlacementMeasurement,
} from '../domain/placement';
import { err, ok, type Result } from '../domain/result';
import { createRunPlacementTrial } from './run-placement-trial';

const measurement = {
  tauMicroseconds: -600,
  levelDifferenceDecibels: -3,
  snrDecibels: 25,
  acceptedPairs: 3,
  side: 'right' as const,
  curve: [],
};

const acoustic = (result: Result<PlacementMeasurement, PlacementFailure>) => ({
  measure: () => Promise.resolve(result),
  exportLastRecording: () => Promise.resolve(null),
});

describe('runPlacementTrial', () => {
  it('records the measurement with the expected side', async () => {
    const run = createRunPlacementTrial(acoustic(ok(measurement)));
    await expect(run('right')).resolves.toEqual({
      expected: 'right',
      measurement,
      failure: null,
    });
  });

  it('records a failure as a value', async () => {
    const run = createRunPlacementTrial(acoustic(err('low_signal')));
    await expect(run('left')).resolves.toEqual({
      expected: 'left',
      measurement: null,
      failure: 'low_signal',
    });
  });
});
