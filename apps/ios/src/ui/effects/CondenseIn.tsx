import { tokens } from '@lumen/design-tokens';
import { useEffect, type ReactNode } from 'react';
import { StyleSheet, type StyleProp, type ViewStyle } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { springs } from '../motion/spring';

type Props = {
  readonly style: StyleProp<ViewStyle>;
  readonly children: ReactNode;
};

const START_SCALE = 0.88;
const [red, green, blue] = tokens.glow.palette.primary;
const lightColor = `rgb(${red * 255}, ${green * 255}, ${blue * 255})`;

export function CondenseIn({ style, children }: Props) {
  const reduceMotion = useReducedMotion();
  const condensed = useSharedValue(reduceMotion ? 1 : 0);

  useEffect(() => {
    condensed.value = withSpring(1, springs.land);
  }, [condensed]);

  const rowStyle = useAnimatedStyle(() => ({
    opacity: Math.min(condensed.value * 2, 1),
    transform: [{ scale: START_SCALE + (1 - START_SCALE) * condensed.value }],
  }));
  const lightStyle = useAnimatedStyle(() => ({
    opacity: Math.max(1 - condensed.value, 0),
  }));

  return (
    <Animated.View style={[style, rowStyle]}>
      {children}
      <Animated.View
        pointerEvents="none"
        style={[StyleSheet.absoluteFill, styles.light, lightStyle]}
      />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  light: { backgroundColor: lightColor, borderRadius: 8 },
});
