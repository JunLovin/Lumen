import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const HEADER =
  'Generated from packages/design-tokens/tokens.json. Do not edit.';

export function assertValidTokens(tokens) {
  for (const [name, spring] of Object.entries(tokens.motion.springs)) {
    if (!(spring.response > 0) || !(spring.damping > 0)) {
      throw new Error(`Spring "${name}" needs positive response and damping`);
    }
  }
  for (const [name, value] of Object.entries(tokens.glow.palette)) {
    if (
      value.length !== 3 ||
      value.some(channel => channel < 0 || channel > 1)
    ) {
      throw new Error(`Color "${name}" needs three channels between 0 and 1`);
    }
  }
  for (const [name, cycle] of Object.entries(tokens.motion.cycles)) {
    if (!(cycle.seconds > 0)) {
      throw new Error(`Cycle "${name}" needs positive seconds`);
    }
  }
}

export function renderTypeScript(tokens) {
  const body = JSON.stringify(tokens, null, 2);
  return `// ${HEADER}\nexport const tokens = ${body} as const;\n`;
}

export function renderSwift(tokens) {
  const springs = Object.entries(tokens.motion.springs).map(
    ([name, { response, damping }]) =>
      `        public static let ${name} = SpringToken(response: ${response}, damping: ${damping})`,
  );
  const cycles = Object.entries(tokens.motion.cycles).map(
    ([name, { seconds }]) =>
      `        public static let ${name}Seconds: Double = ${seconds}`,
  );
  const { glow, chirp, pairing, placement, mirror, shelf } = tokens;
  const { effects, presence, landing, sound, lens, sweep } = tokens;
  const color = ([red, green, blue]) =>
    `ColorToken(red: ${red}, green: ${green}, blue: ${blue})`;
  return [
    `// ${HEADER}`,
    'public struct SpringToken: Sendable, Equatable {',
    '    public let response: Double',
    '    public let damping: Double',
    '}',
    '',
    'public struct ColorToken: Sendable, Equatable {',
    '    public let red: Float',
    '    public let green: Float',
    '    public let blue: Float',
    '}',
    '',
    'public enum DesignTokens {',
    '    public enum Motion {',
    ...springs,
    ...cycles,
    '    }',
    '',
    '    public enum Glow {',
    `        public static let overlayWidthPoints: Double = ${glow.overlayWidthPoints}`,
    `        public static let bandFraction: Float = ${glow.bandFraction}`,
    `        public static let intensity: Float = ${glow.intensity}`,
    `        public static let flowSpeed: Float = ${glow.flowSpeed}`,
    `        public static let noiseScale: Float = ${glow.noiseScale}`,
    `        public static let primary = ${color(glow.palette.primary)}`,
    `        public static let secondary = ${color(glow.palette.secondary)}`,
    `        public static let highlight = ${color(glow.palette.highlight)}`,
    '    }',
    '',
    '    public enum Effects {',
    `        public static let particleAmount: Float = ${effects.particleAmount}`,
    `        public static let particleCells: Float = ${effects.particleCells}`,
    `        public static let particleSpeed: Float = ${effects.particleSpeed}`,
    `        public static let bloom: Float = ${effects.bloom}`,
    '    }',
    '',
    '    public enum Presence {',
    `        public static let minConfidence: Double = ${presence.minConfidence}`,
    `        public static let macWidthPoints: Double = ${presence.macWidthPoints}`,
    `        public static let restOpacity: Float = ${presence.restOpacity}`,
    `        public static let peakOpacity: Float = ${presence.peakOpacity}`,
    `        public static let liftOpacity: Float = ${presence.liftOpacity}`,
    '    }',
    '',
    '    public enum Landing {',
    `        public static let popScale: Double = ${landing.popScale}`,
    `        public static let sheenSeconds: Double = ${landing.sheenSeconds}`,
    `        public static let glowFadeSeconds: Double = ${landing.glowFadeSeconds}`,
    '    }',
    '',
    '    public enum Sweep {',
    `        public static let seconds: Float = ${sweep.seconds}`,
    `        public static let bandPoints: Float = ${sweep.bandPoints}`,
    `        public static let intensity: Float = ${sweep.intensity}`,
    '    }',
    '',
    '    public enum Sound {',
    `        public static let frequencyHz: Double = ${sound.frequencyHz}`,
    `        public static let seconds: Double = ${sound.seconds}`,
    `        public static let gain: Float = ${sound.gain}`,
    `        public static let pan: Float = ${sound.pan}`,
    '    }',
    '',
    '    public enum Lens {',
    `        public static let refractionPoints: Float = ${lens.refractionPoints}`,
    `        public static let radiusFraction: Float = ${lens.radiusFraction}`,
    '    }',
    '',
    '    public enum Pairing {',
    `        public static let ringCycleSeconds: Double = ${pairing.ringCycleSeconds}`,
    `        public static let ringCount = ${pairing.ringCount}`,
    '        public static let verificationPalette = [',
    ...pairing.verificationPalette.map(value => `            ${color(value)},`),
    '        ]',
    '    }',
    '',
    '    public enum Placement {',
    `        public static let cometSeconds: Double = ${placement.cometSeconds}`,
    `        public static let cometLengthFraction: Double = ${placement.cometLengthFraction}`,
    `        public static let cometWidthPoints: Double = ${placement.cometWidthPoints}`,
    '    }',
    '',
    '    public enum Mirror {',
    `        public static let renderDelayMilliseconds: UInt64 = ${mirror.renderDelayMilliseconds}`,
    `        public static let maxExtrapolationMilliseconds: UInt64 = ${mirror.maxExtrapolationMilliseconds}`,
    `        public static let entryStripFraction: Double = ${mirror.entryStripFraction}`,
    '    }',
    '',
    '    public enum Shelf {',
    `        public static let insetPoints: Double = ${shelf.insetPoints}`,
    `        public static let widthPoints: Double = ${shelf.widthPoints}`,
    `        public static let heightPoints: Double = ${shelf.heightPoints}`,
    `        public static let itemPoints: Double = ${shelf.itemPoints}`,
    `        public static let fanDegrees: Double = ${shelf.fanDegrees}`,
    `        public static let hideSeconds: Double = ${shelf.hideSeconds}`,
    '    }',
    '',
    '    public enum Chirp {',
    `        public static let defaultAmplitude: Float = ${chirp.defaultAmplitude}`,
    '    }',
    '}',
    '',
  ].join('\n');
}

function resolve(path) {
  return fileURLToPath(new URL(path, import.meta.url));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const tokens = JSON.parse(readFileSync(resolve('./tokens.json'), 'utf8'));
  assertValidTokens(tokens);
  writeFileSync(resolve('./generated/tokens.ts'), renderTypeScript(tokens));
  writeFileSync(
    resolve('../LumenKit/Sources/LumenMacUI/Generated/DesignTokens.swift'),
    renderSwift(tokens),
  );
}
