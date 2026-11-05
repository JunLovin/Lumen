import type { FacingSide } from './shared-space';

const HIGH_CONFIDENCE = 0.8;
const MEDIUM_CONFIDENCE = 0.5;

export type GlowPolicy = 'anticipate' | 'whenCompatible' | 'followFinger';

export const glowPolicy = (confidence: number): GlowPolicy => {
  'worklet';
  if (confidence >= HIGH_CONFIDENCE) {
    return 'anticipate';
  }
  return confidence >= MEDIUM_CONFIDENCE ? 'whenCompatible' : 'followFinger';
};

export const activeEdge = (
  confidence: number,
  facingEdge: FacingSide | null,
  nearestEdge: FacingSide,
): FacingSide | null => {
  'worklet';
  if (glowPolicy(confidence) === 'followFinger' || facingEdge === null) {
    return nearestEdge;
  }
  return glowPolicy(confidence) === 'anticipate' || nearestEdge === facingEdge
    ? facingEdge
    : null;
};
