import { tokens } from '@lumen/design-tokens';
import { Canvas, Fill, Shader, Skia } from '@shopify/react-native-skia';
import { StyleSheet } from 'react-native';
import { useDerivedValue, type SharedValue } from 'react-native-reanimated';
import { useTuning } from '../motion/TuningContext';

type Props = {
  readonly progress: SharedValue<number>;
  readonly x: SharedValue<number>;
  readonly y: SharedValue<number>;
  readonly palette: SharedValue<readonly number[]>;
};

const { ripple } = tokens;

const effect = Skia.RuntimeEffect.Make(`
uniform float2 center;
uniform float progress;
uniform float radius;
uniform float wavelength;
uniform float intensity;
uniform float3 glow;

half4 main(float2 position) {
  float reach = length(position - center);
  float edgeFade = 1.0 - smoothstep(radius * 0.7, radius, reach);
  float phase = (reach - progress * radius) / wavelength;
  float packet = exp(-phase * phase * 0.22);
  float crest = pow(0.5 + 0.5 * cos(phase * 6.2832), 3.0);
  float decay = (1.0 - progress) * (1.0 - progress);
  float light = clamp(intensity * packet * crest * decay * edgeFade, 0.0, 1.0);
  float3 color = mix(glow, float3(1.0), crest * 0.5);
  return half4(half3(color * light), half(light));
}
`);

export function DropRipple({ progress, x, y, palette }: Props) {
  const tuning = useTuning();
  const uniforms = useDerivedValue(() => ({
    center: [x.value, y.value],
    progress: progress.value,
    radius:
      tuning.value['ripple.phoneRadiusPoints'] ?? ripple.phoneRadiusPoints,
    wavelength:
      tuning.value['ripple.wavelengthPoints'] ?? ripple.wavelengthPoints,
    intensity: tuning.value['ripple.intensity'] ?? ripple.intensity,
    glow: palette.value.slice(0, 3),
  }));

  if (effect === null) {
    return null;
  }

  return (
    <Canvas style={StyleSheet.absoluteFill}>
      <Fill>
        <Shader source={effect} uniforms={uniforms} />
      </Fill>
    </Canvas>
  );
}
