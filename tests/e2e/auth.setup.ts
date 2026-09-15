import { test as setup, expect } from './support/fixtures';
import { enableSemantics } from './support/semantics';
import { RoutePaths } from './support/route-paths';

/**
 * Signs in ONCE per run and saves the browser session to disk, so no spec
 * has to repeat the login flow. Every other project depends on this one and
 * starts already authenticated (see `storageState` in playwright.config.ts).
 *
 * Why a saved session and not a login step in each spec: the app keeps its
 * Supabase session in localStorage (`main.dart:167` initialises Supabase with
 * no custom storage), so a saved storageState restores a real, live session.
 * Repeating the login per spec would add a network round-trip and three
 * screens of UI to every scenario and prove nothing new after the first time.
 *
 * Credentials come from the environment — `tests/e2e/.env.e2e`, which is
 * gitignored (.gitignore:214) — and never from this file, which is committed.
 */
export const AUTH_FILE = 'tests/e2e/.auth/user.json';

const EMAIL = process.env.E2E_EMAIL ?? '';
const PASSWORD = process.env.E2E_PASSWORD ?? '';

setup('log in once and save the session', async ({ page }) => {
  setup.skip(
    EMAIL.length === 0 || PASSWORD.length === 0,
    'E2E_EMAIL / E2E_PASSWORD not set — no test account supplied.',
  );

  // ---- 1. Landing: a single "Continue" CTA (app_en.arb:60) --------------
  await page.goto('/');
  await expect(page).toHaveURL(new RegExp(`${RoutePaths.landing}$`), {
    timeout: 15_000,
  });
  await enableSemantics(page);
  await page.getByRole('button', { name: /^continue$/i }).click();

  // ---- 2. Auth Welcome --------------------------------------------------
  // Four controls here: Continue with Google / Apple / Email, plus the
  // existing-account link. The first three all start a NEW account; only
  // "Already have an account? Log in" signs an existing one in, and it goes
  // straight to the password screen (auth_welcome_screen.dart:220).
  await expect(page).toHaveURL(new RegExp(`${RoutePaths.authWelcome}$`), {
    timeout: 10_000,
  });
  await enableSemantics(page);
  await page
    .getByRole('button', { name: /already have an account\?\s*log in/i })
    .click();

  // ---- 3. Login: email + password + "Login" -----------------------------
  await expect(page).toHaveURL(new RegExp(`${RoutePaths.enterPassword}$`), {
    timeout: 10_000,
  });
  await enableSemantics(page);

  // Two inputs on this screen (email_password_screen.dart:484,529), both
  // present in the DOM from arrival, each inside its own flt-semantics node.
  //
  // CLICK FIRST, THEN TYPE — `fill()` does not work here and fails silently.
  // Those <input> elements are Flutter's ACCESSIBILITY mirror, not its
  // editing surface; the real one is FLT-TEXT-EDITING-HOST, which only
  // receives text once the field is focused. `fill()` writes straight to the
  // mirror's value, Flutter never hears it, and the rendered field stays
  // empty while Playwright reports success — measured, with the Login button
  // left disabled and both fields showing their hints.
  const emailField = page.locator('input[autocomplete="email"]');
  const passwordField = page.locator('input[type="password"]');
  await expect(emailField).toHaveCount(1);
  await expect(passwordField).toHaveCount(1);

  // The pause after each click is load-bearing, not padding. Flutter attaches
  // its editing host asynchronously, and typing immediately drops the FIRST
  // character — measured: "dabbler.pro@proton.com" arrived as
  // "abbler.pro@proton.com", and the app answered "Invalid email or
  // password", which reads like bad credentials and is not.
  await emailField.click();
  await page.waitForTimeout(400);
  await page.keyboard.type(EMAIL, { delay: 25 });

  await passwordField.click();
  await page.waitForTimeout(400);
  await page.keyboard.type(PASSWORD, { delay: 25 });

  // Prove what was actually typed before submitting. Without this, a dropped
  // character surfaces three steps later as a credentials error and sends
  // whoever reads it hunting the wrong bug.
  await expect(emailField).toHaveValue(EMAIL);
  await expect(passwordField).toHaveValue(PASSWORD);

  const loginButton = page.getByRole('button', { name: /^login$/i });
  await expect(loginButton).toBeEnabled({ timeout: 10_000 });
  await loginButton.click();

  // ---- 4. Signed in -----------------------------------------------------
  // An onboarded account lands on /welcome, not /home
  // (email_password_screen.dart:139). An account with no profile goes to
  // /create-user-info instead; this assertion fails there on purpose, and
  // the failure message carries the URL actually reached.
  // Auth round-trip bound: 20s — longer than a UI-state bound because this
  // waits on a real Supabase call.
  await expect(page).toHaveURL(new RegExp(`${RoutePaths.welcome}$`), {
    timeout: 20_000,
  });

  await page.context().storageState({ path: AUTH_FILE });
});
