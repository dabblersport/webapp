# KAN-645 — Personas S2: atomic unified onboarding

Migration: `supabase/migrations/20261026110000_kan645_rpc_onboard_unified_profile.sql` (AUTHORED, NOT APPLIED; story 6 applies it, after KAN-644's `20261026100000`).

## Contract
`public.rpc_onboard_unified_profile(p_user_id uuid, p_display_name text, p_username text, p_age integer, p_gender text, p_onboarding_intention text, p_preferred_sport uuid DEFAULT NULL, p_interests uuid[] DEFAULT NULL, p_country text DEFAULT NULL, p_city text DEFAULT NULL) RETURNS uuid`
SECURITY DEFINER, `search_path = public, pg_temp`, owner postgres. EXECUTE: `authenticated`, `service_role` only. Caller must be `auth.uid() = p_user_id`.

| intention | persona | records created (all on the one `profiles.id`) |
|---|---|---|
| `connect_play`, `play_organise`, `organise` | `contributor` | `player`; `organiser(sport = Primary key)`; `sport_profiles(Primary, skill 1)`; default tier |
| `host_games` | `partner` | `host` (existing defaults: pending, unverified); default tier |

Legacy carriers on INSERT only: contributor `personal / is_player=true / intention='player'`; partner `venue / false / 'host'`. `onboard=true` is the last statement.
Primary (`p_preferred_sport`) is required for both personas (the existing `primary_sport` CHECK). Contributor Following = distinct `p_interests` ∪ Primary, Primary first, no count cap, stored in `profiles.interests`; Following-only sports get no `sport_profiles` row. Partner stores `p_interests` as given.

## Replay / resume (all under KAN-644's lock `pg_advisory_xact_lock(hashtextextended('profiles:user:'||user_id,0))`, all rows read)
| state of the account | result |
|---|---|
| no profile | create |
| one unified, incomplete, same persona | resume that row (intention may change among the first three) |
| one unified, completed, same persona | return the same id; nothing reset or overwritten (saved intention kept) |
| one unified, different persona | `persona_change_not_supported` |
| one legacy | `legacy_profile_requires_existing_flow` |
| more than one (any `is_active`) | `profile_migration_required` |

Other codes (exception message): `access_denied`, `invalid_onboarding_intention`, `invalid_display_name` (2–50), `invalid_username` (`^[a-zA-Z0-9_]+$`), `invalid_age` (13–120, as the existing profile editor), `invalid_gender` (NULL, male, female), `invalid_country` (not in `ref_countries`), `primary_sport_required`, `invalid_sport` (not an active sport), `invalid_interests`, `username_taken`, `onboarding_incomplete`; from KAN-644: `single_profile_required`, `contributor_sports_incomplete`.

## Legacy `rpc_onboard_profile`
Not edited. KAN-644's guards already refuse it for unified accounts (`persona_conversion_blocked`, whole call rolled back) and its own vocabulary check rejects `contributor`/`partner`. Probes P7a–P7f prove both and that a legacy-only user still onboards. Ops must confirm P7c/P7e against the **live** body (the repo copy of the live function is the KAN-48 file under `supabase/schema/migrations/`, which is not in `supabase/migrations/`).

## Avatar
Not in the DB path. The client uploads after the RPC returns the id and retries/falls back as today; a failed upload cannot create a second profile because a retry returns the same id.

## For Ops (story 6)
1. Apply KAN-644, then this migration. 2. Run `probes.sql` (ends in ROLLBACK; raises on any failed probe). 3. Do the manual two-session block at the bottom of `probes.sql`. Rollback: `rollback.sql` (drops the RPC only).
Unverified until run: validation bounds are taken from the existing client/profile editor, not from a DB rule; the live `rpc_onboard_profile` body was not readable from this team.
