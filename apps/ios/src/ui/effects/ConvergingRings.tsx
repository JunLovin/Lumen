import { tokens } from '@lumen/design-tokens';
import { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { labTheme } from '../lab-theme';

type RingProps = {
  readonly size: number;
  readonly offset: number;
};

const { ringCount, ringCycleSeconds } = tokens.pairing;

function Ring({ size, offset }: RingProps) {
  const progress = useSharedValue(0);
  const reduceMotion = useReducedMotion();

  useEffect(() => {
    if (!reduceMotion) {
      progress.value = withRepeat(
        withTiming(1, {
          duration: ringCycleSeconds * 1000,
          easing: Easing.linear,
        }),
        -1,
      );
    }
  }, [progress, reduceMotion]);

  const style = useAnimatedStyle(() => {
    const phase = (progress.value + offset) % 1;
    return { opacity: phase, transform: [{ scale: 1 - phase }] };
  });

  return (
    <Animated.View
      style={[
        styles.ring,
        { width: size, height: size, borderRadius: size / 2 },
        style,
      ]}
    />
  );
}

export function ConvergingRings({ size }: { readonly size: number }) {
  return (
    <View style={{ width: size, height: size }}>
      {Array.from({ length: ringCount }, (_, index) => (
        <Ring key={index} size={size} offset={index / ringCount} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  ring: { position: 'absolute', borderWidth: 2, borderColor: labTheme.accent },
});
