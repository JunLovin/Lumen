import { useEffect, useState } from 'react';
import { StyleSheet, Text } from 'react-native';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';

type Props = {
  readonly isPeerConnected: () => Promise<boolean>;
};

const POLL_MILLISECONDS = 2000;

export function ConnectionBanner({ isPeerConnected }: Props) {
  const [isConnected, setIsConnected] = useState(true);

  useEffect(() => {
    const poll = () => isPeerConnected().then(setIsConnected);
    const timer = setInterval(poll, POLL_MILLISECONDS);
    return () => clearInterval(timer);
  }, [isPeerConnected]);

  return isConnected ? null : (
    <Text accessibilityRole="alert" style={styles.banner}>
      {translate('connection.lost')}
    </Text>
  );
}

const styles = StyleSheet.create({
  banner: {
    backgroundColor: labTheme.surface,
    color: labTheme.secondaryText,
    fontSize: 14,
    padding: labTheme.spacing / 2,
    textAlign: 'center',
  },
});
