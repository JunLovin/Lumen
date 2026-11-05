export const HAPTIC = { soft: 0, medium: 1, light: 2, rigid: 3 } as const;
export type HapticStyle = (typeof HAPTIC)[keyof typeof HAPTIC];
