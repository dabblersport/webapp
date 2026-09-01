---
name: onboarding-two-stage-truth
description: The PO's two-stage onboarding model vs what the code runs; onboard=TRUE is completion not resume; the orphaned stage-2 screen chain; why the KAN-48 fold was not a regression
metadata:
  type: project
---

The PO describes onboarding as two stages — (1) initial info, (2) profile creation — with
`onboard = true` set at the end of stage 1 as a **resume marker**. That is the product intent.
It is **not** what the shipped code does, and the flag polarity is inverted.

**Why:** re-audit 2026-08-30 after the PO challenged KAN-48's premise. Verified live, read-only.

**How to apply:** before touching anything onboarding, hold these five facts.

1. **The live flow is one linear pass**, all data in memory (`onboardingDataProvider`), one
   write at `onboarding_welcome_screen.dart:83` -> `auth_service.dart:1156`. There is no
   later session in which stage 2 happens.
2. **`onboard = FALSE` is the resume marker.** `checkResumeState` sends `onboard = true` to
   step `completed` -> no redirect -> home. No path takes an `onboard = true` profile into
   any further onboarding step. Stub written with `'onboard': false` at
   `auth_service.dart:733`. Live: 2 rows `false` (Jan 2026), 154 `true`.
3. **`rpc_onboard_profile` is the only function in the DB that sets `onboard = true`**
   (pg_proc scan). The other writer, `OnboardingRepository.finalizeOnboarding:327`, is dead.
4. **A stage-2 screen chain exists and is orphaned** — onboarding_sports -> preferences ->
   privacy -> completion, routed at `app_router.dart:710-743`, with no inbound reference
   outside its own back-links. This is probably the stage 2 the PO remembers. Whether to wire
   it or delete it is a **cpo** question. See [[dead-and-wired-router-controller]].
5. **The KAN-48 fold was not a regression** — it did not move where `onboard = true` sits in
   the journey. Rollback rejected. Its one new failure (organiser RAISE on null sport) is
   unreachable because `primary_sport_selection_screen.dart:56,:201` make sport mandatory —
   which makes that a **client guarantee the RPC now depends on**.

**Damage census, re-derived:** 48 missing persona rows (36 player / 9 organiser / 3 host) and
5 (not 6) player sport gaps. **47 of 48 were last seen a day+ after creation** and **none was
created after 2026-04**; 70 onboards since 2026-05 have zero gaps. Historical cohort, not
paused users, not an active leak. See [[load-bearing-measurements]].

**Lesson:** the PO's model of their own product describes intent that may exist in the repo as
built-but-unreachable screens. Do not treat "the PO says X" or "the code says not-X" as
settling it — both were true here, about different code. See [[verification-lessons]].
