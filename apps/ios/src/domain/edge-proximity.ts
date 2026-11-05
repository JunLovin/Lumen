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
