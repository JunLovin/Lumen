import {
  PHONE_EDGES,
  PLACEMENT_SIDES,
  type PeerPlacement,
} from '../domain/peer-placement';
import { PLACEMENT_FAILURES } from '../domain/placement';
import type { PeerChannelPort } from '../ports/peer-channel-port';
import NativeLumenKit, {
  type NativePlacementStatus,
} from './native/NativeLumenKit';

const toPlacement = (status: NativePlacementStatus): PeerPlacement => ({
  locateMilliseconds: status.locateMilliseconds ?? null,
  side: PLACEMENT_SIDES[status.side] ?? 'unknown',
  confidence: status.confidence,
  probabilities: status.probabilities,
  isDetached: status.isDetached,
  facingEdge: PHONE_EDGES[status.facingEdge] ?? null,
  locationFailure:
    status.locationFailure === undefined
      ? null
      : (PLACEMENT_FAILURES.find(
          failure => failure === status.locationFailure,
        ) ?? 'unknown'),
});

export const createNativePeerChannelAdapter = (): PeerChannelPort => ({
  start: () => NativeLumenKit.startLink(),
  isConnected: () => NativeLumenKit.linkStatus(),
  reconnect: () => NativeLumenKit.reconnect(),
  reportEdgeExit: edge =>
    NativeLumenKit.reportEdgeExit(PHONE_EDGES.indexOf(edge)),
  readPlacement: async () =>
    toPlacement(await NativeLumenKit.placementStatus()),
  probeFileChannel: () => NativeLumenKit.probeFileChannel(),
  sendTuning: (name, value) => NativeLumenKit.sendTuning(name, value),
  readTuning: async () =>
    (await NativeLumenKit.readTuning()) as Readonly<Record<string, number>>,
  hasSeenOnboarding: () => NativeLumenKit.hasSeenOnboarding(),
  markOnboardingSeen: () => NativeLumenKit.markOnboardingSeen(),
});
