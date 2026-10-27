# KAN-646 — Operation matrix: Contributor and Partner capability

**Source:** read-only reads of the live catalogue of `wtncuzcskpigqpmnxwws` on 2026-10-26/27 (`pg_get_functiondef` and `pg_proc.proacl`).

**Migration:** `supabase/migrations/20261026120000_kan646_personas_s3_capabilities.sql`. It is **not applied**.

**Probes:** `supabase/tests/kan646_personas_s3/probes.sql`. They have **not been run**.

## Truth table (the only new authorization rule)

| Capability | Legacy predicate, unchanged | New disjunct |
|---|---|---|
| player | `persona_type = 'player'` | `persona_type = 'contributor'` AND a `public.player` row exists |
| organiser | as each function already had it (see F1) | `persona_type = 'contributor'` AND a `public.organiser` row exists |
| host | `persona_type = 'host'` | `persona_type = 'partner'` AND a `public.host` row exists |

Common rules:

- Every disjunct also requires `is_active = true`.
- Ownership comes only from `effective_actor_uid()` / `auth.uid()`.
- `profile_type`, `intention` and JWT `user_metadata` are never read for persona authorization.

**`choose_actor(p_profile_type text DEFAULT 'player')`:**

1. The legacy exact match runs first, unchanged.
2. If it finds nothing, the fallback runs. It returns the caller's own active contributor (for player/organiser) or partner (for host) that has the matching extension row. It returns the **same `profiles.id`** for every type a contributor holds and orders by `created_at` with `LIMIT 1`.
3. If the fallback also finds nothing, the original `no_profile_of_requested_type` is raised.

## Matrix

Notes on the columns:

- "Gate" is the persona check inside the function.
- "Remaining predicates" lists the checks the migration does not touch and the probes assert are preserved.
- Every ACL is unchanged (R1–R3, R5) except the new `actor_is_host`.

| Operation | Signature (live) | Capability | Persona gate after KAN-646 | Extension dependency | Remaining predicates (preserved) | Changed? | Probes |
|---|---|---|---|---|---|---|---|
| Resolve actor | `choose_actor(text)` DEFINER, `search_path=public` | any | legacy exact match first, then the fallback above | player / organiser / host | owner only; active; `not_authenticated` when there is no uid | **CHANGED** (fallback inserted before the final RAISE) | A1–A15, L1, L4, L8, L11, R1, R6 |
| Player helper | `actor_is_player(uuid)` | player | `persona_type='player'` OR (contributor AND player row) | player | `is_active` | **CHANGED** | T1–T5, L3 |
| Organiser helper | `actor_is_organiser(uuid)` | organiser | `profile_type='organiser'` (legacy, kept) OR (contributor AND organiser row) | organiser | `is_active` | **CHANGED** | T1, T3, L6 |
| Host helper | `actor_is_host(uuid)` **NEW**, sql STABLE, `search_path=public, pg_temp` | host | `persona_type='host'` OR (partner AND host row) | host | `is_active` | **NEW** (EXECUTE granted to authenticated and service_role only) | T6, T7, L10, R4 |
| Meetup eligibility | `can_create_meetup(uuid)` | player or organiser | legacy `persona_type IN ('player','organiser')` OR (contributor AND (player OR organiser row)) | player / organiser | ownership, active | **CHANGED** | T8a–T8c, T9 |
| Derived capability | `actor_can(...)`, `actor_capabilities`, `assert_actor` | derived | inherits the helpers | via helpers | unchanged bodies | unchanged | T10 |
| Create game | `rpc_create_game(p_actor_type, …26 args, p_request_id)` DEFINER → `rpc_create_game_legacy_v2(…)` | player (casual) / organiser (hosted) | `persona_type IN ('player','organiser')` OR (contributor AND ((`p_actor_type='player'` AND player row) OR (`'organiser'` AND organiser row))) | player / organiser | `gtype` derived from `p_actor_type` (organiser → hosted, else casual); creator roster role `'host'`; `invalid_time_range`; `price_required` / money / commission; `is_challenge_sport`; squad rules; capacity | **CHANGED** (legacy_v2 gate only; wrapper untouched) | G1–G10, L2, L5, L9, R3 |
| Join game | `rpc_join_game`, `can_current_user_join_game` (invoker) | player | via `choose_actor('player')` + `actor_is_player` | player | frozen → `frozen`; block → `not_visible` (`can_view_with_scope`/`is_blocked`); creator → `host`; cancelled; started; already joined; `join_policy`; capacity | unchanged bodies (behaviour widens via the helpers) | J1–J4, J6–J12 |
| Leave game | `rpc_leave_game` | player | via `choose_actor` | player | `left` / `not_on_roster` / `left_promoted_waitlist` | unchanged body | J5 |
| Create meetup | `rpc_create_meetup` → `rpc_create_meetup_legacy_v2` | player / organiser | via `can_create_meetup` | player / organiser | `profile_not_owned`; visibility; `free_meetups_only`; `location_name_required`; `setting_required`; title | unchanged bodies | M1–M5, L13 |
| Post as actor | `rpc_post_as`, `create_post` | player / organiser | via `choose_actor`; partner → `actor_not_allowed` | player / organiser | author snapshot (`trgfn_posts_enforce_author_refs`) | unchanged bodies | P1–P3 |
| Challenge create | `rpc_challenge_create` | organiser | via `actor_is_organiser` | organiser | `organiser_required` | unchanged body | P4–P6, L7 |
| Sport profile | `rpc_create_sport_profile(uuid,uuid,text,integer)` DEFINER | player | legacy `persona_type='player'` (kept, see F2) OR (owned active contributor AND player row) | player | S1 deferred sports rule (`contributor_sports_incomplete`) | **CHANGED** | S1–S7 |
| Squads | `rpc_squad_create` (Dart caller), `rpc_create_squad` (no caller), `rpc_squad_add_member`, `rpc_squad_invite`, `rpc_squad_request_join` | — | **BLOCKER B1**, not defined | — | — | unchanged | Q1 (parity only) |
| Social follow/block | `trgfn_block_hoster_social`, `validate_hoster_persona`, `trgfn_validate_persona_compatibility` | — | blocks `persona_type='host'` only; a partner is **not** blocked | — | — | unchanged (**BLOCKER B3**) | none |
| Venue / host admin | `is_venue_admin`, `venue_members`, `organiser_venues` (role `'partner'`) | venue role | not persona-based | — | — | unchanged | none (unverified) |
| Messaging / profile lookup / ratings | various | — | not read in detail | — | — | unchanged (**unverified**) | none |

