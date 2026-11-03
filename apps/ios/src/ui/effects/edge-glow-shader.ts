import { Skia } from '@shopify/react-native-skia';

const SOURCE = `
uniform float2 resolution;
uniform float time;
uniform float proximity;
uniform float bandFraction;
uniform float intensity;
uniform float flowSpeed;
uniform float noiseScale;
uniform float3 primary;
uniform float3 secondary;
uniform float3 highlight;

float hash(float2 p) {
  return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float noise(float2 p) {
  float2 cell = floor(p);
  float2 f = fract(p);
  float2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(cell), hash(cell + float2(1.0, 0.0)), u.x),
             mix(hash(cell + float2(0.0, 1.0)), hash(cell + float2(1.0, 1.0)), u.x), u.y);
}

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
  return half4(half3(color * alpha), half(alpha));
}
`;

export const edgeGlowEffect = Skia.RuntimeEffect.Make(SOURCE);
