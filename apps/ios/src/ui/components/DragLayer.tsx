import { Image, StyleSheet, View } from 'react-native';
import Animated, { useAnimatedStyle } from 'react-native-reanimated';
import { EdgeGlow } from '../effects/EdgeGlow';
import { labTheme } from '../lab-theme';
import type { DragController } from '../motion/use-drag-controller';

type Props = {
  readonly drag: DragController;
  readonly uri: string | null;
  readonly size: number;
};

const LIFT_SCALE = 1.06;
const DIM_OPACITY = 0.55;
const SHADOW_OPACITY = 0.5;
const SHADOW_RADIUS_POINTS = 24;
const PERSPECTIVE_POINTS = 600;
const FADE_AT_EDGE = 0.65;
// Pivoting behind the photo keeps its whole surface in front of its siblings; pivoting on the
// photo itself sends half of it behind them when tilted.
const PIVOT_DEPTH_POINTS = -120;
const PIVOT_SCALE_COMPENSATION =
  (PERSPECTIVE_POINTS + PIVOT_DEPTH_POINTS) / PERSPECTIVE_POINTS;

export function DragLayer({ drag, uri, size }: Props) {
  const dimStyle = useAnimatedStyle(() => ({
    opacity: drag.lift.value * DIM_OPACITY,
  }));

  const photoStyle = useAnimatedStyle(() => {
    const proximity = Math.max(drag.leftGlow.value, drag.rightGlow.value);
    return {
      opacity: drag.activeIndex.value < 0 ? 0 : 1 - proximity * FADE_AT_EDGE,
      transformOrigin: ['50%', '50%', PIVOT_DEPTH_POINTS],
      shadowOpacity: drag.lift.value * SHADOW_OPACITY,
      shadowRadius: drag.lift.value * SHADOW_RADIUS_POINTS,
      transform: [
        { translateX: drag.x.value - size / 2 },
        { translateY: drag.y.value - size / 2 - drag.layerTop.value },
        { perspective: PERSPECTIVE_POINTS },
        { rotateX: `${drag.tiltX.value}deg` },
        { rotateY: `${drag.tiltY.value}deg` },
        { rotateZ: `${drag.rotation.value}rad` },
        {
          scale:
            PIVOT_SCALE_COMPENSATION * (1 + (LIFT_SCALE - 1) * drag.lift.value),
        },
      ],
    };
  });

  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      <Animated.View style={[styles.dim, dimStyle]} />
      <EdgeGlow
        width={drag.screenWidth}
        height={drag.screenHeight}
        proximity={drag.rightGlow}
      />
      <View style={[StyleSheet.absoluteFill, styles.mirrored]}>
        <EdgeGlow
          width={drag.screenWidth}
          height={drag.screenHeight}
          proximity={drag.leftGlow}
        />
      </View>
      <Animated.View
        style={[styles.photo, { width: size, height: size }, photoStyle]}
      >
        {uri !== null && <Image source={{ uri }} style={styles.image} />}
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  dim: { ...StyleSheet.absoluteFill, backgroundColor: labTheme.background },
  mirrored: { transform: [{ scaleX: -1 }] },
  photo: {
    position: 'absolute',
    top: 0,
    left: 0,
    shadowColor: labTheme.background,
    shadowOffset: { width: 0, height: 12 },
  },
  image: { flex: 1, borderRadius: 8 },
});
