import { useEffect, useState } from 'react';
import {
  StyleSheet,
  Switch,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';
import { GestureDetector, usePanGesture } from 'react-native-gesture-handler';
import { useFrameCallback, useSharedValue } from 'react-native-reanimated';
import { edgeProximity } from '../../domain/edge-proximity';
import { DiagnosticRow } from '../components/DiagnosticRow';
import { LabButton } from '../components/LabButton';
import { EdgeGlow } from '../effects/EdgeGlow';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';
import { useFrameMeter } from '../motion/use-frame-meter';

const ACTIVATION_DISTANCE_POINTS = 200;
const SWEEP_PERIOD_MILLISECONDS = 2000;

export function GlowLabScreen() {
  const { width, height } = useWindowDimensions();
  const [isSweeping, setIsSweeping] = useState(true);
  const proximity = useSharedValue(0);
  const sweep = useSharedValue(true);
  const { stats, reset } = useFrameMeter();

  useEffect(() => {
    sweep.value = isSweeping;
  }, [isSweeping, sweep]);

  useFrameCallback(info => {
    if (sweep.value) {
      const phase =
        (info.timeSinceFirstFrame / SWEEP_PERIOD_MILLISECONDS) * 2 * Math.PI;
      proximity.value = 0.5 + 0.5 * Math.sin(phase);
    }
  });

  const pan = usePanGesture({
    onUpdate: event => {
      if (!sweep.value) {
        proximity.value = edgeProximity(
          event.x,
          width,
          ACTIVATION_DISTANCE_POINTS,
        );
      }
    },
  });

  return (
    <GestureDetector gesture={pan}>
      <View style={styles.screen}>
        <EdgeGlow width={width} height={height} proximity={proximity} />
        <Text style={styles.hint}>{translate('glow.hint')}</Text>
        <View style={styles.sweep}>
          <Text style={styles.label}>{translate('glow.sweep')}</Text>
          <Switch value={isSweeping} onValueChange={setIsSweeping} />
        </View>
        <DiagnosticRow
          label={translate('glow.fps')}
          value={stats ? stats.averageFps.toFixed(1) : '—'}
        />
        <DiagnosticRow
          label={translate('glow.dropped')}
          value={stats ? String(stats.dropped) : '—'}
        />
        <DiagnosticRow
          label={translate('glow.p95')}
          value={stats ? `${stats.p95IntervalMilliseconds.toFixed(1)} ms` : '—'}
        />
        <DiagnosticRow
          label={translate('glow.frames')}
          value={stats ? String(stats.frames) : '—'}
        />
        <LabButton title={translate('glow.reset')} onPress={reset} />
      </View>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: labTheme.background,
    padding: labTheme.spacing,
  },
  hint: {
    color: labTheme.secondaryText,
    fontSize: 14,
    marginBottom: labTheme.spacing,
  },
  sweep: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  label: { color: labTheme.secondaryText, fontSize: 15 },
});
