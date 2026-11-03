import { useCallback, useState } from 'react';
import { ScrollView, Share, StyleSheet, Text } from 'react-native';
import type { LabUseCases } from '../../application/lab-use-cases';
import {
  summarizeTrials,
  type PlacementSide,
  type PlacementTrial,
} from '../../domain/placement';
import { CorrelationChart } from '../components/CorrelationChart';
import { DiagnosticRow } from '../components/DiagnosticRow';
import { LabButton } from '../components/LabButton';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';

type Props = {
  readonly useCases: LabUseCases;
};

export function PlacementLabScreen({ useCases }: Props) {
  const [trials, setTrials] = useState<readonly PlacementTrial[]>([]);
  const [isMeasuring, setIsMeasuring] = useState(false);
  const last = trials.at(-1);
  const measurement = last?.measurement;
  const summary = summarizeTrials(trials);

  const measure = useCallback(
    async (expected: PlacementSide) => {
      setIsMeasuring(true);
      const trial = await useCases.runPlacementTrial(expected);
      setTrials(current => [...current, trial]);
      setIsMeasuring(false);
    },
    [useCases],
  );

  const exportResults = useCallback(() => {
    const rows = trials.map(({ expected, measurement: result, failure }) => ({
      expected,
      failure,
      side: result?.side,
      tauMicroseconds: result?.tauMicroseconds,
      levelDifferenceDecibels: result?.levelDifferenceDecibels,
      snrDecibels: result?.snrDecibels,
      acceptedPairs: result?.acceptedPairs,
    }));
    Share.share({ message: JSON.stringify(rows, null, 2) });
  }, [trials]);

  const exportRecording = useCallback(async () => {
    const url = await useCases.exportLastRecording();
    if (url !== null) {
      Share.share({ url });
    }
  }, [useCases]);

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      <Text style={styles.privacy}>{translate('placement.privacy')}</Text>
      <LabButton
        title={translate(
          isMeasuring ? 'placement.measuring' : 'placement.measureLeft',
        )}
        disabled={isMeasuring}
        onPress={() => measure('left')}
      />
      <LabButton
        title={translate(
          isMeasuring ? 'placement.measuring' : 'placement.measureRight',
        )}
        disabled={isMeasuring}
        onPress={() => measure('right')}
      />
      <DiagnosticRow
        label={translate('placement.hits')}
        value={`${summary.hits} / ${summary.total}`}
      />
      <DiagnosticRow
        label={translate('placement.criterion')}
        value={translate(summary.meetsCriterion ? 'common.yes' : 'common.no')}
      />
      {last?.failure && (
        <DiagnosticRow
          label={translate('placement.lastResult')}
          value={translate(`failure.${last.failure}`)}
        />
      )}
      {measurement && (
        <>
          <DiagnosticRow
            label={translate('placement.side')}
            value={translate(`side.${measurement.side}`)}
          />
          <DiagnosticRow
            label={translate('placement.tau')}
            value={`${measurement.tauMicroseconds.toFixed(0)} µs`}
          />
          <DiagnosticRow
            label={translate('placement.level')}
            value={`${measurement.levelDifferenceDecibels.toFixed(1)} dB`}
          />
          <DiagnosticRow
            label={translate('placement.snr')}
            value={`${measurement.snrDecibels.toFixed(1)} dB`}
          />
          <DiagnosticRow
            label={translate('placement.pairs')}
            value={String(measurement.acceptedPairs)}
          />
          <CorrelationChart curve={measurement.curve} />
        </>
      )}
      <LabButton
        title={translate('placement.export')}
        onPress={exportResults}
      />
      <LabButton
        title={translate('placement.exportRecording')}
        onPress={exportRecording}
      />
      <LabButton
        title={translate('placement.reset')}
        onPress={() => setTrials([])}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: labTheme.background },
  content: { padding: labTheme.spacing },
  privacy: {
    color: labTheme.secondaryText,
    fontSize: 13,
    marginBottom: labTheme.spacing,
  },
});
