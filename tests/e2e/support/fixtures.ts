import { test as base, expect } from '@playwright/test';

/**
 * AC5 / hard requirement: "Uncaught page/runtime errors FAIL unless
 * explicitly expected; ordinary warnings are recorded, not fatal."
 *
 * This harness has exactly one standing, named exception: the placeholder
 * Supabase anon key in tests/e2e/.env.e2e (SUPABASE_ANON_KEY=
 * test-placeholder-not-a-real-key) makes every Supabase auth/session call
 * come back 401 Unauthorized. SUPABASE_URL is the real, public project
 * endpoint (not a secret — only the anon key is faked), so this is a
 * clean 401 response, not a DNS failure or a crash. It is EXPECTED until
 * a real test-safe anon key replaces the placeholder (see the KAN-166
 * Jira comment and agent/status/devops.md) — team-lead's own spike hit
 * the same 401 for the same reason.
 *
 * What this fixture does:
 *  - Classifies that one signature by name (a 401 response whose URL is
 *    the configured Supabase project) and records it via a test
 *    annotation instead of failing the test on it.
 *  - Fails the test on any OTHER uncaught page error (an unhandled JS
 *    exception) — nothing is blanket-suppressed. A real, unrelated
 *    runtime error still fails the run.
 *  - Never asserts on the classified 401 as pass/fail criteria either
 *    way — a spec that wants to check auth behaviour some other day
 *    still can; this fixture only stops it from being an unexplained
 *    failure reason.
 *
 * Separately: Auth Welcome eagerly loads Google Identity Services
 * (`accounts.google.com/gsi/client`) regardless of which button is
 * tapped — measured to throw asynchronously back into our Dart callback
 * (an uncaught page error) when it runs against a non-functional
 * placeholder OAuth client ID, on a timer that made it intermittent
 * rather than immediate. None of this harness's scenarios exercise real
 * Google sign-in, so this fixture blocks that third-party origin at the
 * network level — the same call any e2e harness makes to keep a real,
 * live third party from being an untested, flaky dependency of a test
 * that isn't about it. It is not a suppression of an error our own code
 * produces; nothing from Google ever runs in this harness.
 */
const SUPABASE_URL = process.env.SUPABASE_URL ?? '';

export const test = base.extend({
  page: async ({ page }, use, testInfo) => {
    const unexpectedErrors: string[] = [];
    let classifiedPlaceholder401Seen = false;

    await page.route('https://accounts.google.com/**', (route) =>
      route.abort(),
    );

    page.on('pageerror', (err) => {
      unexpectedErrors.push(`pageerror: ${err.message}`);
    });

    page.on('response', (response) => {
      const isKnownPlaceholder401 =
        response.status() === 401 &&
        SUPABASE_URL.length > 0 &&
        response.url().startsWith(SUPABASE_URL);
      if (isKnownPlaceholder401) {
        classifiedPlaceholder401Seen = true;
      }
    });

    await use(page);

    if (classifiedPlaceholder401Seen) {
      testInfo.annotations.push({
        type: 'known-issue',
        description:
          'Classified, non-fatal: Supabase 401 from the placeholder anon key (tests/e2e/.env.e2e). Expected until a real test-safe key is supplied — see KAN-166 Jira comment / agent/status/devops.md.',
      });
    }

    if (unexpectedErrors.length > 0) {
      throw new Error(
        `Unexpected uncaught page error(s) — not on the known-exceptions list:\n${unexpectedErrors.join('\n')}`,
      );
    }
  },
});

export { expect };
