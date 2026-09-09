import { defineConfig, devices } from '@playwright/test';

// Timing/retry bounds are CEO Sec20 ceilings (confirmed, KAN-166 comment
// 2026-09-09T21:25) — not targets. Raising any of these requires evidence,
// not convenience.
const SERVER_READY_TIMEOUT_MS = 60_000; // application startup
const NAVIGATION_TIMEOUT_MS = 15_000; // route settle
const UI_STATE_TIMEOUT_MS = 10_000; // expected-UI-state assertion
const TEST_TIMEOUT_MS = 90_000; // upper end of the 60-90s individual-test bound

const PORT = process.env.E2E_PORT ?? '4173';
const BASE_URL = `http://127.0.0.1:${PORT}`;

export default defineConfig({
  testDir: './tests/e2e',
  testMatch: ['**/*.spec.ts'],
  // The deliberately-failing proof lives outside the normal run — see
  // tests/e2e/synthetic-failure.spec.ts and `npm run test:e2e:failing`.
  testIgnore: ['**/*.synthetic.spec.ts'],

  timeout: TEST_TIMEOUT_MS,
  expect: { timeout: UI_STATE_TIMEOUT_MS },

  fullyParallel: false,
  forbidOnly: !!process.env.CI,

  // "Identical-state / no-progress retry: 0" (CEO Sec20) — never rerun a
  // test against the same stuck state.
  retries: 0,

  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
  ],

  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    navigationTimeout: NAVIGATION_TIMEOUT_MS,
    actionTimeout: UI_STATE_TIMEOUT_MS,
  },

  projects: [
    // AC1: exactly one browser project, Chromium. No firefox/webkit here —
    // do not add one without a CEO condition change (single-browser
    // ownership).
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],

  webServer: {
    // Serves the already-built static bundle (see tests/e2e/support/static-server.mjs).
    // The build itself happens in `npm run e2e:build`, which `test:e2e` runs
    // first — kept out of this command so the 60s server-ready ceiling
    // times only "start serving", not "compile the whole app" (a flutter
    // release build routinely exceeds 60s on its own).
    //
    // "Infrastructure retry: MAX 1" (CEO Sec20) has no first-class knob in
    // Playwright's webServer config — it does not itself retry a failed
    // boot. That bound is honoured operationally: if the server fails to
    // come up within the timeout below, the run fails once; any retry is a
    // manual, capped-at-one re-run of `npm run test:e2e`, not an automated
    // loop configured here.
    command: 'node tests/e2e/support/static-server.mjs',
    url: BASE_URL,
    timeout: SERVER_READY_TIMEOUT_MS,
    reuseExistingServer: !process.env.CI,
    env: { E2E_PORT: PORT },
  },
});
