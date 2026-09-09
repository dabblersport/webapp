import { test, expect } from '@playwright/test';

// Deliberately-failing proof of the failure path (KAN-166 hard requirement).
// It asserts a nonexistent element is visible, so it always fails inside
// the expect timeout — it does not touch or break any Product source.
//
// Excluded from the normal run: playwright.config.ts's testIgnore matches
// `**/*.synthetic.spec.ts`. Run it on purpose with:
//
//   npm run test:e2e:failing
//
// It should fail within the 10s expected-UI-state bound, produce a
// screenshot + trace under test-results/, and exit non-zero without
// looping (retries: 0, no infrastructure retry needed since the app
// server is already up).
test('synthetic failure: asserts a nonexistent element is visible', async ({
  page,
}) => {
  await page.goto('/');
  await expect(
    page.getByRole('button', { name: 'this-control-does-not-exist-kan-166' }),
  ).toBeVisible({ timeout: 10_000 });
});
