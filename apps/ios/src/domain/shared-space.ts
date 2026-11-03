export type FacingSide = 'left' | 'right';

export type SharedSpace = {
  readonly edgeFacingMac: FacingSide;
  readonly screenWidthPoints: number;
  readonly pointsPerMillimeter: number;
};

export type Point = {
  readonly x: number;
  readonly y: number;
};

export const phoneToWorld = (point: Point, space: SharedSpace): Point => {
  'worklet';
  const distanceFromEdge =
    space.edgeFacingMac === 'right'
      ? point.x - space.screenWidthPoints
      : -point.x;
  return {
    x: distanceFromEdge / space.pointsPerMillimeter,
    y: point.y / space.pointsPerMillimeter,
  };
};

export const worldToPhone = (point: Point, space: SharedSpace): Point => {
  'worklet';
  const distanceFromEdge = point.x * space.pointsPerMillimeter;
  return {
    x:
      space.edgeFacingMac === 'right'
        ? distanceFromEdge + space.screenWidthPoints
        : -distanceFromEdge,
    y: point.y * space.pointsPerMillimeter,
  };
};
