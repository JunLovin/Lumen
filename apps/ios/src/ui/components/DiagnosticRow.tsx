import { StyleSheet, Text, View } from 'react-native';

type Props = {
  readonly label: string;
  readonly value: string;
};

export function DiagnosticRow({ label, value }: Props) {
  return (
    <View style={styles.row}>
      <Text style={styles.label}>{label}</Text>
      <Text style={styles.value}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
  },
  label: { color: '#8e8e93', fontSize: 15 },
  value: { color: '#ffffff', fontSize: 15, fontVariant: ['tabular-nums'] },
});
