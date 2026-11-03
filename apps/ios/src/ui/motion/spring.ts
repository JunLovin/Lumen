import { tokens } from '@lumen/design-tokens';

type SpringToken = { readonly response: number; readonly damping: number };

export const springConfig = ({ response, damping }: SpringToken) => {
  const angularFrequency = (2 * Math.PI) / response;
  return {
    mass: 1,
    stiffness: angularFrequency * angularFrequency,
    damping: 2 * damping * angularFrequency,
  };
};

export const springs = {
  lift: springConfig(tokens.motion.springs.lift),
  follow: springConfig(tokens.motion.springs.follow),
  land: springConfig(tokens.motion.springs.land),
  snapBack: springConfig(tokens.motion.springs.snapBack),
};
