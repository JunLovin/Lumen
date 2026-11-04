import { Skia } from '@shopify/react-native-skia';
import { NOISE_SKSL } from './noise-sksl';

const SOURCE = `
uniform float2 resolution;
uniform float time;
uniform float proximity;
uniform float bandFraction;
uniform float intensity;
uniform float flowSpeed;
uniform float noiseScale;
uniform float particleAmount;
uniform float particleCells;
uniform float particleSpeed;
uniform float3 primary;
uniform float3 secondary;
uniform float3 highlight;

${NOISE_SKSL}

float fbm(float2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int octave = 0; octave < 4; octave++) {
    value += amplitude * noise(p);
    p *= 2.02;
    amplitude *= 0.5;
  }
  return value;
}

float sparks(float2 uv, float distanceToEdge) {
  float2 grid = float2(uv.y * particleCells, distanceToEdge * particleCells * 0.5 - time * particleSpeed * particleCells * 0.25);
  float2 cell = floor(grid);
  float seed = hash(cell);
  float2 center = float2(0.3 + 0.4 * hash(cell + 7.0), 0.5);
  return smoothstep(0.22, 0.0, length(fract(grid) - center)) * step(0.72, seed);
}

half4 main(float2 position) {
  float2 uv = position / resolution;
  float distanceToEdge = 1.0 - uv.x;
  float band = max(bandFraction * proximity, 0.001);
  float flow = fbm(float2(uv.y * noiseScale, distanceToEdge * noiseScale - time * flowSpeed));
  float falloff = exp(-distanceToEdge / (band * (0.5 + flow)));
  float stripFade = 1.0 - smoothstep(0.6, 1.0, distanceToEdge);
  float alpha = clamp(intensity * proximity * falloff, 0.0, 1.0) * stripFade;
  float3 color = mix(primary, secondary, flow);
  color = mix(color, highlight, falloff * falloff * 0.6);
  float spark = sparks(uv, distanceToEdge) * particleAmount * proximity * proximity * stripFade;
  color = mix(color, highlight, spark);
  alpha = clamp(alpha + spark, 0.0, 1.0);
  return half4(half3(color * alpha), half(alpha));
}
`;

export const edgeGlowEffect = Skia.RuntimeEffect.Make(SOURCE);
