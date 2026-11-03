export const edgeProximity = (
  position: number,
  extent: number,
  activationDistance: number,
): number => {
  'worklet';
  const distanceToEdge = extent - position;
  const closeness = 1 - distanceToEdge / activationDistance;
  return Math.min(Math.max(closeness, 0), 1);
};

export const horizontalExitEdge = (
  position: number,
  extent: number,
  margin: number,
): 'left' | 'right' | null => {
  'worklet';
  if (position <= margin) {
    return 'left';
  }
  return position >= extent - margin ? 'right' : null;
};

export const crossingFraction = (
  fingerX: number,
  edge: 'left' | 'right',
  screenWidth: number,
  objectSize: number,
): number => {
  'worklet';
  const leading =
    edge === 'right'
      ? fingerX + objectSize / 2 - screenWidth
      : objectSize / 2 - fingerX;
  return Math.min(Math.max(leading / objectSize, 0), 1);
};
