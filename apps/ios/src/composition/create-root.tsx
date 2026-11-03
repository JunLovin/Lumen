import { StyleSheet } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { createNativeAcousticAdapter } from '../adapters/native-acoustic-adapter';
import { createNativePeerChannelAdapter } from '../adapters/native-peer-channel-adapter';
import { createRuntimeInfoAdapter } from '../adapters/runtime-info-adapter';
import { createSystemClockAdapter } from '../adapters/system-clock-adapter';
import { createDragFrameSender } from '../application/drag-frame-sender';
import type { LabUseCases } from '../application/lab-use-cases';
import { createLoadDiagnostics } from '../application/load-diagnostics';
import { createRunPlacementTrial } from '../application/run-placement-trial';
import { RootNavigator } from '../ui/RootNavigator';

const composeUseCases = (): LabUseCases => {
  const peer = createNativePeerChannelAdapter();
  const acoustic = createNativeAcousticAdapter();
  peer.start();
  return {
    loadDiagnostics: createLoadDiagnostics(createRuntimeInfoAdapter()),
    runPlacementTrial: createRunPlacementTrial(acoustic),
    exportLastRecording: () => acoustic.exportLastRecording(),
    isPeerConnected: () => peer.isConnected(),
    dragFrameSender: createDragFrameSender(peer, createSystemClockAdapter()),
  };
};

export const createRoot = () => {
  const useCases = composeUseCases();

  return function Root() {
    return (
      <GestureHandlerRootView style={styles.root}>
        <SafeAreaProvider>
          <RootNavigator useCases={useCases} />
        </SafeAreaProvider>
      </GestureHandlerRootView>
    );
  };
};

const styles = StyleSheet.create({
  root: { flex: 1 },
});
