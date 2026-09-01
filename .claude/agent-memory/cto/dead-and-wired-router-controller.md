---
name: dead-and-wired-router-controller
description: A controller can be dead by method and live by provider — onboarding_controller.dart's writes have no call sites while the router reads its state on every load
metadata:
  type: feedback
---

**Judge dead code per-method, not per-file, and check whether anything *reads* it before calling
it unwired.**

**Why:** `lib/features/auth_onboarding/presentation/controllers/onboarding_controller.dart` was
reported twice (KAN-46 and KAN-48 comments) as an unused parallel onboarding architecture, on the
true observation that `selectPersona()` has zero call sites. But its *read* half is load-bearing
for production routing: `app_router.dart:304-308` reads `onboardingControllerProvider`, `:312-318`
fires `checkResumeState()` on every authenticated app load, `:322-338` maps its `step` to a
redirect. Deleting it as dead code would have broken routing; leaving it as "dead, clean up later"
left a router steering on state nothing advances. This is the `T-007` dead-but-wired shape, and
the file-level read missed it in both directions.

Note there are also **two different classes both named `OnboardingController`** in this repo
(`features/auth_onboarding/presentation/controllers/` and `features/profile/services/`), each with
its own `onboardingControllerProvider`. A grep on the class name alone conflates them.

**How to apply:** when an agent reports a file as unused, grep the provider/symbol separately from
the methods, and check `app_router.dart` specifically — the router is the most common consumer
that makes "unused" code live. Ruled in `T-037`; see [[onboarding-write-path-facts]] and
[[verification-lessons]].
