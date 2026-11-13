# KAN-644 Personas S1 – schema, intention, single-profile guards

Migration: `supabase/migrations/20261026100000_kan644_personas_s1_schema_guards.sql` (AUTHORED, NOT APPLIED).
Files here: `probes.sql` (transactional, ends in ROLLBACK), `catalog_capture.sql` (read-only before/after diff for Ops),
`rollback.sql` (refuses while any new-persona row or intention exists).

Contract notes for story 2 (the onboarding RPC):
- `profiles.onboard` defaults to TRUE. Insert a unified row with `onboard=false` and no intention; set
  `onboarding_intention`, the player/organiser (or host) rows, `interests` (Following, includes Primary) and the Primary
  `sport_profiles` row, then set `onboard=true`. The sports rule is a deferred constraint, checked at COMMIT.
- Take the same lock first: `pg_advisory_xact_lock(hashtextextended('profiles:user:' || user_id::text, 0))` (the trigger does too).
- Writes of new personas / intention must come from a SECURITY DEFINER function (current_user postgres); client roles get `persona_write_via_rpc_only`.
- Following = `profiles.interests`, Practicing = `sport_profiles.sport_id`, Primary = `profiles.primary_sport`, `preferred_sport` untouched.
- Not changed here (named for the owning story): `choose_actor` still matches exact `persona_type`, so `choose_actor('player'|'organiser')`
  fails for a Contributor; the live host guard text could not be read (repo baseline says `hoster`, live CHECK says `host`), so the new host
  guard accepts `host`, `hoster`, `partner`.
