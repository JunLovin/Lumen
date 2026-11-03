import { DarkTheme, NavigationContainer } from '@react-navigation/native';
import {
  createNativeStackNavigator,
  type NativeStackScreenProps,
} from '@react-navigation/native-stack';
import type { LabUseCases } from '../application/lab-use-cases';
import { translate } from './i18n/translate';
import { DiagnosticsScreen } from './screens/DiagnosticsScreen';
import { GlowLabScreen } from './screens/GlowLabScreen';
import { LatencyLabScreen } from './screens/LatencyLabScreen';
import { PlacementLabScreen } from './screens/PlacementLabScreen';

type Routes = {
  Diagnostics: undefined;
  Placement: undefined;
  Latency: undefined;
  Glow: undefined;
};

const Stack = createNativeStackNavigator<Routes>();

type Props = {
  readonly useCases: LabUseCases;
};

export function RootNavigator({ useCases }: Props) {
  const renderDiagnostics = ({
    navigation,
  }: NativeStackScreenProps<Routes, 'Diagnostics'>) => (
    <DiagnosticsScreen
      loadDiagnostics={useCases.loadDiagnostics}
      isPeerConnected={useCases.isPeerConnected}
      onOpenPlacement={() => navigation.navigate('Placement')}
      onOpenLatency={() => navigation.navigate('Latency')}
      onOpenGlow={() => navigation.navigate('Glow')}
    />
  );

  return (
    <NavigationContainer theme={DarkTheme}>
      <Stack.Navigator>
        <Stack.Screen
          name="Diagnostics"
          options={{ title: translate('diagnostics.title') }}
        >
          {renderDiagnostics}
        </Stack.Screen>
        <Stack.Screen
          name="Placement"
          options={{ title: translate('lab.placement') }}
        >
          {() => <PlacementLabScreen useCases={useCases} />}
        </Stack.Screen>
        <Stack.Screen
          name="Latency"
          options={{ title: translate('lab.latency'), gestureEnabled: false }}
        >
          {() => <LatencyLabScreen sender={useCases.dragFrameSender} />}
        </Stack.Screen>
        <Stack.Screen
          name="Glow"
          options={{ title: translate('lab.glow'), gestureEnabled: false }}
        >
          {() => <GlowLabScreen />}
        </Stack.Screen>
      </Stack.Navigator>
    </NavigationContainer>
  );
}
