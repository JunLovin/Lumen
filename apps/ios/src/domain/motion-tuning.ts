export type Tunable = {
  readonly path: string;
  readonly min: number;
  readonly max: number;
};

export const TUNABLES: readonly Tunable[] = [
  { path: 'glow.intensity', min: 0, max: 3 },
  { path: 'glow.bandFraction', min: 0.05, max: 1 },
  { path: 'glow.flowSpeed', min: 0, max: 2 },
  { path: 'glow.noiseScale', min: 0.5, max: 10 },
  { path: 'effects.particleAmount', min: 0, max: 1 },
  { path: 'effects.particleCells', min: 5, max: 60 },
  { path: 'effects.particleSpeed', min: 0, max: 2 },
  { path: 'effects.bloom', min: 0, max: 4 },
  { path: 'effects.dissolveEdge', min: 0.02, max: 0.4 },
  { path: 'effects.aberrationPoints', min: 0, max: 12 },
  { path: 'effects.specular', min: 0, max: 1 },
  { path: 'effects.flashPeak', min: 1, max: 2 },
  { path: 'ripple.seconds', min: 0.3, max: 3 },
  { path: 'ripple.wavelengthPoints', min: 10, max: 120 },
  { path: 'ripple.intensity', min: 0, max: 2 },
  { path: 'ripple.phoneRadiusPoints', min: 100, max: 700 },
  { path: 'ripple.macRadiusPoints', min: 100, max: 1200 },
  { path: 'proximity.activationPoints', min: 40, max: 300 },
  { path: 'proximity.curve', min: 0.4, max: 3 },
  { path: 'motion.springs.lift.response', min: 0.1, max: 1 },
  { path: 'motion.springs.lift.damping', min: 0.2, max: 1 },
  { path: 'motion.springs.follow.response', min: 0.05, max: 0.6 },
  { path: 'motion.springs.follow.damping', min: 0.2, max: 1 },
  { path: 'motion.springs.land.response', min: 0.1, max: 1.5 },
  { path: 'motion.springs.land.damping', min: 0.2, max: 1 },
  { path: 'motion.springs.snapBack.response', min: 0.1, max: 1 },
  { path: 'motion.springs.snapBack.damping', min: 0.2, max: 1 },
];

type Tree = { readonly [key: string]: unknown };

const isTree = (value: unknown): value is Tree =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

export const readTokenValue = (tree: Tree, path: string): number | null => {
  const value = path
    .split('.')
    .reduce<unknown>(
      (node, key) => (isTree(node) ? node[key] : undefined),
      tree,
    );
  return typeof value === 'number' ? value : null;
};

const withValue = (
  tree: Tree,
  [key, ...rest]: string[],
  value: number,
): Tree => {
  if (key === undefined) {
    return tree;
  }
  const child = tree[key];
  return {
    ...tree,
    [key]:
      rest.length === 0
        ? value
        : withValue(isTree(child) ? child : {}, rest, value),
  };
};

export const patchTokens = (
  tree: Tree,
  values: Readonly<Record<string, number>>,
): Tree =>
  Object.entries(values).reduce(
    (patched, [path, value]) => withValue(patched, path.split('.'), value),
    tree,
  );
