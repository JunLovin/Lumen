import { useCallback, useState } from 'react';
import { StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import { GestureDetector, usePanGesture } from 'react-native-gesture-handler';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
} from 'react-native-reanimated';
import { scheduleOnRN } from 'react-native-worklets';
import { edgeProximity, horizontalExitEdge } from '../../domain/edge-proximity';
import type { PhoneEdge } from '../../domain/peer-placement';
import type { PhoneMetrics } from '../../domain/phone-metrics';
import type { UIThreadChannelPort } from '../../application/lab-use-cases';
import { LabButton } from '../components/LabButton';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';

type Props = {
  readonly channel: UIThreadChannelPort;
  readonly metrics: PhoneMetrics;
  readonly onEdgeExit: (edge: PhoneEdge) => void;
};

const DOT_SIZE_POINTS = 72;
const ACTIVATION_DISTANCE_POINTS = 200;
const EXIT_MARGIN_POINTS = 24;
const JS_BLOCK_MILLISECONDS = 5000;
// Position of the right edge in the protocol's PhoneEdge.
const EDGE_INDEX_RIGHT = 1;

export function LatencyLabScreen({ channel, metrics, onEdgeExit }: Props) {
  const { width } = useWindowDimensions();
  const [isBlocked, setIsBlocked] = useState(false);
  const x = useSharedValue(width / 2);
  const y = useSharedValue(width / 2);
  const session = useSharedValue(0);
  const sequence = useSharedValue(0);
  const perMillimeter = metrics.pointsPerMillimeter;

  const blockJavaScript = useCallback(() => {
    setIsBlocked(true);
    setTimeout(() => {
      const end = Date.now() + JS_BLOCK_MILLISECONDS;
      while (Date.now() < end) {
        continue;
      }
      setIsBlocked(false);
    }, 50);
  }, []);

  const pan = usePanGesture({
    minDistance: 0,
    onBegin: () => {
      session.value += 1;
      sequence.value = 0;
    },
    onDeactivate: () => {
      const edge = horizontalExitEdge(x.value, width, EXIT_MARGIN_POINTS);
      if (edge !== null) {
        scheduleOnRN(onEdgeExit, edge);
      }
    },
    onUpdate: event => {
      x.value = event.x;
      y.value = event.y;
      sequence.value += 1;
      const size = DOT_SIZE_POINTS / perMillimeter;
      channel.sendFrame(
        session.value,
        sequence.value,
        event.x / perMillimeter,
        event.y / perMillimeter,
        event.velocityX / perMillimeter,
        event.velocityY / perMillimeter,
        edgeProximity(event.x, width, ACTIVATION_DISTANCE_POINTS),
        size,
        size,
        0,
        EDGE_INDEX_RIGHT,
      );
    },
  });

  const dotStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: x.value - DOT_SIZE_POINTS / 2 },
      { translateY: y.value - DOT_SIZE_POINTS / 2 },
    ],
  }));

  return (
    <GestureDetector gesture={pan}>
      <View style={styles.screen}>
        <View style={styles.header}>
          <Text style={styles.hint}>{translate('latency.hint')}</Text>
          <Text style={styles.hint}>{translate('latency.proof')}</Text>
          <LabButton
            title={translate(isBlocked ? 'latency.blocked' : 'latency.block')}
            disabled={isBlocked}
            onPress={blockJavaScript}
          />
        </View>
        <Animated.View style={[styles.dot, dotStyle]} />
      </View>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: labTheme.background },
  header: { padding: labTheme.spacing, gap: 8 },
  hint: { color: labTheme.secondaryText, fontSize: 14 },
  dot: {
    position: 'absolute',
    width: DOT_SIZE_POINTS,
    height: DOT_SIZE_POINTS,
    borderRadius: DOT_SIZE_POINTS / 2,
    backgroundColor: labTheme.accent,
  },
});
