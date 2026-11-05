import { createContext, useContext, type ReactNode } from 'react';
import {
  makeMutable,
  useSharedValue,
  type SharedValue,
} from 'react-native-reanimated';
import { DEFAULT_PALETTE } from '../effects/glow-palette';

type Sweep = {
  readonly progress: SharedValue<number>;
  readonly fromLeft: SharedValue<boolean>;
  readonly palette: SharedValue<readonly number[]>;
};

const IDLE: Sweep = {
  progress: makeMutable(1),
  fromLeft: makeMutable(false),
  palette: makeMutable(DEFAULT_PALETTE),
};
const SweepContext = createContext<Sweep>(IDLE);

export const useSweep = () => useContext(SweepContext);

type Props = {
  readonly children: ReactNode;
};

export function SweepProvider({ children }: Props) {
  const progress = useSharedValue(1);
  const fromLeft = useSharedValue(false);
  const palette = useSharedValue<readonly number[]>(DEFAULT_PALETTE);
  return (
    <SweepContext.Provider value={{ progress, fromLeft, palette }}>
      {children}
    </SweepContext.Provider>
  );
}
