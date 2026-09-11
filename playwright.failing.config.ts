import { defineConfig } from '@playwright/test';
import baseConfig from './playwright.config';

// Runs ONLY the deliberately-failing proof (tests/e2e/synthetic-failure.synthetic.spec.ts),
// which the base config's testIgnore deliberately excludes from the normal
// `npm run test:e2e` run. Invoke with `npm run test:e2e:failing`.
export default defineConfig(baseConfig, {
  testIgnore: [],
  testMatch: ['**/*.synthetic.spec.ts'],
});
