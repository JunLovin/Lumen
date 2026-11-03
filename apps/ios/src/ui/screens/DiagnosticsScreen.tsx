import { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import type { LoadDiagnostics } from '../../application/load-diagnostics';
import { DiagnosticRow } from '../components/DiagnosticRow';
import { LabButton } from '../components/LabButton';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';
import { tokens } from '@lumen/design-tokens';

type Props = {
  readonly loadDiagnostics: LoadDiagnostics;
  readonly isPeerConnected: () => Promise<boolean>;
  readonly peerName: string;
  readonly reconnectMilliseconds: number | null;
  readonly onForget: () => void;
  readonly onProbeFileChannel: () => Promise<boolean>;
  readonly onOpenPlacement: () => void;
  readonly onOpenLatency: () => void;
  readonly onOpenGlow: () => void;
};

const STATUS_POLL_MILLISECONDS = 1000;

const yesNo = (value: boolean) => translate(value ? 'common.yes' : 'common.no');

export function DiagnosticsScreen({
  loadDiagnostics,
  isPeerConnected,
  peerName,
  reconnectMilliseconds,
  onForget,
  onProbeFileChannel,
  onOpenPlacement,
  onOpenLatency,
  onOpenGlow,
}: Props) {
  const diagnostics = loadDiagnostics();
  const [isConnected, setIsConnected] = useState(false);
  const [fileChannelWorks, setFileChannelWorks] = useState<boolean | null>(
    null,
  );

  useEffect(() => {
    const poll = () => isPeerConnected().then(setIsConnected);
    poll();
    const timer = setInterval(poll, STATUS_POLL_MILLISECONDS);
    return () => clearInterval(timer);
  }, [isPeerConnected]);

  return (
    <View style={styles.screen}>
      <DiagnosticRow label={translate('pairing.peer')} value={peerName} />
      <DiagnosticRow
        label={translate('lab.connected')}
        value={yesNo(isConnected)}
      />
      <DiagnosticRow
        label={translate('pairing.reconnect')}
        value={
          reconnectMilliseconds === null ? '—' : `${reconnectMilliseconds} ms`
        }
      />
      <DiagnosticRow
        label={translate('pairing.fileChannel')}
        value={fileChannelWorks === null ? '—' : yesNo(fileChannelWorks)}
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
        value={`${tokens.motion.springs.lift.response} s`}
      />
      <LabButton
        title={translate('pairing.probeFileChannel')}
        onPress={() => {
          onProbeFileChannel().then(setFileChannelWorks);
        }}
      />
      <LabButton title={translate('pairing.forget')} onPress={onForget} />
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
