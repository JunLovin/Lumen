import { Canvas, Path, Skia } from '@shopify/react-native-skia';
import { useMemo } from 'react';
import { StyleSheet, useWindowDimensions } from 'react-native';
import { labTheme } from '../lab-theme';

type Props = {
  readonly curve: readonly number[];
};

const CHART_HEIGHT = 96;

export function CorrelationChart({ curve }: Props) {
  const width = useWindowDimensions().width - labTheme.spacing * 2;
  const path = useMemo(() => {
    const line = Skia.PathBuilder.Make();
    const peak = Math.max(...curve, Number.MIN_VALUE);
    curve.forEach((value, index) => {
      const x = (index / Math.max(curve.length - 1, 1)) * width;
      const y = CHART_HEIGHT - (value / peak) * CHART_HEIGHT;
      if (index === 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    });
    return line.detach();
  }, [curve, width]);

  return (
    <Canvas style={styles.canvas}>
      <Path
        path={path}
        color={labTheme.accent}
        style="stroke"
        strokeWidth={1.5}
      />
    </Canvas>
  );
}

const styles = StyleSheet.create({
  canvas: { height: CHART_HEIGHT, marginVertical: 8 },
});
