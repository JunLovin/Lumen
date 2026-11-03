import { useEffect, useMemo } from 'react';
import { useWindowDimensions } from 'react-native';
import Animated, {
  useAnimatedRef,
  useSharedValue,
} from 'react-native-reanimated';
import type { LabUseCases } from '../../application/lab-use-cases';
import type { PeerPlacement } from '../../domain/peer-placement';
import type { FacingSide } from '../../domain/shared-space';

const PLACEMENT_POLL_MILLISECONDS = 500;

const facingSide = (placement: PeerPlacement): FacingSide | null =>
  placement.facingEdge === 'left' || placement.facingEdge === 'right'
    ? placement.facingEdge
    : null;

export const useDragController = (useCases: LabUseCases) => {
  const { width, height } = useWindowDimensions();
  const scrollY = useSharedValue(0);
  const activeIndex = useSharedValue(-1);
  const lift = useSharedValue(0);
  const x = useSharedValue(0);
  const y = useSharedValue(0);
  const rotation = useSharedValue(0);
  const tiltX = useSharedValue(0);
  const tiltY = useSharedValue(0);
  const leftGlow = useSharedValue(0);
  const rightGlow = useSharedValue(0);
  const confidence = useSharedValue(0);
  const facingIsRight = useSharedValue<boolean | null>(null);
  const session = useSharedValue(0);
  const sequence = useSharedValue(0);
  const gridOffsetY = useSharedValue(0);
  const layerTop = useSharedValue(0);
  const layerRef = useAnimatedRef<Animated.View>();

  useEffect(() => {
    const poll = async () => {
      const placement = await useCases.readPlacement();
      confidence.value = placement.confidence;
      const side = facingSide(placement);
      facingIsRight.value = side === null ? null : side === 'right';
    };
    poll();
    const timer = setInterval(poll, PLACEMENT_POLL_MILLISECONDS);
    return () => clearInterval(timer);
  }, [confidence, facingIsRight, useCases]);

  return useMemo(
    () => ({
      channel: useCases.uiThreadChannel,
      pointsPerMillimeter: useCases.phoneMetrics.pointsPerMillimeter,
      reportEdgeExit: useCases.reportEdgeExit,
      screenWidth: width,
      screenHeight: height,
      scrollY,
      activeIndex,
      lift,
      x,
      y,
      rotation,
      tiltX,
      tiltY,
      leftGlow,
      rightGlow,
      confidence,
      facingIsRight,
      session,
      sequence,
      gridOffsetY,
      layerTop,
      layerRef,
    }),
    [
      activeIndex,
      confidence,
      facingIsRight,
      gridOffsetY,
      height,
      layerRef,
      layerTop,
      leftGlow,
      lift,
      rightGlow,
      rotation,
      scrollY,
      sequence,
      session,
      tiltX,
      tiltY,
      useCases,
      width,
      x,
      y,
    ],
  );
};

export type DragController = ReturnType<typeof useDragController>;
