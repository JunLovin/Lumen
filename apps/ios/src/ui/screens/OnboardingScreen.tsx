import { useState } from 'react';
import { StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import { GestureDetector, usePanGesture } from 'react-native-gesture-handler';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { scheduleOnRN } from 'react-native-worklets';
import { tokens } from '@lumen/design-tokens';
import { edgeProximity } from '../../domain/edge-proximity';
import { LabButton } from '../components/LabButton';
import { EdgeGlow } from '../effects/EdgeGlow';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';
import { springs } from '../motion/spring';

type Props = {
  readonly onDone: () => void;
};

const CARD_POINTS = 120;
const { activationPoints } = tokens.proximity;

export function OnboardingScreen({ onDone }: Props) {
  const { width, height } = useWindowDimensions();
  const [hasCrossed, setHasCrossed] = useState(false);
  const offsetX = useSharedValue(0);
  const offsetY = useSharedValue(0);
  const rightGlow = useSharedValue(0);
  const leftGlow = useSharedValue(0);

  const pan = usePanGesture({
    onUpdate: event => {
      offsetX.value = event.translationX;
      offsetY.value = event.translationY;
      rightGlow.value = edgeProximity(event.absoluteX, width, activationPoints);
      leftGlow.value = edgeProximity(
        width - event.absoluteX,
        width,
        activationPoints,
      );
      if (rightGlow.value >= 1 || leftGlow.value >= 1) {
        scheduleOnRN(setHasCrossed, true);
      }
    },
    onDeactivate: () => {
      offsetX.value = withSpring(0, springs.snapBack);
      offsetY.value = withSpring(0, springs.snapBack);
      rightGlow.value = withSpring(0, springs.snapBack);
      leftGlow.value = withSpring(0, springs.snapBack);
    },
  });

  const cardStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: offsetX.value }, { translateY: offsetY.value }],
  }));

  return (
    <View style={styles.screen}>
      <EdgeGlow width={width} height={height} proximity={rightGlow} />
      <View style={[StyleSheet.absoluteFill, styles.mirrored]}>
        <EdgeGlow width={width} height={height} proximity={leftGlow} />
      </View>
      <Text style={styles.title}>{translate('onboarding.title')}</Text>
      <Text style={styles.body}>{translate('onboarding.body')}</Text>
      <GestureDetector gesture={pan}>
        <Animated.View style={[styles.card, cardStyle]} />
      </GestureDetector>
      <Text style={styles.body}>
        {translate(hasCrossed ? 'onboarding.success' : 'onboarding.try')}
      </Text>
      <LabButton
        title={translate(hasCrossed ? 'onboarding.start' : 'onboarding.skip')}
        onPress={onDone}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    justifyContent: 'center',
    backgroundColor: labTheme.background,
    padding: labTheme.spacing * 2,
    gap: labTheme.spacing,
  },
  mirrored: { transform: [{ scaleX: -1 }] },
  title: { color: labTheme.text, fontSize: 28, fontWeight: '700' },
  body: { color: labTheme.secondaryText, fontSize: 16 },
  card: {
    alignSelf: 'center',
    width: CARD_POINTS,
    height: CARD_POINTS,
    borderRadius: 12,
    marginVertical: labTheme.spacing * 2,
    backgroundColor: labTheme.accent,
  },
});
