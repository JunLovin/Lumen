export type PairingStatus =
  | { readonly stage: 'idle' | 'searching' | 'exchanging' | 'failed' }
  | {
      readonly stage: 'awaitingConfirmation';
      readonly pattern: readonly number[];
    }
  | { readonly stage: 'paired'; readonly peerName: string };
