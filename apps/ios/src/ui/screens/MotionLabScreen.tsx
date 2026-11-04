import { tokens } from '@lumen/design-tokens';
import { useEffect, useState } from 'react';
import { ScrollView, Share, StyleSheet } from 'react-native';
import type { LabUseCases } from '../../application/lab-use-cases';
import {
  patchTokens,
  readTokenValue,
  TUNABLES,
} from '../../domain/motion-tuning';
import { LabButton } from '../components/LabButton';
import { LabSlider } from '../components/LabSlider';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';

type Props = {
  readonly useCases: LabUseCases;
};

const POLL_MILLISECONDS = 500;
const INDENT = 2;

export function MotionLabScreen({ useCases }: Props) {
  const [values, setValues] = useState<Readonly<Record<string, number>>>({});

  useEffect(() => {
    const poll = () => useCases.readTuning().then(setValues);
    poll();
    const timer = setInterval(poll, POLL_MILLISECONDS);
    return () => clearInterval(timer);
  }, [useCases]);

  const tune = (path: string, value: number) => {
    setValues(current => ({ ...current, [path]: value }));
    useCases.tune(path, value);
  };

  const reset = () => {
    for (const { path } of TUNABLES) {
      const value = readTokenValue(tokens, path);
      if (value !== null) {
        tune(path, value);
      }
    }
  };

  const exportTokens = () =>
    Share.share({
      message: JSON.stringify(patchTokens(tokens, values), null, INDENT),
    });

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      <LabButton title={translate('motion.export')} onPress={exportTokens} />
      <LabButton title={translate('motion.reset')} onPress={reset} />
      {TUNABLES.map(({ path, min, max }) => (
        <LabSlider
          key={path}
          label={path}
          min={min}
          max={max}
          value={values[path] ?? readTokenValue(tokens, path) ?? min}
          onChange={value => tune(path, value)}
        />
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: labTheme.background },
  content: { padding: labTheme.spacing },
});
