---
name: auth-uid-already-in-state
description: Before authoring an id-resolver RPC, check whether the screen already loaded the value; and profiles.user_id is anon-readable (154 uids, KAN-106)
metadata:
  type: project
---

**Two facts from the KAN-87 / T-041 ruling, 2026-08-31.**

**1. `user_profile_screen.dart` already holds the viewed user's genuine auth uid.**
`ref.read(profileControllerProvider).profile?.userId` — `UserProfile.userId` is non-nullable and comes from `supabase_profile_repository.dart`'s `_baseProfileColumns`, which includes `user_id`. When `profileId` is supplied the fetch goes by profile id and *still* returns `user_id` (`profile_repository_impl.dart:33-42`).

**Why:** `flutter-feature-agent` escalated that the game-creator-card path "has no genuine auth uid available at all" post-SEC-17 and offered only two options — a `profile_id → user_id` RPC, or disabling Block/Report/Message. Both were wrong; the value was in state, the actions were reading `widget.userId`.

**How to apply:** when an agent reports "the id we need is not available client-side", check what the screen already fetched before authorising a resolver RPC. A definer endpoint whose job is handing out an `auth.users` id is a *new* PII surface — never the cheap option. See [[jwt-profile-id-claim-trap]], [[definer-rpc-exposure]].

**2. `public.profiles` hands 154 distinct raw `auth.users` UUIDs to `anon`** — policy `profiles_select_public` `USING (is_active = true)` with `polroles = NULL` (PUBLIC), plus an `anon` column grant on `user_id`. Measured with a `SET LOCAL ROLE anon` probe, read-only.

**Why:** it is six times the 26 uuids KAN-87 removes from `v_game_card`. **KAN-87 does not close the SEC-17 class** — the base table is the larger surface. Filed as **KAN-106** (parent KAN-2).

**How to apply:** do not treat SEC-17 as closed when KAN-87 ships. And per [[policy-role-vs-check-trap]], the `polroles = NULL` reading alone would not have been proof — the role probe was.
