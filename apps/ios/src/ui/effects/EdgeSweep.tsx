import { tokens } from '@lumen/design-tokens';
import { Canvas, Fill, Shader, Skia } from '@shopify/react-native-skia';
import { StyleSheet, useWindowDimensions } from 'react-native';
import { useDerivedValue } from 'react-native-reanimated';
import { useSweep } from '../motion/SweepContext';
import { useTuning } from '../motion/TuningContext';
import { NOISE_SKSL } from './noise-sksl';

const { sweep: sweepTokens } = tokens;

const effect = Skia.RuntimeEffect.Make(`
uniform float2 resolution;
uniform float progress;
uniform float fromLeft;
uniform float band;
uniform float intensity;
uniform float3 glow;

${NOISE_SKSL}

half4 main(float2 position) {
  float x = fromLeft > 0.5 ? position.x : resolution.x - position.x;
  float y = position.y / resolution.y;
  float sway = (noise(float2(y * 3.0, progress * 2.0)) - 0.5) * band * 3.0;
  float behind = progress * resolution.x * 1.25 + sway - x;
  float crest = exp(-behind * behind / (band * band * 0.6));
  float ripples = pow(0.5 + 0.5 * cos(behind / band * 6.2832), 2.0);
  float wake = behind > 0.0 ? exp(-behind / (band * 5.0)) * ripples * 0.45 : 0.0;
  float fade = 1.0 - smoothstep(0.8, 1.0, progress);
  float light = clamp(intensity * (crest + wake) * fade, 0.0, 1.0);
  float3 color = mix(glow, float3(1.0), crest * 0.6);
  return half4(half3(color * light), half(light));
}
`);

export function EdgeSweep() {
  const { width, height } = useWindowDimensions();
  const { progress, fromLeft, palette } = useSweep();
  const tuning = useTuning();
  const uniforms = useDerivedValue(() => ({
    resolution: [width, height],
    progress: progress.value,
    fromLeft: fromLeft.value ? 1 : 0,
    band: tuning.value['sweep.bandPoints'] ?? sweepTokens.bandPoints,
    intensity: tuning.value['sweep.intensity'] ?? sweepTokens.intensity,
    glow: palette.value.slice(0, 3),
  }));

  if (effect === null) {
    return null;
  }

  return (
    <Canvas pointerEvents="none" style={StyleSheet.absoluteFill}>
      <Fill>
        <Shader source={effect} uniforms={uniforms} />
      </Fill>
    </Canvas>
  );
}
