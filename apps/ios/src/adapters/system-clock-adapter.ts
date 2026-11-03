import type { ClockPort } from '../ports/clock-port';

export const createSystemClockAdapter = (): ClockPort => ({
  nowMilliseconds: () => Date.now(),
});
