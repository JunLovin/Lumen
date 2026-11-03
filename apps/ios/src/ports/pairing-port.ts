import type { PairingStatus } from '../domain/pairing';

export interface PairingPort {
  read(): Promise<PairingStatus>;
  forget(): void;
}
