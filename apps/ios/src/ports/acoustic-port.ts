import type {
  PlacementFailure,
  PlacementMeasurement,
} from '../domain/placement';
import type { Result } from '../domain/result';

export interface AcousticPort {
  measure(): Promise<Result<PlacementMeasurement, PlacementFailure>>;
  exportLastRecording(): Promise<string | null>;
}
