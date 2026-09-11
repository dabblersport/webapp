import { test, expect } from './support/fixtures';
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

  // Disambiguated per KAN-166 AC-4 (amended): a bare /continue/i matches
  // BOTH "Continue with Google" and "Continue with Email" on this screen
  // (2 results -> Playwright strict-mode failure), so the names must be
  // specific here. Landing's Continue button above stays a bare
  // /continue/i because it is the only match there.
  const googleButton = page.getByRole('button', {
    name: /continue with google/i,
  });
  const emailButton = page.getByRole('button', {
    name: /continue with email/i,
  });

  await expect(googleButton).toBeVisible();
  await expect(googleButton).toBeEnabled();
  await expect(emailButton).toBeVisible();
  await expect(emailButton).toBeEnabled();
});
