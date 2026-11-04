import { tokens } from '@lumen/design-tokens';
import { Canvas, Rect, Shader, useClock } from '@shopify/react-native-skia';
import { StyleSheet } from 'react-native';
import {
  useDerivedValue,
  useReducedMotion,
  type SharedValue,
} from 'react-native-reanimated';
import { edgeGlowEffect } from './edge-glow-shader';
import { DEFAULT_PALETTE } from './glow-palette';

type Props = {
  readonly width: number;
  readonly height: number;
  readonly proximity: SharedValue<number>;
  readonly palette?: SharedValue<readonly number[]>;
};

const { glow, effects } = tokens;
const STRIP_WIDTH = glow.overlayWidthPoints;

export function EdgeGlow({ width, height, proximity, palette }: Props) {
  const clock = useClock();
  const reduceMotion = useReducedMotion();
  const uniforms = useDerivedValue(() => {
    const colors = palette?.value ?? DEFAULT_PALETTE;
    return {
      resolution: [STRIP_WIDTH, height],
      time: clock.value / 1000,
      proximity: proximity.value,
      bandFraction: glow.bandFraction,
      intensity: glow.intensity,
      flowSpeed: reduceMotion ? 0 : glow.flowSpeed,
      noiseScale: glow.noiseScale,
      particleAmount: reduceMotion ? 0 : effects.particleAmount,
      particleCells: effects.particleCells,
      particleSpeed: effects.particleSpeed,
      primary: colors.slice(0, 3),
      secondary: colors.slice(3, 6),
      highlight: colors.slice(6, 9),
    };
  });

  if (edgeGlowEffect === null) {
    return null;
  }

  return (
    <Canvas
      pointerEvents="none"
      style={[StyleSheet.absoluteFill, { left: width - STRIP_WIDTH }]}
    >
      <Rect x={0} y={0} width={STRIP_WIDTH} height={height}>
        <Shader source={edgeGlowEffect} uniforms={uniforms} />
      </Rect>
    </Canvas>
  );
}
