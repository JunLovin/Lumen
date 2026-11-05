import type {
  PlacementCalibration,
  PlacementMeasurement,
  PlacementTrial,
} from '../../domain/placement';
import { CorrelationChart } from '../components/CorrelationChart';
import { DiagnosticRow } from '../components/DiagnosticRow';
import { translate } from '../i18n/translate';

type Props = {
  readonly trial: PlacementTrial;
  readonly measurement: PlacementMeasurement;
  readonly calibration: PlacementCalibration;
};

export function PlacementResult({ trial, measurement, calibration }: Props) {
  const relativeTau = measurement.tauMicroseconds - calibration.tauMicroseconds;
  return (
    <>
      {trial.measuredSide && (
        <DiagnosticRow
          label={translate('placement.side')}
          value={translate(`side.${trial.measuredSide}`)}
        />
      )}
      <DiagnosticRow
        label={translate('placement.relativeTau')}
        value={`${relativeTau.toFixed(0)} µs`}
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
  );
}
