import { Pressable, StyleSheet, Text } from 'react-native';
import { labTheme } from '../lab-theme';

type Props = {
  readonly title: string;
  readonly disabled?: boolean;
  readonly onPress: () => void;
};

export function LabButton({ title, disabled = false, onPress }: Props) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={[styles.button, disabled && styles.disabled]}
    >
      <Text style={styles.title}>{title}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    backgroundColor: labTheme.surface,
    borderRadius: labTheme.buttonRadius,
    padding: labTheme.spacing,
    marginVertical: 4,
  },
  disabled: { opacity: 0.5 },
  title: { color: labTheme.accent, fontSize: 16, textAlign: 'center' },
});
