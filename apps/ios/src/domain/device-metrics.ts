// iPhone 14: 460 ppi at 3x is 153.33 points per inch. Replaced by a per-model table in Phase 4.
export const POINTS_PER_MILLIMETER = 6.037;

export const pointsToMillimeters = (points: number): number => {
  'worklet';
  return points / POINTS_PER_MILLIMETER;
};
