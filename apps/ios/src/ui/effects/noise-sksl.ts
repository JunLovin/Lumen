export const NOISE_SKSL = `
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
`;
