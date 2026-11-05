import { createContext, useContext, useEffect, type ReactNode } from 'react';
import {
  makeMutable,
  useSharedValue,
  type SharedValue,
} from 'react-native-reanimated';

type Tuning = Readonly<Record<string, number>>;

const POLL_MILLISECONDS = 250;
const NO_TUNING = makeMutable<Tuning>({});
const TuningContext = createContext<SharedValue<Tuning>>(NO_TUNING);

export const useTuning = () => useContext(TuningContext);

type Props = {
  readonly readTuning: () => Promise<Tuning>;
  readonly children: ReactNode;
};

export function TuningProvider({ readTuning, children }: Props) {
  const tuning = useSharedValue<Tuning>({});

  useEffect(() => {
    if (!__DEV__) {
      return;
    }
    const timer = setInterval(async () => {
      tuning.value = await readTuning();
    }, POLL_MILLISECONDS);
    return () => clearInterval(timer);
  }, [readTuning, tuning]);

  return (
    <TuningContext.Provider value={tuning}>{children}</TuningContext.Provider>
  );
}
