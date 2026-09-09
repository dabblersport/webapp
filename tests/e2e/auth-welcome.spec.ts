import { test, expect } from '@playwright/test';
import { enableSemantics } from './support/semantics';
import { RoutePaths } from './support/route-paths';

// AC4: a second, deeper scenario that stays read-only — no DB mutation, no
// money-layer mutation, no CEO authorization needed. It only asserts that
// the two continue controls on Auth Welcome are present and enabled; it
// never actually signs in.
test('auth welcome offers both Google and Email continue controls, enabled', async ({
  page,
}) => {
  await page.goto('/');
  await expect(page).toHaveURL(new RegExp(`${RoutePaths.landing}$`), {
    timeout: 15_000,
  });

  await enableSemantics(page);
  await page.getByRole('button', { name: /continue/i }).click();

  await expect(page).toHaveURL(new RegExp(`${RoutePaths.authWelcome}$`), {
    timeout: 10_000,
  });

  // Semantics is a per-page-render tree; re-assert it's on for this route
  // rather than assuming the earlier enable carried over.
  await enableSemantics(page);

  const googleButton = page.getByRole('button', { name: /google/i });
  const emailButton = page.getByRole('button', { name: /email/i });

  await expect(googleButton).toBeVisible();
  await expect(googleButton).toBeEnabled();
  await expect(emailButton).toBeVisible();
  await expect(emailButton).toBeEnabled();
});
