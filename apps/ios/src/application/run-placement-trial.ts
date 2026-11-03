import type { PlacementSide, PlacementTrial } from '../domain/placement';
import type { AcousticPort } from '../ports/acoustic-port';

export type RunPlacementTrial = (
  expected: PlacementSide,
) => Promise<PlacementTrial>;

export const createRunPlacementTrial =
  (acoustic: AcousticPort): RunPlacementTrial =>
  async expected => {
    const result = await acoustic.measure();
    return result.ok
      ? { expected, measurement: result.value, failure: null }
      : { expected, measurement: null, failure: result.error };
  };
