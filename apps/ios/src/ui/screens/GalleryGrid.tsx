import { FlashList } from '@shopify/flash-list';
import { useCallback, useState } from 'react';
import { StyleSheet, useWindowDimensions } from 'react-native';
import Animated, { useAnimatedScrollHandler } from 'react-native-reanimated';
import type { LabUseCases } from '../../application/lab-use-cases';
import type { MediaAsset } from '../../domain/media';
import { DragLayer } from '../components/DragLayer';
import { GalleryCell } from '../components/GalleryCell';
import { useDragController } from '../motion/use-drag-controller';

type Props = {
  readonly assets: readonly MediaAsset[];
  readonly useCases: LabUseCases;
  readonly onEndReached: () => void;
};

const COLUMNS = 3;
const AnimatedFlashList = Animated.createAnimatedComponent(
  FlashList<MediaAsset>,
);

export function GalleryGrid({ assets, useCases, onEndReached }: Props) {
  const { width } = useWindowDimensions();
  const cellSize = width / COLUMNS;
  const drag = useDragController(useCases);
  const [draggedUri, setDraggedUri] = useState<string | null>(null);

  const onScroll = useAnimatedScrollHandler(event => {
    drag.scrollY.value = event.contentOffset.y;
  });

  const renderItem = useCallback(
    ({
      item,
      index,
    }: {
      readonly item: MediaAsset;
      readonly index: number;
    }) => (
      <GalleryCell
        asset={item}
        index={index}
        columns={COLUMNS}
        size={cellSize}
        drag={drag}
        loadThumbnail={useCases.loadThumbnail}
        onLift={setDraggedUri}
      />
    ),
    [cellSize, drag, useCases.loadThumbnail],
  );

  return (
    <Animated.View ref={drag.layerRef} style={styles.container}>
      <AnimatedFlashList
        data={assets}
        numColumns={COLUMNS}
        keyExtractor={item => item.id}
        renderItem={renderItem}
        onScroll={onScroll}
        scrollEventThrottle={16}
        onEndReached={onEndReached}
      />
      <DragLayer drag={drag} uri={draggedUri} size={cellSize} />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
});
