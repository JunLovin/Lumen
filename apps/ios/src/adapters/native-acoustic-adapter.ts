import type { PlacementFailure } from '../domain/placement';
import { err, ok } from '../domain/result';
import type { AcousticPort } from '../ports/acoustic-port';
import NativeLumenKit from './native/NativeLumenKit';

const KNOWN_FAILURES: readonly PlacementFailure[] = [
  'link_down',
  'low_signal',
  'microphone_denied',
  'microphone_unavailable',
];

const failureFrom = (error: unknown): PlacementFailure => {
  const code = (error as { readonly code?: unknown }).code;
  return KNOWN_FAILURES.find(failure => failure === code) ?? 'unknown';
};

export const createNativeAcousticAdapter = (): AcousticPort => ({
  measure: async () => {
    try {
      return ok(await NativeLumenKit.measurePlacement());
    } catch (error) {
      return err(failureFrom(error));
    }
  },
  exportLastRecording: () => NativeLumenKit.exportLastRecording(),
});
