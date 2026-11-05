import { tokens } from '@lumen/design-tokens';
import { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, {
  cancelAnimation,
  Easing,
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import type { PeerPlacement } from '../../domain/peer-placement';

type Props = {
  readonly readPlacement: () => Promise<PeerPlacement>;
  readonly isPeerConnected: () => Promise<boolean>;
};

const POLL_MILLISECONDS = 1000;
const { minConfidence, phoneWidthPoints, restOpacity, peakOpacity } =
  tokens.presence;
const breathMilliseconds = (tokens.motion.cycles.glowBreath.seconds * 1000) / 2;
const [red, green, blue] = tokens.glow.palette.primary;
const auraColor = `rgb(${red * 255}, ${green * 255}, ${blue * 255})`;

type AuraEdge = 'left' | 'right';

// A view's opacity is composited natively; the shader glow would redraw at 120 Hz while idle.
export function PresenceAura({ readPlacement, isPeerConnected }: Props) {
  const [edge, setEdge] = useState<AuraEdge | null>(null);
  const reduceMotion = useReducedMotion();
  const breath = useSharedValue<number>(restOpacity);

  useEffect(() => {
    const poll = async () => {
      const [placement, connected] = await Promise.all([
        readPlacement(),
        isPeerConnected(),
      ]);
      const facing = placement.facingEdge;
      const isSure = connected && placement.confidence >= minConfidence;
      setEdge(
        isSure && (facing === 'left' || facing === 'right') ? facing : null,
      );
    };
    poll();
    const timer = setInterval(poll, POLL_MILLISECONDS);
    return () => clearInterval(timer);
  }, [isPeerConnected, readPlacement]);

  const isVisible = edge !== null;

  useEffect(() => {
    if (!isVisible || reduceMotion) {
      cancelAnimation(breath);
      breath.value = restOpacity;
      return;
    }
    breath.value = withRepeat(
      withTiming(peakOpacity, {
        duration: breathMilliseconds,
        easing: Easing.inOut(Easing.sin),
      }),
      -1,
      true,
    );
  }, [breath, isVisible, reduceMotion]);

  const style = useAnimatedStyle(() => ({ opacity: breath.value }));

  if (edge === null) {
    return null;
  }

  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      <Animated.View
        style={[
          styles.line,
          edge === 'left' ? styles.left : styles.right,
          style,
        ]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  line: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    width: phoneWidthPoints,
    backgroundColor: auraColor,
    shadowColor: auraColor,
    shadowOpacity: 1,
    shadowRadius: 6,
  },
  left: { left: 0 },
  right: { right: 0 },
});
