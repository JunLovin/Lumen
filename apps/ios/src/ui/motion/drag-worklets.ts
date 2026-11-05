import { edgeProximity } from '../../domain/edge-proximity';
import { activeEdge } from '../../domain/glow-edge';
import { phoneToWorld, type FacingSide } from '../../domain/shared-space';
import type { DragController } from './use-drag-controller';

// Positions of PhoneEdge in the protocol.
const EDGE_INDEX_RIGHT = 1;
const EDGE_INDEX_LEFT = 3;
const ACTIVATION_DISTANCE_POINTS = 140;
const MAX_TILT_DEGREES = 8;
const MAX_ROTATION_RADIANS = 0.2;
const ROTATION_PER_POINT_PER_SECOND = 0.00012;

export const updateGlow = (drag: DragController, fingerX: number) => {
  'worklet';
  const left = edgeProximity(
    drag.screenWidth - fingerX,
    drag.screenWidth,
    ACTIVATION_DISTANCE_POINTS,
  );
  const right = edgeProximity(
    fingerX,
    drag.screenWidth,
    ACTIVATION_DISTANCE_POINTS,
  );
  const nearest: FacingSide = left > right ? 'left' : 'right';
  const known: FacingSide | null =
    drag.facingIsRight.value === null
      ? null
      : drag.facingIsRight.value
        ? 'right'
        : 'left';
  const edge = activeEdge(drag.confidence.value, known, nearest);
  const proximity = Math.max(left, right);
  drag.leftGlow.value = edge === 'left' ? proximity : 0;
  drag.rightGlow.value = edge === 'right' ? proximity : 0;
  return { edge: edge ?? nearest, proximity };
};

export const updateTilt = (
  drag: DragController,
  fingerX: number,
  fingerY: number,
  velocityX: number,
) => {
  'worklet';
  const horizontal = (fingerX / drag.screenWidth - 0.5) * 2;
  const vertical = (fingerY / drag.screenHeight - 0.5) * 2;
  drag.tiltY.value = horizontal * MAX_TILT_DEGREES;
  drag.tiltX.value = -vertical * MAX_TILT_DEGREES;
  drag.rotation.value = Math.max(
    -MAX_ROTATION_RADIANS,
    Math.min(MAX_ROTATION_RADIANS, velocityX * ROTATION_PER_POINT_PER_SECOND),
  );
};

export const sendDragFrame = (
  drag: DragController,
  fingerX: number,
  fingerY: number,
  velocityX: number,
  velocityY: number,
  edge: FacingSide,
  proximity: number,
  objectSize: number,
) => {
  'worklet';
  const perMillimeter = drag.pointsPerMillimeter;
  const world = phoneToWorld(
    { x: fingerX, y: fingerY },
    {
      edgeFacingMac: edge,
      screenWidthPoints: drag.screenWidth,
      pointsPerMillimeter: perMillimeter,
    },
  );
  drag.sequence.value += 1;
  drag.channel.sendFrame(
    drag.session.value,
    drag.sequence.value,
    world.x,
    world.y,
    (edge === 'right' ? velocityX : -velocityX) / perMillimeter,
    velocityY / perMillimeter,
    proximity,
    objectSize / perMillimeter,
    objectSize / perMillimeter,
    drag.rotation.value,
    edge === 'right' ? EDGE_INDEX_RIGHT : EDGE_INDEX_LEFT,
  );
};
