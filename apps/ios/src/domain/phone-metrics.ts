export type PhoneMetrics = {
  readonly pointsPerMillimeter: number;
};

// Points per millimeter is ppi / scale / 25.4: 460 ppi at 3x for nearly every current iPhone,
// 476 ppi at 3x for the mini models and 326 ppi at 2x for the SE.
const STANDARD = 6.037;
const MINI = 6.247;
const SE = 6.417;

const EXCEPTIONS: Readonly<Record<string, number>> = {
  'iPhone13,1': MINI,
  'iPhone14,4': MINI,
  'iPhone12,8': SE,
  'iPhone14,6': SE,
};

export const phoneMetricsFor = (model: string): PhoneMetrics => ({
  pointsPerMillimeter: EXCEPTIONS[model] ?? STANDARD,
});
