import { DarkTheme, NavigationContainer } from '@react-navigation/native';
import {
  createNativeStackNavigator,
  type NativeStackScreenProps,
} from '@react-navigation/native-stack';
import { StyleSheet, Text } from 'react-native';
import type { LabUseCases } from '../application/lab-use-cases';
import { translate } from './i18n/translate';
import { labTheme } from './lab-theme';
import { PlacementPulse } from './effects/PlacementPulse';
import { PresenceAura } from './effects/PresenceAura';
import { GalleryScreen } from './screens/GalleryScreen';
import { DiagnosticsScreen } from './screens/DiagnosticsScreen';
import { GlowLabScreen } from './screens/GlowLabScreen';
import { InboxScreen } from './screens/InboxScreen';
import { LatencyLabScreen } from './screens/LatencyLabScreen';
import { MotionLabScreen } from './screens/MotionLabScreen';
import { PlacementLabScreen } from './screens/PlacementLabScreen';

type Routes = {
  Gallery: undefined;
  Inbox: undefined;
  Diagnostics: undefined;
  Placement: undefined;
  Latency: undefined;
  Glow: undefined;
  Motion: undefined;
};

const Stack = createNativeStackNavigator<Routes>();

type Props = {
  readonly useCases: LabUseCases;
  readonly peerName: string;
  readonly reconnectMilliseconds: number | null;
};

export function RootNavigator({
  useCases,
  peerName,
  reconnectMilliseconds,
}: Props) {
  const renderDiagnostics = ({
    navigation,
  }: NativeStackScreenProps<Routes, 'Diagnostics'>) => (
    <DiagnosticsScreen
      loadDiagnostics={useCases.loadDiagnostics}
      isPeerConnected={useCases.isPeerConnected}
      peerName={peerName}
      reconnectMilliseconds={reconnectMilliseconds}
      onForget={useCases.forgetPairing}
      onProbeFileChannel={useCases.probeFileChannel}
      onOpenPlacement={() => navigation.navigate('Placement')}
      onOpenLatency={() => navigation.navigate('Latency')}
      onOpenGlow={() => navigation.navigate('Glow')}
      onOpenMotion={() => navigation.navigate('Motion')}
    />
  );

  return (
    <>
      <NavigationContainer theme={DarkTheme}>
        <Stack.Navigator>
          <Stack.Screen
            name="Gallery"
            options={({ navigation }) => ({
              title: translate('gallery.title'),
              gestureEnabled: false,
              headerRight: () =>
                __DEV__ && (
                  <Text
                    style={styles.headerLink}
                    onPress={() => navigation.navigate('Diagnostics')}
                  >
                    {translate('gallery.labs')}
                  </Text>
                ),
            })}
          >
            {() => <GalleryScreen useCases={useCases} />}
          </Stack.Screen>
          <Stack.Screen
            name="Inbox"
            options={{ title: translate('inbox.title') }}
          >
            {() => <InboxScreen useCases={useCases} />}
          </Stack.Screen>
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
            {() => (
              <LatencyLabScreen
                channel={useCases.uiThreadChannel}
                metrics={useCases.phoneMetrics}
                onEdgeExit={useCases.reportEdgeExit}
              />
            )}
          </Stack.Screen>
          <Stack.Screen
            name="Glow"
            options={{ title: translate('lab.glow'), gestureEnabled: false }}
          >
            {() => <GlowLabScreen />}
          </Stack.Screen>
          <Stack.Screen
            name="Motion"
            options={{ title: translate('lab.motion') }}
          >
            {() => <MotionLabScreen useCases={useCases} />}
          </Stack.Screen>
        </Stack.Navigator>
      </NavigationContainer>
      <PlacementPulse readPlacement={useCases.readPlacement} />
      <PresenceAura
        readPlacement={useCases.readPlacement}
        isPeerConnected={useCases.isPeerConnected}
      />
    </>
  );
}

const styles = StyleSheet.create({
  headerLink: { color: labTheme.accent, fontSize: 16, paddingHorizontal: 8 },
});
