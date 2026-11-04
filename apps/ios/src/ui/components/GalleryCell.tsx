import { useEffect, useState } from 'react';
import { Image, StyleSheet } from 'react-native';
import { GestureDetector, usePanGesture } from 'react-native-gesture-handler';
import Animated, {
  measure,
  useAnimatedRef,
  useAnimatedStyle,
  useReducedMotion,
  withSpring,
} from 'react-native-reanimated';
import { scheduleOnRN } from 'react-native-worklets';
import type { MediaAsset } from '../../domain/media';
import { advanceDragSession } from '../../domain/drag-session';
import { crossingFraction } from '../../domain/edge-proximity';
import { HAPTIC } from '../../domain/haptics';
import {
  playStageHaptic,
  sendDragFrame,
  settleDrag,
  startRipple,
  updateGlow,
  updateTilt,
} from '../motion/drag-worklets';
import { tunedSpring } from '../motion/spring';
import type { DragController } from '../motion/use-drag-controller';

type Props = {
  readonly asset: MediaAsset;
  readonly index: number;
  readonly columns: number;
  readonly size: number;
  readonly drag: DragController;
  readonly loadThumbnail: (
    assetId: string,
    size: number,
  ) => Promise<string | null>;
  readonly onLift: (uri: string | null) => void;
};

const LONG_PRESS_MILLISECONDS = 300;
const THUMBNAIL_PIXELS = 400;
const GAP_POINTS = 1;
const REPULSION_RADIUS_POINTS = 170;
const REPULSION_POINTS = 14;
// A photo must be clearly past the edge to cross; an accidental graze returns to the gallery.
const CROSSING_DEAD_ZONE = 0.25;
const SPECULATIVE_UPLOAD_PROXIMITY = 0.5;

export function GalleryCell({
  asset,
  index,
  columns,
  size,
  drag,
  loadThumbnail,
  onLift,
}: Props) {
  const [uri, setUri] = useState<string | null>(null);
  const reference = useAnimatedRef<Animated.View>();
  const reduceMotion = useReducedMotion();

  useEffect(() => {
    let isCurrent = true;
    loadThumbnail(asset.id, THUMBNAIL_PIXELS).then(loaded => {
      if (isCurrent) {
        setUri(loaded);
      }
    });
    return () => {
      isCurrent = false;
    };
  }, [asset.id, loadThumbnail]);

  const pan = usePanGesture({
    activateAfterLongPress: LONG_PRESS_MILLISECONDS,
    onActivate: event => {
      const frame = measure(reference);
      if (frame !== null) {
        const row = Math.floor(index / columns);
        drag.gridOffsetY.value =
          frame.pageY - (row * size - drag.scrollY.value);
      }
      const layer = measure(drag.layerRef);
      if (layer !== null) {
        drag.layerTop.value = layer.pageY;
      }
      drag.session.value += 1;
      drag.sequence.value = 0;
      drag.activeIndex.value = index;
      drag.x.value = event.absoluteX;
      drag.y.value = event.absoluteY;
      drag.lift.value = withSpring(1, tunedSpring(drag.tuning.value, 'lift'));
      if (!reduceMotion) {
        startRipple(
          drag,
          event.absoluteX,
          event.absoluteY - drag.layerTop.value,
        );
      }
      drag.channel.impact(HAPTIC.soft);
      drag.dragSession.value = advanceDragSession(
        { stage: 'idle' },
        { type: 'lift' },
      );
      scheduleOnRN(drag.beginTransfer, drag.session.value, asset.id);
      scheduleOnRN(onLift, uri);
    },
    onUpdate: event => {
      drag.x.value = withSpring(
        event.absoluteX,
        tunedSpring(drag.tuning.value, 'follow'),
      );
      drag.y.value = withSpring(
        event.absoluteY,
        tunedSpring(drag.tuning.value, 'follow'),
      );
      if (!reduceMotion) {
        updateTilt(drag, event.absoluteX, event.absoluteY, event.velocityX);
      }
      const { edge, proximity } = updateGlow(drag, event.absoluteX);
      drag.lastEdge.value = edge;
      if (
        proximity > SPECULATIVE_UPLOAD_PROXIMITY &&
        !drag.uploadStarted.value
      ) {
        drag.uploadStarted.value = true;
        drag.channel.startUpload(drag.session.value);
      }
      const previous = drag.dragSession.value;
      const next = advanceDragSession(previous, {
        type: 'moved',
        proximity,
        crossingFraction: Math.max(
          crossingFraction(event.absoluteX, edge, drag.screenWidth, size) -
            CROSSING_DEAD_ZONE,
          0,
        ),
      });
      playStageHaptic(drag, previous, next);
      drag.dragSession.value = next;
      sendDragFrame(
        drag,
        event.absoluteX,
        event.absoluteY,
        event.velocityX,
        event.velocityY,
        edge,
        proximity,
        size,
      );
    },
    onDeactivate: event => {
      const released = advanceDragSession(drag.dragSession.value, {
        type: 'release',
      });
      drag.dragSession.value = { stage: 'idle' };
      const edge = drag.lastEdge.value;
      const crossed = released.stage === 'released';
      const perMillimeter = drag.pointsPerMillimeter;
      drag.channel.endDrag(
        drag.session.value,
        crossed,
        (edge === 'right' ? event.velocityX : -event.velocityX) / perMillimeter,
        event.velocityY / perMillimeter,
      );
      if (crossed) {
        scheduleOnRN(drag.reportEdgeExit, edge);
      } else {
        drag.channel.impact(HAPTIC.soft);
      }
      settleDrag(drag, {
        crossed,
        edge,
        velocityX: event.velocityX,
        home: crossed ? null : measure(reference),
        size,
        reduceMotion,
      });
    },
  });

  const style = useAnimatedStyle(() => {
    if (drag.activeIndex.value === index) {
      return { opacity: 0, transform: [{ translateX: 0 }, { translateY: 0 }] };
    }
    const column = index % columns;
    const row = Math.floor(index / columns);
    const centerX = column * size + size / 2;
    const centerY =
      row * size + size / 2 - drag.scrollY.value + drag.gridOffsetY.value;
    const deltaX = centerX - drag.x.value;
    const deltaY = centerY - drag.y.value;
    const distance = Math.max(Math.hypot(deltaX, deltaY), 1);
    const strength =
      Math.max(1 - distance / REPULSION_RADIUS_POINTS, 0) * drag.lift.value;
    return {
      opacity: 1,
      transform: [
        { translateX: (deltaX / distance) * strength * REPULSION_POINTS },
        { translateY: (deltaY / distance) * strength * REPULSION_POINTS },
      ],
    };
  });

  return (
    <GestureDetector gesture={pan}>
      <Animated.View
        ref={reference}
        style={[
          {
            width: size - GAP_POINTS,
            height: size - GAP_POINTS,
            margin: GAP_POINTS / 2,
          },
          style,
        ]}
      >
        {uri !== null && <Image source={{ uri }} style={styles.image} />}
      </Animated.View>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  image: { flex: 1 },
});
