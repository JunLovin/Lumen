import { tokens } from '@lumen/design-tokens';
import { Canvas, Path, Skia } from '@shopify/react-native-skia';

type Props = {
  readonly colorIndices: readonly number[];
  readonly size: number;
};

const toColor = ([red, green, blue]: readonly number[]) =>
  Skia.Color([red ?? 0, green ?? 0, blue ?? 0, 1]);

export function VerificationRing({ colorIndices, size }: Props) {
  const palette = tokens.pairing.verificationPalette;
  const strokeWidth = size / 8;
  const inset = strokeWidth / 2;
  const sweep = 360 / Math.max(colorIndices.length, 1);
  const oval = Skia.XYWHRect(
    inset,
    inset,
    size - strokeWidth,
    size - strokeWidth,
  );

  return (
    <Canvas style={{ width: size, height: size }}>
      {colorIndices.map((index, position) => (
        <Path
          key={position}
          path={Skia.PathBuilder.Make()
            .addArc(oval, position * sweep - 90, sweep)
            .detach()}
          color={toColor(palette[index % palette.length] ?? [])}
          style="stroke"
          strokeWidth={strokeWidth}
        />
      ))}
    </Canvas>
  );
}
