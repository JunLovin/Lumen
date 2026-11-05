import { useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';
import type { LabUseCases } from '../application/lab-use-cases';
import type { PairingStatus } from '../domain/pairing';
import { TuningProvider } from './motion/TuningContext';
import { RootNavigator } from './RootNavigator';
import { OnboardingScreen } from './screens/OnboardingScreen';
import { PairingScreen } from './screens/PairingScreen';

type Props = {
  readonly useCases: LabUseCases;
};

const PAIRING_POLL_MILLISECONDS = 250;

export function PairingGate({ useCases }: Props) {
  const [status, setStatus] = useState<PairingStatus>({ stage: 'idle' });
  const [reconnectMilliseconds, setReconnectMilliseconds] = useState<
    number | null
  >(null);
  const foregroundedAt = useRef<number | null>(Date.now());
  const [needsOnboarding, setNeedsOnboarding] = useState(
    () => !useCases.hasSeenOnboarding(),
  );

  useEffect(() => {
    const poll = async () => {
      const nextStatus = await useCases.readPairingStatus();
      setStatus(nextStatus);
      if (nextStatus.stage === 'searching') {
        foregroundedAt.current = null;
      }
      const startedAt = foregroundedAt.current;
      if (startedAt !== null && (await useCases.isPeerConnected())) {
        foregroundedAt.current = null;
        setReconnectMilliseconds(Date.now() - startedAt);
      }
    };
    const timer = setInterval(poll, PAIRING_POLL_MILLISECONDS);
    const subscription = AppState.addEventListener('change', state => {
      if (state === 'active') {
        foregroundedAt.current = Date.now();
        useCases.reconnectToPeer();
      }
    });
    return () => {
      clearInterval(timer);
      subscription.remove();
    };
  }, [useCases]);

  if (status.stage !== 'paired') {
    return <PairingScreen status={status} />;
  }

  return (
    <TuningProvider readTuning={useCases.readTuning}>
      {needsOnboarding ? (
        <OnboardingScreen
          onDone={() => {
            useCases.markOnboardingSeen();
            setNeedsOnboarding(false);
          }}
        />
      ) : (
        <RootNavigator
          useCases={useCases}
          peerName={status.peerName}
          reconnectMilliseconds={reconnectMilliseconds}
        />
      )}
    </TuningProvider>
  );
}
