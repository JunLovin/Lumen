import { tokens } from '@lumen/design-tokens';
import { edgeProximity } from '../../domain/edge-proximity';
import { activeEdge } from '../../domain/glow-edge';
import type { DragSession } from '../../domain/drag-session';
import { phoneToWorld, type FacingSide } from '../../domain/shared-space';
import { HAPTIC } from '../../domain/haptics';
import {
  Easing,
  withSequence,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { tunedSpring } from './spring';
import type { DragController } from './use-drag-controller';

// Positions of PhoneEdge in the protocol.
const EDGE_INDEX_RIGHT = 1;
const EDGE_INDEX_LEFT = 3;
const MAX_TILT_DEGREES = 8;
const MAX_ROTATION_RADIANS = 0.2;
const ROTATION_PER_POINT_PER_SECOND = 0.00012;

export const updateGlow = (drag: DragController, fingerX: number) => {
  'worklet';
  const tuned = drag.tuning.value;
  const activation =
    tuned['proximity.activationPoints'] ?? tokens.proximity.activationPoints;
  const curve = tuned['proximity.curve'] ?? tokens.proximity.curve;
  const left =
    edgeProximity(drag.screenWidth - fingerX, drag.screenWidth, activation) **
    curve;
  const right = edgeProximity(fingerX, drag.screenWidth, activation) ** curve;
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

export const playStageHaptic = (
  drag: DragController,
  previous: DragSession,
  next: DragSession,
) => {
  'worklet';
  if (previous.stage === next.stage) {
    return;
  }
  if (next.stage === 'approaching' && previous.stage !== 'crossing') {
    drag.channel.impact(HAPTIC.light);
  } else if (next.stage === 'crossing') {
    drag.channel.impact(HAPTIC.rigid);
  }
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

const playSweep = (drag: DragController, edge: FacingSide) => {
  'worklet';
  const seconds = drag.tuning.value['sweep.seconds'] ?? tokens.sweep.seconds;
  drag.sweep.fromLeft.value = edge === 'left';
  drag.sweep.palette.value = drag.palette.value;
  drag.sweep.progress.value = 0;
  drag.sweep.progress.value = withTiming(1, {
    duration: seconds * 1000,
    easing: Easing.out(Easing.poly(2.2)),
  });
};

type Settle = {
  readonly crossed: boolean;
  readonly edge: FacingSide;
  readonly velocityX: number;
  readonly home: { readonly pageX: number; readonly pageY: number } | null;
  readonly size: number;
  readonly reduceMotion: boolean;
};

export const settleDrag = (
  drag: DragController,
  { crossed, edge, velocityX, home, size, reduceMotion }: Settle,
) => {
  'worklet';
  const tuned = drag.tuning.value;
  const snapBack = tunedSpring(tuned, 'snapBack');
  if (crossed && !reduceMotion) {
    playSweep(drag, edge);
  }
  if (crossed) {
    drag.x.value = withSpring(
      edge === 'right' ? drag.screenWidth + size : -size,
      { ...tunedSpring(tuned, 'land'), velocity: velocityX },
    );
  } else if (home !== null) {
    drag.x.value = withSpring(home.pageX + size / 2, snapBack);
    drag.y.value = withSpring(home.pageY + size / 2, snapBack);
  }
  drag.rotation.value = withSpring(0, snapBack);
  drag.tiltX.value = withSpring(0, snapBack);
  drag.tiltY.value = withSpring(0, snapBack);
  const glow = edge === 'left' ? drag.leftGlow : drag.rightGlow;
  glow.value =
    crossed && !reduceMotion
      ? withSequence(
          withSpring(
            tuned['effects.flashPeak'] ?? tokens.effects.flashPeak,
            tunedSpring(tuned, 'follow'),
          ),
          withSpring(0, snapBack),
        )
      : withSpring(0, snapBack);
  drag.lift.value = withSpring(0, snapBack, finished => {
    if (finished) {
      drag.activeIndex.value = -1;
    }
  });
};
