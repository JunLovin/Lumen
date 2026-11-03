import type { PairingStatus } from '../domain/pairing';
import type { PairingPort } from '../ports/pairing-port';
import NativeLumenKit, {
  type NativePairingStatus,
} from './native/NativeLumenKit';

const toStatus = (status: NativePairingStatus): PairingStatus => {
  switch (status.stage) {
    case 'searching':
    case 'exchanging':
    case 'failed':
      return { stage: status.stage };
    case 'awaitingConfirmation':
      return { stage: status.stage, pattern: status.pattern ?? [] };
    case 'paired':
      return { stage: status.stage, peerName: status.peerName ?? '' };
    default:
      return { stage: 'idle' };
  }
};

export const createNativePairingAdapter = (): PairingPort => ({
  read: async () => toStatus(await NativeLumenKit.pairingStatus()),
  forget: () => NativeLumenKit.forgetPairing(),
});
