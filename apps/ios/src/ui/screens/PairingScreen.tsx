import { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { PairingStatus } from '../../domain/pairing';
import { ConvergingRings } from '../effects/ConvergingRings';
import { VerificationRing } from '../effects/VerificationRing';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';

type Props = {
  readonly status: PairingStatus;
};

const VISUAL_SIZE = 200;
const NETWORK_HINT_DELAY_MILLISECONDS = 20_000;

const messageFor = (status: PairingStatus) => {
  switch (status.stage) {
    case 'awaitingConfirmation':
      return translate('pairing.compare');
    case 'exchanging':
      return translate('pairing.exchanging');
    case 'failed':
      return translate('pairing.failed');
    default:
      return translate('pairing.searching');
  }
};

export function PairingScreen({ status }: Props) {
  const [showsNetworkHint, setShowsNetworkHint] = useState(false);

  useEffect(() => {
    if (status.stage !== 'searching') {
      setShowsNetworkHint(false);
      return;
    }
    const timer = setTimeout(
      () => setShowsNetworkHint(true),
      NETWORK_HINT_DELAY_MILLISECONDS,
    );
    return () => clearTimeout(timer);
  }, [status.stage]);

  return (
    <View style={styles.screen}>
      <Text style={styles.title}>{translate('pairing.title')}</Text>
      {status.stage === 'awaitingConfirmation' ? (
        <VerificationRing colorIndices={status.pattern} size={VISUAL_SIZE} />
      ) : (
        <ConvergingRings size={VISUAL_SIZE} />
      )}
      <Text style={styles.message}>{messageFor(status)}</Text>
      {showsNetworkHint && (
        <Text style={styles.hint}>{translate('pairing.networkHint')}</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: labTheme.background,
    padding: labTheme.spacing * 2,
    gap: labTheme.spacing * 2,
  },
  title: { color: labTheme.text, fontSize: 28, fontWeight: '700' },
  message: { color: labTheme.text, fontSize: 17, textAlign: 'center' },
  hint: { color: labTheme.secondaryText, fontSize: 14, textAlign: 'center' },
});
