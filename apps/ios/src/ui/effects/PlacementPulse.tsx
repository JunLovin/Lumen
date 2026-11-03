import { tokens } from '@lumen/design-tokens';
import { useEffect, useRef, useState } from 'react';
import { StyleSheet, useWindowDimensions, View } from 'react-native';
import {
  useReducedMotion,
  useSharedValue,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import type { PeerPlacement, PhoneEdge } from '../../domain/peer-placement';
import { EdgeGlow } from './EdgeGlow';

type Props = {
  readonly readPlacement: () => Promise<PeerPlacement>;
};

const POLL_MILLISECONDS = 500;
const PEAK_PROXIMITY = 0.7;

export function PlacementPulse({ readPlacement }: Props) {
  const { width, height } = useWindowDimensions();
  const proximity = useSharedValue(0);
  const reduceMotion = useReducedMotion();
  const [edge, setEdge] = useState<PhoneEdge>('right');
  const lastSide = useRef<PeerPlacement['side'] | null>(null);

  useEffect(() => {
    const duration = (tokens.placement.pulseSeconds * 1000) / 2;
    const poll = async () => {
      const placement = await readPlacement();
      const isNewSide =
        lastSide.current !== null &&
        lastSide.current !== placement.side &&
        placement.side !== 'unknown';
      lastSide.current = placement.side;
      if (isNewSide && placement.facingEdge !== null) {
        setEdge(placement.facingEdge);
        proximity.value = reduceMotion
          ? PEAK_PROXIMITY / 2
          : withSequence(
              withTiming(PEAK_PROXIMITY, { duration }),
              withTiming(0, { duration }),
            );
      }
    };
    const timer = setInterval(poll, POLL_MILLISECONDS);
    return () => clearInterval(timer);
  }, [proximity, readPlacement, reduceMotion]);

  if (edge !== 'left' && edge !== 'right') {
    return null;
  }

  return (
    <View
      pointerEvents="none"
      style={[StyleSheet.absoluteFill, edge === 'left' && styles.mirrored]}
    >
      <EdgeGlow width={width} height={height} proximity={proximity} />
    </View>
  );
}

const styles = StyleSheet.create({
  mirrored: { transform: [{ scaleX: -1 }] },
});
