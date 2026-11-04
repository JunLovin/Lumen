import { useEffect, useMemo } from 'react';
import { useWindowDimensions } from 'react-native';
import Animated, {
  useAnimatedRef,
  useSharedValue,
} from 'react-native-reanimated';
import type { LabUseCases } from '../../application/lab-use-cases';
import type { PeerPlacement } from '../../domain/peer-placement';
import type { DragSession } from '../../domain/drag-session';
import type { FacingSide } from '../../domain/shared-space';
import { DEFAULT_PALETTE, usablePalette } from '../effects/glow-palette';
import { useTuning } from './TuningContext';

const PLACEMENT_POLL_MILLISECONDS = 500;
const SESSION_BASE_RANGE = 2 ** 30;

// The Mac keeps transfers by session while it runs, and this counter restarts with the iPhone app.
const randomSessionBase = () => Math.floor(Math.random() * SESSION_BASE_RANGE);

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
  const session = useSharedValue(randomSessionBase());
  const sequence = useSharedValue(0);
  const gridOffsetY = useSharedValue(0);
  const layerTop = useSharedValue(0);
  const dragSession = useSharedValue<DragSession>({ stage: 'idle' });
  const lastEdge = useSharedValue<FacingSide>('right');
  const uploadStarted = useSharedValue(false);
  const layerRef = useAnimatedRef<Animated.View>();
  const tuning = useTuning();
  const ripple = useSharedValue(0);
  const rippleX = useSharedValue(0);
  const rippleY = useSharedValue(0);
  const palette = useSharedValue<readonly number[]>(DEFAULT_PALETTE);

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
      dragSession,
      lastEdge,
      uploadStarted,
      palette,
      tuning,
      ripple,
      rippleX,
      rippleY,
      beginTransfer: async (session: number, assetId: string) => {
        palette.value = DEFAULT_PALETTE;
        palette.value = usablePalette(
          await useCases.beginDragTransfer(
            session,
            assetId,
            height / useCases.phoneMetrics.pointsPerMillimeter,
          ),
        );
      },
    }),
    [
      palette,
      tuning,
      ripple,
      rippleX,
      rippleY,
      dragSession,
      lastEdge,
      uploadStarted,
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
