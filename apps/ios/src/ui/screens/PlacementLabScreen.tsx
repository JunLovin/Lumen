import { useCallback, useState } from 'react';
import { ScrollView, Share, StyleSheet, Text } from 'react-native';
import type { LabUseCases } from '../../application/lab-use-cases';
import {
  summarizeTrials,
  type PlacementCalibration,
  type PlacementFailure,
  type PlacementSide,
  type PlacementTrial,
} from '../../domain/placement';
import { DiagnosticRow } from '../components/DiagnosticRow';
import { LabButton } from '../components/LabButton';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';
import { PlacementResult } from './PlacementResult';

type Props = {
  readonly useCases: LabUseCases;
};

export function PlacementLabScreen({ useCases }: Props) {
  const [trials, setTrials] = useState<readonly PlacementTrial[]>([]);
  const [calibration, setCalibration] = useState<PlacementCalibration | null>(
    null,
  );
  const [calibrationFailure, setCalibrationFailure] =
    useState<PlacementFailure | null>(null);
  const [isBusy, setIsBusy] = useState(false);
  const last = trials.at(-1);
  const summary = summarizeTrials(trials);
  const failure = last?.failure ?? calibrationFailure;

  const calibrate = useCallback(async () => {
    setIsBusy(true);
    const result = await useCases.calibratePlacement();
    setCalibration(result.ok ? result.value : null);
    setCalibrationFailure(result.ok ? null : result.error);
    setTrials([]);
    setIsBusy(false);
  }, [useCases]);

  const measure = useCallback(
    async (expected: PlacementSide, current: PlacementCalibration) => {
      setIsBusy(true);
      const trial = await useCases.runPlacementTrial(expected, current);
      setTrials(previous => [...previous, trial]);
      setIsBusy(false);
    },
    [useCases],
  );

  const exportResults = useCallback(() => {
    const rows = trials.map(
      ({ expected, measuredSide, measurement, failure: reason }) => ({
        expected,
        measuredSide,
        failure: reason,
        tauMicroseconds: measurement?.tauMicroseconds,
        levelDifferenceDecibels: measurement?.levelDifferenceDecibels,
        snrDecibels: measurement?.snrDecibels,
        acceptedPairs: measurement?.acceptedPairs,
        pairs: measurement?.pairs,
      }),
    );
    Share.share({
      message: JSON.stringify({ calibration, trials: rows }, null, 2),
    });
  }, [calibration, trials]);

  const exportRecording = useCallback(async () => {
    const url = await useCases.exportLastRecording();
    if (url !== null) {
      Share.share({ url });
    }
  }, [useCases]);

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      <Text style={styles.note}>{translate('placement.privacy')}</Text>
      <Text style={styles.note}>{translate('placement.calibrationFirst')}</Text>
      <LabButton
        title={translate(
          isBusy ? 'placement.calibrating' : 'placement.calibrate',
        )}
        disabled={isBusy}
        onPress={calibrate}
      />
      {calibration && (
        <>
          <DiagnosticRow
            label={translate('placement.calibrationTau')}
            value={`${calibration.tauMicroseconds.toFixed(0)} µs`}
          />
          <DiagnosticRow
            label={translate('placement.calibrationLevel')}
            value={`${calibration.levelDifferenceDecibels.toFixed(1)} dB`}
          />
          <LabButton
            title={translate(
              isBusy ? 'placement.measuring' : 'placement.measureLeft',
            )}
            disabled={isBusy}
            onPress={() => measure('left', calibration)}
          />
          <LabButton
            title={translate(
              isBusy ? 'placement.measuring' : 'placement.measureRight',
            )}
            disabled={isBusy}
            onPress={() => measure('right', calibration)}
          />
        </>
      )}
      <DiagnosticRow
        label={translate('placement.hits')}
        value={`${summary.hits} / ${summary.total}`}
      />
      <DiagnosticRow
        label={translate('placement.criterion')}
        value={translate(summary.meetsCriterion ? 'common.yes' : 'common.no')}
      />
      {failure && (
        <DiagnosticRow
          label={translate('placement.lastResult')}
          value={translate(`failure.${failure}`)}
        />
      )}
      {last?.measurement && calibration && (
        <PlacementResult
          trial={last}
          measurement={last.measurement}
          calibration={calibration}
        />
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
  note: {
    color: labTheme.secondaryText,
    fontSize: 13,
    marginBottom: labTheme.spacing,
  },
});