## Findings (pre-existing, deliberately unchanged)

- **F1:** `actor_is_organiser`'s legacy branch tests `profile_type = 'organiser'`. No live row carries that value; legacy organisers are `profile_type = 'business'`.
  - Effect: a legacy organiser is refused at `rpc_challenge_create` (`organiser_required`) and at `actor_can('host')`.
  - After KAN-646 a contributor with an organiser row passes.
  - Fixing the legacy branch changes legacy behaviour, which is out of scope. Probes L6 and L7 pin the current behaviour.
- **F2:** `rpc_create_sport_profile`'s legacy branch has no ownership check, and EXECUTE is granted to `PUBLIC`/`anon`.
  - The new contributor branch is owner-checked.
  - The legacy hole is left as is, because removing grants is forbidden by the brief. It needs a separate ticket.

## Blockers (named, never silently defaulted)

- **B1, squads.** Every squad path is broken live for every persona:
  - `rpc_squad_create` and `rpc_create_squad` gate on `profile_type IN ('player','organiser')`, which no live row carries.
  - `rpc_squad_add_member` and `rpc_squad_invite` require `profile_type='player'`.
  - `rpc_squad_request_join` calls `_profile_is_player_for_sport` and `_can_participate`, and the organiser branch of `rpc_squad_create` calls `_profile_matches_sport`. **None of these functions exists in any schema.**
  - Squad capability for Contributor/Partner cannot be defined until there is a product/CTO ruling on squads. Q1 asserts only that a contributor gets exactly the legacy player's result (`invalid_creator_role`).
- **B3, partner social.** `trgfn_block_hoster_social` bars `persona_type='host'` from social follows. Whether a Partner (the successor to host) is likewise barred is unspecified, so it is unchanged. It needs a product ruling.

## Notes

- **N2:** the invoker-rights helpers read `profiles` under RLS, so evaluating another user's contributor returns false. This fails closed (T9).
- **N3:** `choose_actor('contributor')` resolves the caller's own contributor id through the legacy exact match, which was not changed.
  - The game gate refuses that literal type (G3, `persona_not_allowed`).
  - Meetup and post accept it on the same profile, because they gate on capability rather than on the requested type.
- **AC7:** before KAN-649, re-run probes G and J against the real S2 onboarding RPC rather than the in-transaction fixtures.
