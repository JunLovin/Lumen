import { tokens } from '@lumen/design-tokens';
import { Canvas, Rect, Shader, useClock } from '@shopify/react-native-skia';
import { StyleSheet } from 'react-native';
import { useDerivedValue, type SharedValue } from 'react-native-reanimated';
import { edgeGlowEffect } from './edge-glow-shader';

type Props = {
  readonly width: number;
  readonly height: number;
  readonly proximity: SharedValue<number>;
};

const { glow } = tokens;
const STRIP_WIDTH = glow.overlayWidthPoints;

export function EdgeGlow({ width, height, proximity }: Props) {
  const clock = useClock();
  const uniforms = useDerivedValue(() => ({
    resolution: [STRIP_WIDTH, height],
    time: clock.value / 1000,
    proximity: proximity.value,
    bandFraction: glow.bandFraction,
    intensity: glow.intensity,
    flowSpeed: glow.flowSpeed,
    noiseScale: glow.noiseScale,
    primary: [...glow.palette.primary],
    secondary: [...glow.palette.secondary],
    highlight: [...glow.palette.highlight],
  }));

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
