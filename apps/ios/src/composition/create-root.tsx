import { SafeAreaProvider } from 'react-native-safe-area-context';
import { createRuntimeInfoAdapter } from '../adapters/runtime-info-adapter';
import { createLoadDiagnostics } from '../application/load-diagnostics';
import { DiagnosticsScreen } from '../ui/screens/DiagnosticsScreen';

export const createRoot = () => {
  const loadDiagnostics = createLoadDiagnostics(createRuntimeInfoAdapter());

  return function Root() {
    return (
      <SafeAreaProvider>
        <DiagnosticsScreen loadDiagnostics={loadDiagnostics} />
      </SafeAreaProvider>
    );
  };
};
