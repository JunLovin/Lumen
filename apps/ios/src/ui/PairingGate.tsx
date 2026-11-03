import { useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';
import type { LabUseCases } from '../application/lab-use-cases';
import type { PairingStatus } from '../domain/pairing';
import { RootNavigator } from './RootNavigator';
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
  const foregroundedAt = useRef<number | null>(null);

  useEffect(() => {
    const poll = async () => {
      setStatus(await useCases.readPairingStatus());
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

  return status.stage === 'paired' ? (
    <RootNavigator
      useCases={useCases}
      peerName={status.peerName}
      reconnectMilliseconds={reconnectMilliseconds}
    />
  ) : (
    <PairingScreen status={status} />
  );
}
