import { tokens } from '@lumen/design-tokens';

type SpringToken = { readonly response: number; readonly damping: number };

export const springConfig = ({ response, damping }: SpringToken) => {
  'worklet';
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

type SpringName = keyof typeof tokens.motion.springs;

export const tunedSpring = (
  tuned: Readonly<Record<string, number>>,
  name: SpringName,
) => {
  'worklet';
  const base = tokens.motion.springs[name];
  return springConfig({
    response: tuned[`motion.springs.${name}.response`] ?? base.response,
    damping: tuned[`motion.springs.${name}.damping`] ?? base.damping,
  });
};
