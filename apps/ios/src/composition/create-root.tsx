import { StyleSheet } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { createNativeAcousticAdapter } from '../adapters/native-acoustic-adapter';
import { createNativePairingAdapter } from '../adapters/native-pairing-adapter';
import { createNativePeerChannelAdapter } from '../adapters/native-peer-channel-adapter';
import { createRuntimeInfoAdapter } from '../adapters/runtime-info-adapter';
import { createSystemClockAdapter } from '../adapters/system-clock-adapter';
import { createDragFrameSender } from '../application/drag-frame-sender';
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
    probeFileChannel: () => peer.probeFileChannel(),
    dragFrameSender: createDragFrameSender(peer, createSystemClockAdapter()),
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
