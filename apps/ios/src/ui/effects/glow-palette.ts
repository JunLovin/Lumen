import { tokens } from '@lumen/design-tokens';

const { primary, secondary, highlight } = tokens.glow.palette;
const CHANNELS = 9;

export const DEFAULT_PALETTE: readonly number[] = [
  ...primary,
  ...secondary,
  ...highlight,
];

export const usablePalette = (colors: readonly number[]): readonly number[] =>
  colors.length === CHANNELS ? colors : DEFAULT_PALETTE;
