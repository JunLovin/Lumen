import { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import type { LoadDiagnostics } from '../../application/load-diagnostics';
import { DiagnosticRow } from '../components/DiagnosticRow';
import { LabButton } from '../components/LabButton';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';
import { springs } from '../motion/springs';

type Props = {
  readonly loadDiagnostics: LoadDiagnostics;
  readonly isPeerConnected: () => Promise<boolean>;
  readonly onOpenPlacement: () => void;
  readonly onOpenLatency: () => void;
  readonly onOpenGlow: () => void;
};

const STATUS_POLL_MILLISECONDS = 1000;

const yesNo = (value: boolean) => translate(value ? 'common.yes' : 'common.no');

export function DiagnosticsScreen({
  loadDiagnostics,
  isPeerConnected,
  onOpenPlacement,
  onOpenLatency,
  onOpenGlow,
}: Props) {
  const diagnostics = loadDiagnostics();
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    const poll = () => isPeerConnected().then(setIsConnected);
    poll();
    const timer = setInterval(poll, STATUS_POLL_MILLISECONDS);
    return () => clearInterval(timer);
  }, [isPeerConnected]);

  return (
    <View style={styles.screen}>
      <DiagnosticRow
        label={translate('lab.connected')}
        value={yesNo(isConnected)}
      />
      <DiagnosticRow
        label={translate('diagnostics.scriptProtocol')}
        value={String(diagnostics.scriptProtocolVersion)}
      />
      <DiagnosticRow
        label={translate('diagnostics.nativeProtocol')}
        value={String(diagnostics.nativeProtocolVersion)}
      />
      <DiagnosticRow
        label={translate('diagnostics.agreement')}
        value={yesNo(diagnostics.negotiation.ok)}
      />
      <DiagnosticRow
        label={translate('diagnostics.hermes')}
        value={yesNo(diagnostics.isHermes)}
      />
      <DiagnosticRow
        label={translate('diagnostics.newArchitecture')}
        value={yesNo(diagnostics.isNewArchitecture)}
      />
      <DiagnosticRow
        label={translate('diagnostics.liftSpring')}
        value={`${springs.lift.response} s`}
      />
      <LabButton title={translate('lab.placement')} onPress={onOpenPlacement} />
      <LabButton title={translate('lab.latency')} onPress={onOpenLatency} />
      <LabButton title={translate('lab.glow')} onPress={onOpenGlow} />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: labTheme.background,
    padding: labTheme.spacing,
  },
});
