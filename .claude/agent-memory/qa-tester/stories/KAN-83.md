# KAN-83 — Full onboarding incl. back navigation — re-verification story

Status per docs: closed 2026-08-29 (fixed a GoRouter error page hit on back-nav during
onboarding).

## Steps
1. Use QA account (or a fresh signup if onboarding only triggers pre-`onboard=true`).
   If QA account has already completed onboarding, check whether there's a way to
   re-trigger it (deep link to first onboarding step) — if not, note as
   blocked-partial and test back-nav on whatever onboarding steps are reachable.
2. Walk forward through every onboarding step (persona selection, sport selection,
   location, any additional steps) screenshotting each screen.
3. At EACH step, press the in-app back button (not browser back) and confirm it
   returns to the previous onboarding step — not a GoRouter error/"page not found"
   screen. This is the specific defect KAN-83 fixed.
4. Additionally test browser Back button at 2-3 points mid-onboarding — confirm it
   doesn't drop to an error page or a broken state either (sweep #1 requirement).
5. Complete onboarding fully once, confirm it lands on the expected post-onboarding
   screen (home/feed) and `onboard=true` gets set (verify by reloading — should not
   re-show onboarding).
6. Check console for uncaught exceptions at each transition.

## Result — executed 2026-08-29/30 — PARTIAL / BLOCKED

Could not run the full forward-through-onboarding-with-back-nav walkthrough: the
QA account (`Dabbler-Test`) is already fully onboarded (persona, sport, `onboard=
true` set), and there's no safe in-app way to re-trigger a fresh onboarding run
without risking real data changes to the shared QA account. This part of KAN-83's
acceptance criteria (back button at each step doesn't hit a GoRouter error page)
remains UNVERIFIED by direct walkthrough this session.

**New bug found instead, while probing onboarding routes directly — filed
KAN-96 (MEDIUM).** Navigating to `/onboarding-welcome` as an already-onboarded
user shows "Setting up your account..." and hangs forever — three progress items
never check off, no network POST/PATCH fires (only GETs), no console error, no
back/cancel/timeout. Confirmed the account itself wasn't corrupted (home loaded
fine after manually navigating away). Router comment confirms this route is
deliberately excluded from the redirect gate ("Progress screen — must not be
gated"), so this dead-end is reachable, just not through any normal button today.

**Recommendation:** either provision a disposable/resettable test account for a
full onboarding walkthrough, or have `task-auditor`/`cto` confirm via code review
that the KAN-83 GoRouter-error-page fix (back nav mid-onboarding) hasn't
regressed, since I could not exercise it live this pass.

## Pass/fail criteria
- FAIL (CRITICAL) if back nav at any step still hits a GoRouter error page —
  this was the exact defect; a regression here blocks a launch-critical path.
- FAIL (MEDIUM) if browser Back causes a broken/blank state but in-app back works.
- FAIL (HIGH) if completing onboarding doesn't persist (`onboard=true` not set,
  re-shows onboarding on reload) — ties to KAN-48 (onboarding can silently fail to
  write persona/sport rows).
