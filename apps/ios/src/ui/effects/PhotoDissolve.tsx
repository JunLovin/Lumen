import { tokens } from '@lumen/design-tokens';
import {
  Canvas,
  ImageShader,
  RoundedRect,
  Shader,
  Skia,
  useImage,
} from '@shopify/react-native-skia';
import { Image, StyleSheet } from 'react-native';
import { useDerivedValue, type SharedValue } from 'react-native-reanimated';
import { NOISE_SKSL } from './noise-sksl';

type Props = {
  readonly uri: string;
  readonly size: number;
  readonly dissolve: SharedValue<number>;
  readonly edgeIsLeft: SharedValue<boolean>;
  readonly tilt: SharedValue<number>;
  readonly palette: SharedValue<readonly number[]>;
};

const CORNER_POINTS = 8;
const MAX_TILT_DEGREES = 8;
const { dissolveEdge, aberrationPoints, bloom, specular } = tokens.effects;

const effect = Skia.RuntimeEffect.Make(`
uniform shader image;
uniform float2 size;
uniform float dissolve;
uniform float edgeIsLeft;
uniform float tilt;
uniform float3 glow;
uniform float dissolveEdge;
uniform float aberration;
uniform float bloom;
uniform float specular;

${NOISE_SKSL}

half4 main(float2 position) {
  float2 uv = position / size;
  float towardEdge = edgeIsLeft > 0.5 ? 1.0 - uv.x : uv.x;
  float grain = noise(uv * 18.0) * 0.6 + noise(uv * 41.0) * 0.4;
  float eaten = dissolve * 1.5 - (1.0 - towardEdge) * 0.5;
  float solid = smoothstep(eaten - dissolveEdge, eaten + dissolveEdge, grain);
  float2 shift = float2(aberration * dissolve * dissolve, 0.0);
  half3 photo = half3(
    image.eval(position + shift).r,
    image.eval(position).g,
    image.eval(position - shift).b
  );
  float band = (uv.x + uv.y) - 1.0 - tilt * 0.7;
  float sheen = specular * exp(-band * band * 18.0);
  float rim = solid * (1.0 - solid) * 4.0;
  half3 color = mix(half3(glow), photo + half3(sheen), half(solid)) + half3(glow) * half(rim * bloom);
  float alpha = max(solid, rim);
  return half4(color * half(alpha), half(alpha));
}
`);

export function PhotoDissolve({
  uri,
  size,
  dissolve,
  edgeIsLeft,
  tilt,
  palette,
}: Props) {
  const image = useImage(uri);
  const uniforms = useDerivedValue(() => ({
    size: [size, size],
    dissolve: Math.min(dissolve.value, 1),
    edgeIsLeft: edgeIsLeft.value ? 1 : 0,
    tilt: tilt.value / MAX_TILT_DEGREES,
    glow: palette.value.slice(0, 3),
    dissolveEdge,
    aberration: aberrationPoints,
    bloom,
    specular,
  }));

  if (effect === null || image === null) {
    return <Image source={{ uri }} style={styles.fallback} />;
  }

  return (
    <Canvas style={StyleSheet.absoluteFill}>
      <RoundedRect x={0} y={0} width={size} height={size} r={CORNER_POINTS}>
        <Shader source={effect} uniforms={uniforms}>
          <ImageShader
            image={image}
            fit="cover"
            x={0}
            y={0}
            width={size}
            height={size}
          />
        </Shader>
      </RoundedRect>
    </Canvas>
  );
}

const styles = StyleSheet.create({
  fallback: { flex: 1, borderRadius: CORNER_POINTS },
});
