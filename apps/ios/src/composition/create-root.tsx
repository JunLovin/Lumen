import { StyleSheet } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { createNativeAcousticAdapter } from '../adapters/native-acoustic-adapter';
import { createNativePairingAdapter } from '../adapters/native-pairing-adapter';
import { createNativePeerChannelAdapter } from '../adapters/native-peer-channel-adapter';
import { createRuntimeInfoAdapter } from '../adapters/runtime-info-adapter';
import { readDeviceModel as NativeDeviceModel } from '../adapters/device-model-adapter';
import { createNativeMediaLibraryAdapter } from '../adapters/native-media-library-adapter';
import { createNativeUIThreadChannel } from '../adapters/native-ui-thread-channel';
import { createLoadGalleryPage } from '../application/load-gallery-page';
import { phoneMetricsFor } from '../domain/phone-metrics';
import type { LabUseCases } from '../application/lab-use-cases';
import { createLoadDiagnostics } from '../application/load-diagnostics';
import {
  createCalibratePlacement,
  createRunPlacementTrial,
} from '../application/run-placement-trial';
import { PairingGate } from '../ui/PairingGate';

const composeUseCases = (): LabUseCases => {
  const peer = createNativePeerChannelAdapter();
  const acoustic = createNativeAcousticAdapter();
  const pairing = createNativePairingAdapter();
  const media = createNativeMediaLibraryAdapter();
  peer.start();
  return {
    loadDiagnostics: createLoadDiagnostics(createRuntimeInfoAdapter()),
    calibratePlacement: createCalibratePlacement(acoustic),
    runPlacementTrial: createRunPlacementTrial(acoustic),
    exportLastRecording: () => acoustic.exportLastRecording(),
    isPeerConnected: () => peer.isConnected(),
    readPairingStatus: () => pairing.read(),
    forgetPairing: () => pairing.forget(),
    reconnectToPeer: () => peer.reconnect(),
    reportEdgeExit: edge => peer.reportEdgeExit(edge),
    readPlacement: () => peer.readPlacement(),
    probeFileChannel: () => peer.probeFileChannel(),
    uiThreadChannel: createNativeUIThreadChannel(),
    phoneMetrics: phoneMetricsFor(NativeDeviceModel()),
    readLibraryAccess: () => media.readAccess(),
    requestLibraryAccess: () => media.requestAccess(),
    loadGalleryPage: createLoadGalleryPage(media),
    loadThumbnail: (assetId, size) => media.loadThumbnail(assetId, size),
    manageLimitedAccess: () => media.manageLimitedAccess(),
    beginDragTransfer: (session, assetId, height) =>
      media.beginDragTransfer(session, assetId, height),
  };
};

export const createRoot = () => {
  const useCases = composeUseCases();

  return function Root() {
    return (
      <GestureHandlerRootView style={styles.root}>
        <SafeAreaProvider>
          <PairingGate useCases={useCases} />
        </SafeAreaProvider>
      </GestureHandlerRootView>
    );
  };
};

const styles = StyleSheet.create({
  root: { flex: 1 },
});
