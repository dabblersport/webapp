import type { Page } from '@playwright/test';

/**
 * Flutter Web's semantics tree is OFF on first paint (measured: 0
 * `flt-semantics` nodes). Flutter itself renders a
 * `<flt-semantics-placeholder aria-label="Enable accessibility">` node for
 * exactly this reason; dispatching a click on it turns the tree on
 * (measured: 0 -> 14 nodes on the Landing screen). This is a
 * framework-provided mechanism, not a workaround, and it is a required
 * first step before any `getByRole` selector will resolve.
 *
 * Idempotent: once enabled, the placeholder node is gone for the rest of
 * the session (it does not reappear on a client-side route change), so a
 * second call on a later screen is a harmless no-op rather than a hang.
 */
export async function enableSemantics(page: Page): Promise<void> {
  const alreadyOn = await page.evaluate(
    () => document.querySelectorAll('flt-semantics').length > 0,
  );
  if (alreadyOn) {
    return;
  }

  const placeholder = page
    .locator('flt-semantics-placeholder, [aria-label="Enable accessibility"]')
    .first();
  await placeholder.waitFor({ state: 'attached' });

  // Flutter positions this node off-screen for screen readers (that's the
  // point — it's not meant to be seen). A pointer-based click fails
  // Playwright's viewport check even with `force`, so dispatch a real DOM
  // click event directly instead, which is what a screen reader's virtual
  // cursor does anyway.
  await placeholder.dispatchEvent('click');

  await page.waitForFunction(
    () => document.querySelectorAll('flt-semantics').length > 0,
  );
}
