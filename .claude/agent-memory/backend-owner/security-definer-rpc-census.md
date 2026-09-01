---
name: security-definer-rpc-census
description: KAN-77 census found 61 of 303 public SECURITY DEFINER functions with no visible internal auth check; 3 confirmed real leaks including unauthenticated account creation via create_seed_user.
metadata:
  type: project
---

On 2026-08-29, per KAN-77, ran a full census of `public` schema `SECURITY DEFINER`
functions (they're all exposed as PostgREST RPCs, same shape as [[rls-policy-count-is-not-permission]]
and [[jwt-claim-predicate-narrower-than-lookup]]):

- 303 total SECURITY DEFINER functions in `public`.
- 192 take an identifier arg (uuid/bigint/integer/`_id`) AND grant EXECUTE to anon/authenticated.
- 61 of those have no literal `auth.uid()`/`auth.jwt()`/`is_circle_member`/`owner_profile_id`/
  legacy-GUC reference in `prosrc` — candidates for the circle_member_count pattern.

Spot-checking the 61 showed most route through `public.is_admin()`/`admin_actor()`
internally (regex false positive — those check auth just fine). But three are
**confirmed real, unfixed** as of that date:

1. `create_seed_user` (4 overloads) — zero auth check, inserts directly into
   `auth.users` with hardcoded password `[REDACTED — see KAN-78]`, callable by anon. Highest
   severity of anything found — unauthenticated account creation, not just a read leak.
2. `get_user_fcm_tokens(target_user_id uuid)` — no auth check, leaks push tokens
   for any user id.
3. `get_profile_by_id(p_profile_id uuid)` — no auth check, `row_to_json` of the
   full profiles row for any id.
4. **(2026-09-01, KAN-106 sweep)** `whois(p_username text)` — zero auth check,
   `EXECUTE`-granted to anon, resolves any username straight to its raw
   `profiles.user_id` (`auth.users` UUID). Not called anywhere in `lib/` — live,
   reachable via the publishable key, dead to the app. Also found but not yet
   individually audited: `rpc_search_users`, `rpc_get_friends`,
   `rpc_get_friend_suggestions`, `rpc_friend_requests_inbox`/`_outbox`,
   `admin_whois_profile` all return `user_id` and are anon-executable — worth a
   follow-up pass. Filed as its own finding on KAN-106, not folded into that
   ticket's scope (base-table column grant fix).

**A column-level `REVOKE` on a table never closes one of these.** A
`SECURITY DEFINER` function reads with the *definer's* privileges, not the
caller's — it bypasses column/row grants entirely. If a table column leak and
a definer-function leak of the same column coexist (as with `profiles.user_id`
and `whois`), they need two separate fixes; closing the grant does nothing to
the function.

**Why this matters for future work:** any new SECURITY DEFINER function with an
id-shaped argument must be checked for this pattern before it ships — PostgREST
exposes it whether or not that was intended, and `EXECUTE` defaults are broad.

**How to apply:** before authoring or reviewing any SECURITY DEFINER function,
grep its body for an explicit `auth.uid()`-rooted authorization check (or
`is_admin()`/`admin_actor()` for privileged ops) — absence is not proof of safety,
but presence of an identifier arg + no check is a strong signal to escalate, not fix
silently. The three above are unresolved — check ticket status before assuming fixed.
