import type { PairingStatus } from '../domain/pairing';
import type { PeerPlacement, PhoneEdge } from '../domain/peer-placement';
import type { DragFrameSender } from './drag-frame-sender';
import type { LoadDiagnostics } from './load-diagnostics';
import type {
  CalibratePlacement,
  RunPlacementTrial,
} from './run-placement-trial';

export type LabUseCases = {
  readonly loadDiagnostics: LoadDiagnostics;
  readonly calibratePlacement: CalibratePlacement;
  readonly runPlacementTrial: RunPlacementTrial;
  readonly exportLastRecording: () => Promise<string | null>;
  readonly isPeerConnected: () => Promise<boolean>;
  readonly readPairingStatus: () => Promise<PairingStatus>;
  readonly forgetPairing: () => void;
  readonly reconnectToPeer: () => void;
  readonly reportEdgeExit: (edge: PhoneEdge) => void;
  readonly readPlacement: () => Promise<PeerPlacement>;
  readonly probeFileChannel: () => Promise<boolean>;
  readonly dragFrameSender: DragFrameSender;
};
