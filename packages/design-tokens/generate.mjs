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
  return [
    `// ${HEADER}`,
    'public struct SpringToken: Sendable, Equatable {',
    '    public let response: Double',
    '    public let damping: Double',
    '}',
    '',
    'public enum DesignTokens {',
    '    public enum Motion {',
    ...springs,
    ...cycles,
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
