import {
  calibrationFrom,
  classifySide,
  type PlacementCalibration,
  type PlacementFailure,
  type PlacementMeasurement,
  type PlacementSide,
  type PlacementTrial,
} from '../domain/placement';
import { err, type Result } from '../domain/result';
import type { AcousticPort } from '../ports/acoustic-port';

export type RunPlacementTrial = (
  expected: PlacementSide,
  calibration: PlacementCalibration,
) => Promise<PlacementTrial>;

export type CalibratePlacement = () => Promise<
  Result<PlacementCalibration, PlacementFailure>
>;

const CALIBRATION_MEASUREMENTS = 5;

export const createRunPlacementTrial =
  (acoustic: AcousticPort): RunPlacementTrial =>
  async (expected, calibration) => {
    const result = await acoustic.measure();
    return result.ok
      ? {
          expected,
          measurement: result.value,
          measuredSide: classifySide(result.value.tauMicroseconds, calibration),
          failure: null,
        }
      : {
          expected,
          measurement: null,
          measuredSide: null,
          failure: result.error,
        };
  };

export const createCalibratePlacement =
  (acoustic: AcousticPort): CalibratePlacement =>
  async () => {
    const measurements: PlacementMeasurement[] = [];
    for (let attempt = 0; attempt < CALIBRATION_MEASUREMENTS; attempt += 1) {
      const result = await acoustic.measure();
      if (!result.ok) {
        return err(result.error);
      }
      measurements.push(result.value);
    }
    return calibrationFrom(measurements);
  };
