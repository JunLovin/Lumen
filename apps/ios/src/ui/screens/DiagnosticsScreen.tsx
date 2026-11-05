import { StyleSheet, Text } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import type { LoadDiagnostics } from '../../application/load-diagnostics';
import { DiagnosticRow } from '../components/DiagnosticRow';
import { translate } from '../i18n/translate';
import { springs } from '../motion/springs';

type Props = {
  readonly loadDiagnostics: LoadDiagnostics;
};

const yesNo = (value: boolean) => translate(value ? 'common.yes' : 'common.no');

export function DiagnosticsScreen({ loadDiagnostics }: Props) {
  const diagnostics = loadDiagnostics();

  return (
    <SafeAreaView style={styles.screen}>
      <Text style={styles.title}>{translate('diagnostics.title')}</Text>
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
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#000000', paddingHorizontal: 20 },
  title: {
    color: '#ffffff',
    fontSize: 28,
    fontWeight: '700',
    marginVertical: 16,
  },
});
