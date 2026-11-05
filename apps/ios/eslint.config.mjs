import js from '@eslint/js';
import boundaries from 'eslint-plugin-boundaries';
import tseslint from 'typescript-eslint';

const LAYERS = [
  'domain',
  'ports',
  'application',
  'adapters',
  'ui',
  'composition',
];

const ALLOWED_DEPENDENCIES = {
  domain: ['domain'],
  ports: ['domain', 'ports'],
  application: ['domain', 'ports', 'application'],
  adapters: ['domain', 'ports', 'adapters'],
  ui: ['domain', 'application', 'ui'],
  composition: LAYERS,
};

const allowedPolicy = ([from, to]) => ({
  from: { element: { type: from } },
  allow: { to: { element: { types: to } } },
});

const frameworkImportBan = {
  'no-restricted-imports': [
    'error',
    {
      patterns: [
        {
          regex: '^[^.]',
          message: 'Domain, ports and application only import their own code.',
        },
      ],
    },
  ],
};

export default tseslint.config(
  { ignores: ['node_modules/', 'ios/', 'native/', 'coverage/'] },
  js.configs.recommended,
  ...tseslint.configs.strict,
  {
    files: ['**/*.js', '**/*.mjs'],
    languageOptions: {
      globals: {
        module: 'readonly',
        require: 'readonly',
        __dirname: 'readonly',
      },
    },
    rules: { '@typescript-eslint/no-require-imports': 'off' },
  },
  {
    files: ['src/**/*.{ts,tsx}'],
    plugins: { boundaries },
    settings: {
      'import/resolver': { node: { extensions: ['.ts', '.tsx', '.js'] } },
      'boundaries/elements': LAYERS.map(type => ({
        type,
        pattern: `src/${type}`,
      })),
    },
    rules: {
      'boundaries/dependencies': [
        'error',
        {
          default: 'disallow',
          policies: Object.entries(ALLOWED_DEPENDENCIES).map(allowedPolicy),
        },
      ],
      'boundaries/no-unknown-files': 'error',
    },
  },
  {
    files: ['src/domain/**', 'src/ports/**', 'src/application/**'],
    ignores: ['**/*.test.ts'],
    rules: frameworkImportBan,
  },
  {
    files: ['src/**/*.{ts,tsx}'],
    ignores: ['src/adapters/**'],
    rules: {
      '@typescript-eslint/consistent-type-assertions': [
        'error',
        { assertionStyle: 'never' },
      ],
    },
  },
);
