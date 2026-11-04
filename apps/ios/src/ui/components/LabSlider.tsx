import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { GestureDetector, usePanGesture } from 'react-native-gesture-handler';
import { scheduleOnRN } from 'react-native-worklets';
import { labTheme } from '../lab-theme';

type Props = {
  readonly label: string;
  readonly value: number;
  readonly min: number;
  readonly max: number;
  readonly onChange: (value: number) => void;
};

const TRACK_HEIGHT = 28;
const DECIMALS = 2;
const HORIZONTAL_START_POINTS = 4;
const VERTICAL_CANCEL_POINTS = 12;

export function LabSlider({ label, value, min, max, onChange }: Props) {
  const [width, setWidth] = useState(1);
  const fraction = Math.min(Math.max((value - min) / (max - min), 0), 1);

  const pan = usePanGesture({
    activeOffsetX: [-HORIZONTAL_START_POINTS, HORIZONTAL_START_POINTS],
    failOffsetY: [-VERTICAL_CANCEL_POINTS, VERTICAL_CANCEL_POINTS],
    onUpdate: event => {
      const next = Math.min(Math.max(event.x / width, 0), 1);
      scheduleOnRN(onChange, min + (max - min) * next);
    },
  });

  return (
    <View style={styles.row}>
      <Text style={styles.label}>
        {label} {value.toFixed(DECIMALS)}
      </Text>
      <GestureDetector gesture={pan}>
        <View
          style={styles.track}
          onLayout={event => setWidth(event.nativeEvent.layout.width)}
        >
          <View style={[styles.fill, { width: `${fraction * 100}%` }]} />
        </View>
      </GestureDetector>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { marginBottom: labTheme.spacing / 2 },
  label: { color: labTheme.secondaryText, fontSize: 13, marginBottom: 4 },
  track: {
    height: TRACK_HEIGHT,
    borderRadius: 8,
    backgroundColor: labTheme.surface,
    overflow: 'hidden',
  },
  fill: { height: '100%', backgroundColor: labTheme.accent },
});
