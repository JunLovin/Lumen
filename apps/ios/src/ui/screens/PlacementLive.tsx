import { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import {
  PLACEMENT_SIDES,
  type PeerPlacement,
} from '../../domain/peer-placement';
import { DiagnosticRow } from '../components/DiagnosticRow';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';

type Props = {
  readonly readPlacement: () => Promise<PeerPlacement>;
};

const POLL_MILLISECONDS = 500;

export function PlacementLive({ readPlacement }: Props) {
  const [placement, setPlacement] = useState<PeerPlacement | null>(null);

  useEffect(() => {
    const poll = () => readPlacement().then(setPlacement);
    poll();
    const timer = setInterval(poll, POLL_MILLISECONDS);
    return () => clearInterval(timer);
  }, [readPlacement]);

  if (placement === null) {
    return null;
  }

  return (
    <View style={styles.section}>
      <DiagnosticRow
        label={translate('live.side')}
        value={translate(`side.${placement.side}`)}
      />
      <DiagnosticRow
        label={translate('live.confidence')}
        value={`${Math.round(placement.confidence * 100)} %`}
      />
      <DiagnosticRow
        label={translate('live.detached')}
        value={translate(placement.isDetached ? 'common.yes' : 'common.no')}
      />
      <DiagnosticRow
        label={translate('live.facing')}
        value={
          placement.facingEdge === null
            ? '—'
            : translate(`edge.${placement.facingEdge}`)
        }
      />
      <DiagnosticRow
        label={translate('live.lastFailure')}
        value={
          placement.locationFailure === null
            ? 'OK'
            : translate(`failure.${placement.locationFailure}`)
        }
      />
      {PLACEMENT_SIDES.map((side, index) => (
        <DiagnosticRow
          key={side}
          label={translate(`side.${side}`)}
          value={`${Math.round((placement.probabilities[index] ?? 0) * 100)} %`}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  section: { marginBottom: labTheme.spacing },
});
