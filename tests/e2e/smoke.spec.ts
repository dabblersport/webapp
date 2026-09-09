import { test, expect } from '@playwright/test';
import { enableSemantics } from './support/semantics';
import { RoutePaths } from './support/route-paths';

// AC3: deterministic smoke test — Landing -> enable semantics -> Continue
// -> Auth Welcome. Matches the sequence team-lead proved end to end in the
// KAN-166 spike (see the ticket's revision comment for the measured facts).
test('landing loads, Continue is reachable by role, and it navigates to Auth Welcome', async ({
  page,
}) => {
  await page.goto('/');

  // Navigation / route-settle bound: 15s (CEO Sec20).
  await expect(page).toHaveURL(new RegExp(`${RoutePaths.landing}$`), {
    timeout: 15_000,
  });

  await enableSemantics(page);

  const continueButton = page.getByRole('button', { name: /continue/i });
  await expect(continueButton).toHaveCount(1);
  await continueButton.click();

  // Expected-UI-state bound: 10s (CEO Sec20).
  await expect(page).toHaveURL(new RegExp(`${RoutePaths.authWelcome}$`), {
    timeout: 10_000,
  });
});
