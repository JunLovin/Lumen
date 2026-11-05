import { useCallback, useState } from 'react';
import { StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import { GestureDetector, usePanGesture } from 'react-native-gesture-handler';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
} from 'react-native-reanimated';
import { scheduleOnRN } from 'react-native-worklets';
import type { DragFrameSender } from '../../application/drag-frame-sender';
import { pointsToMillimeters } from '../../domain/device-metrics';
import type { DragFrameInput } from '../../domain/drag-frame';
import { edgeProximity } from '../../domain/edge-proximity';
import { DiagnosticRow } from '../components/DiagnosticRow';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';

type Props = {
  readonly sender: DragFrameSender;
};

const DOT_SIZE_POINTS = 72;
const ACTIVATION_DISTANCE_POINTS = 200;

export function LatencyLabScreen({ sender }: Props) {
  const { width } = useWindowDimensions();
  const [framesSent, setFramesSent] = useState(0);
  const x = useSharedValue(width / 2);
  const y = useSharedValue(width / 2);

  const send = useCallback(
    (input: DragFrameInput) => {
      sender.send(input);
      setFramesSent(count => count + 1);
    },
    [sender],
  );
  const begin = useCallback(() => sender.begin(), [sender]);

  const pan = usePanGesture({
    minDistance: 0,
    onBegin: () => {
      scheduleOnRN(begin);
    },
    onUpdate: event => {
      x.value = event.x;
      y.value = event.y;
      const size = pointsToMillimeters(DOT_SIZE_POINTS);
      scheduleOnRN(send, {
        capturedAtMilliseconds: Date.now(),
        xMillimeters: pointsToMillimeters(event.x),
        yMillimeters: pointsToMillimeters(event.y),
        velocityX: pointsToMillimeters(event.velocityX),
        velocityY: pointsToMillimeters(event.velocityY),
        edgeProximity: edgeProximity(
          event.x,
          width,
          ACTIVATION_DISTANCE_POINTS,
        ),
        objectWidthMillimeters: size,
        objectHeightMillimeters: size,
        rotationRadians: 0,
      });
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
          <DiagnosticRow
            label={translate('latency.framesSent')}
            value={String(framesSent)}
          />
        </View>
        <Animated.View style={[styles.dot, dotStyle]} />
      </View>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: labTheme.background },
  header: { padding: labTheme.spacing },
  hint: { color: labTheme.secondaryText, fontSize: 14 },
  dot: {
    position: 'absolute',
    width: DOT_SIZE_POINTS,
    height: DOT_SIZE_POINTS,
    borderRadius: DOT_SIZE_POINTS / 2,
    backgroundColor: labTheme.accent,
  },
});
