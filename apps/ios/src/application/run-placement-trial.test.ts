import type {
  PlacementFailure,
  PlacementMeasurement,
} from '../domain/placement';
import { err, ok, type Result } from '../domain/result';
import {
  createCalibratePlacement,
  createRunPlacementTrial,
} from './run-placement-trial';

const measurement: PlacementMeasurement = {
  tauMicroseconds: 700,
  levelDifferenceDecibels: -3,
  snrDecibels: 25,
  acceptedPairs: 3,
  pairs: [],
  curve: [],
};

const calibration = {
  tauMicroseconds: 1000,
  levelDifferenceDecibels: 5,
  samples: 5,
};

const acoustic = (result: Result<PlacementMeasurement, PlacementFailure>) => ({
  measure: () => Promise.resolve(result),
  exportLastRecording: () => Promise.resolve(null),
});

describe('runPlacementTrial', () => {
  it('classifies the measurement against the calibration', async () => {
    const run = createRunPlacementTrial(acoustic(ok(measurement)));
    await expect(run('right', calibration)).resolves.toEqual({
      expected: 'right',
      measurement,
      measuredSide: 'right',
      failure: null,
    });
  });

  it('records a failure as a value', async () => {
    const run = createRunPlacementTrial(acoustic(err('low_signal')));
    await expect(run('left', calibration)).resolves.toEqual({
      expected: 'left',
      measurement: null,
      measuredSide: null,
      failure: 'low_signal',
    });
  });
});

describe('calibratePlacement', () => {
  it('summarizes several measurements', async () => {
    const calibrate = createCalibratePlacement(acoustic(ok(measurement)));
    await expect(calibrate()).resolves.toEqual({
      ok: true,
      value: { tauMicroseconds: 700, levelDifferenceDecibels: -3, samples: 5 },
    });
  });

  it('stops at the first failure', async () => {
    const calibrate = createCalibratePlacement(acoustic(err('link_down')));
    await expect(calibrate()).resolves.toEqual({
      ok: false,
      error: 'link_down',
    });
  });
});
