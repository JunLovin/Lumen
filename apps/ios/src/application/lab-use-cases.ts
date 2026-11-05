import type { LibraryAccess } from '../domain/media';
import type { PairingStatus } from '../domain/pairing';
import type { PhoneMetrics } from '../domain/phone-metrics';
import type { UIThreadChannelPort } from '../ports/ui-thread-channel-port';
import type { LoadGalleryPage } from './load-gallery-page';
import type { PeerPlacement, PhoneEdge } from '../domain/peer-placement';
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
  readonly uiThreadChannel: UIThreadChannelPort;
  readonly phoneMetrics: PhoneMetrics;
  readonly readLibraryAccess: () => Promise<LibraryAccess>;
  readonly requestLibraryAccess: () => Promise<LibraryAccess>;
  readonly loadGalleryPage: LoadGalleryPage;
  readonly loadThumbnail: (
    assetId: string,
    size: number,
  ) => Promise<string | null>;
  readonly manageLimitedAccess: () => void;
};

export type { UIThreadChannelPort };
