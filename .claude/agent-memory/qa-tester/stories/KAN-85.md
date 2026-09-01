# KAN-85 — Following reachable — re-verification story

Status per docs: closed 2026-08-29 (RealFriendsScreen was fully functional but had no
nav item; a nav entry was added).

## Steps
1. Sign in with QA account. From the main nav / profile screen, locate the new
   "Following" (or Friends) entry point — screenshot where it lives (tab bar, profile
   menu, etc.) since this is exactly the "was unreachable" defect.
2. Tap it. Expected: lands on RealFriendsScreen (or equivalent), not a 404/error page.
3. Verify the four data-surface states on this screen where applicable: loading
   flash, empty state (if QA account follows no one), populated list (if it does),
   and an error state (toggle offline or hit an unreachable backend if feasible).
4. From the screen, test any action available (follow/unfollow/view profile) —
   state expected outcome, click, verify network request succeeds, reload and
   re-check persistence.
5. Confirm back navigation from this screen returns to where the user came from.
6. Hard-reload directly on the following/friends route URL if it has one —
   confirm it restores the same screen rather than bouncing to landing/home.

## Result — executed 2026-08-29

**Nav reachability: PASS.** Reached via profile "N Following" stat tap → Community
screen (Following/Followers tabs). Note: could not confirm true 390px mobile-width
bottom-nav rendering this session — `resize_window` did not actually change
`window.innerWidth` (stayed ~606 regardless of requested size), so this was tested
under the app's wider/desktop-style layout, not confirmed mobile. Per KAN-85's own
fix, Community is intentionally flag-gated OFF on true mobile bottom-nav
(`FeatureFlags.enableCommunityMobileNav`, default false) — reachable via desktop
side-nav only, which is consistent with what I saw.

**New bug found on the screen KAN-85 made reachable — filed KAN-91 (HIGH).**
Following-tab rows show "Follow" (wrong) instead of "Unfollow" for users already
followed, on every fresh load. Clicking sends a real `POST profile_follows` that
returns 409, but the UI silently flips ALL rows to "Unfollow" as if it succeeded.
Reproduced 2/2 clean runs from cold load. No real follow-state mutation occurs
(reload reverts to "Follow" again) — it's a client-side display/state bug, not a
persistence issue.

## Pass/fail criteria
- FAIL (HIGH) if the nav entry is still missing/unreachable (regression of the
  exact fixed defect).
- FAIL (MEDIUM) if the screen loads but a data state (empty/error) is missing or
  broken.
- FAIL (HIGH) if a follow/unfollow action is a silent failure (request fails but
  UI shows success).
