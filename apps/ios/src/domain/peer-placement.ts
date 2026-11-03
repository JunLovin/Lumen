import type { PlacementFailure } from './placement';

export const PLACEMENT_SIDES = [
  'left',
  'right',
  'below',
  'above',
  'unknown',
] as const;
export const PHONE_EDGES = ['top', 'right', 'bottom', 'left'] as const;

export type PeerSide = (typeof PLACEMENT_SIDES)[number];
export type PhoneEdge = (typeof PHONE_EDGES)[number];

export type PeerPlacement = {
  readonly side: PeerSide;
  readonly confidence: number;
  readonly probabilities: readonly number[];
  readonly isDetached: boolean;
  readonly facingEdge: PhoneEdge | null;
  readonly locationFailure: PlacementFailure | null;
};
