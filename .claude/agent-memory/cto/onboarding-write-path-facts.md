---
name: onboarding-write-path-facts
description: The live onboarding path is three calls from onboarding_welcome_screen; rpc_onboard_profile IS live (reached via a constant); completeOnboarding is dead; the persona table is `host` not `hoster`
metadata:
  type: project
---

Facts about the Dabbler onboarding write path, verified live 2026-08-29 for `T-037` (KAN-48).

**The live path is `onboarding_welcome_screen.dart:_runCreation()` (`:60-120`), three calls:**

1. `AuthService.createProfileStep` (`auth_service.dart:1122`) → calls **`rpc_onboard_profile`**
   at `:1156`.
2. `AuthService.createPersonaProfileStep` (`:1174`) → direct client INSERT; **three genuinely
   empty `catch (_) {}` at `:1189`, `:1201`, `:1213`**.
3. `AuthService.createSportProfileStep` (`:1220`) → `rpc_create_sport_profile`, **only when
   `intention == 'player'`** (`welcome_screen:114`) — non-players having no `sport_profiles`
   row is by design, not a defect.

**`AuthService.completeOnboarding` (`:818-1113`) is DEAD** — its only caller is the unreachable
`features/profile/services/onboarding_controller.dart:283`. Its catches use `debugPrint`. Two
reviewers (and my own first pass) mistook it for the live path and reported "the empty catches
are gone". They were reading the dead function.

**`rpc_onboard_profile` IS live — I wrongly reported it had zero call sites.** It is reached
through `SupabaseConfig.rpcOnboardProfileFn`, never as a literal. See
[[verification-lessons]]: in this repo a literal grep proves nothing; resolve the name through
its constant or through `pg_proc`. Verified from `pg_proc`: `SECURITY DEFINER`,
`SET search_path TO 'public'`, enforces `auth.uid() = p_user_id`, normalises `hoster`→`host`
server-side, sets `onboard = true`, assigns the default tier — one transaction. It does **not**
create the persona-extension or `sport_profiles` row; that gap is the whole of KAN-48.

**The persona table is `public.host`, not `hoster`.** `SupabaseConfig.hosterTable = 'hoster'`
(`supabase_config.dart:189`) names a nonexistent relation; the insert throws and `:1213`
discards it. Prod `persona_type` values are `player`/`organiser`/`socialiser`/**`host`**.
Canonical vocabulary per `T-037` is the DB's; `hoster` is banned.

**`profile_completion` is NULL on 156 of 156 rows** — only the unreachable
`onboarding_repository.dart` (`:202,299,323`) writes it, so every branch reading it in
`onboarding_controller.dart:_resumeFromProfile` (`:145`, `:151`) is dead and the ladder falls
to the "Unknown state" `else` at `:154-156` — the KAN-46 producer.

Related: [[dead-and-wired-router-controller]].
