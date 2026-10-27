# KAN-674 — F1 read-back and probe notes

Migration: `supabase/migrations/20261027110000_kan674_organiser_predicate_persona_type.sql`.
Applied by Ops (Memphis). The team ran none of this SQL: there is no database access on this branch.
Each block below is run by Ops after applying, and its output is pasted on KAN-674.

## 0. Deviation from the literal ruling (one)

The ruled body was `persona_type='organiser' AND is_active = true`. The live function is not the baseline body:
KAN-646 (`20261026120000`) already made a contributor with an `organiser` row an organiser, and probes T1–T6 rely on it.
The migration keeps that branch and replaces only the dead `profile_type = 'organiser'` clause:
`is_active = true AND (persona_type = 'organiser' OR (persona_type = 'contributor' AND EXISTS organiser row))`.
A plain `persona_type='organiser' AND is_active` body would flip T2 and the other contributor probes.

## 1. Definition read-back (C3)

```sql
SELECT pg_get_functiondef('public.actor_is_organiser(uuid)'::regprocedure);
SELECT prosecdef, provolatile, prorettype::regtype, proconfig
FROM pg_proc WHERE oid = 'public.actor_is_organiser(uuid)'::regprocedure;
```

Expected: `persona_type = 'organiser'` and `is_active = true` in the body, `(p_profile_id uuid)`,
`prosecdef = false` (SECURITY INVOKER), `provolatile = 's'` (STABLE), `proconfig = {search_path=public, pg_temp}`.

## 2. Privilege read-back (C4)

```sql
SELECT p.oid::regprocedure AS fn,
       has_function_privilege('anon', p.oid, 'EXECUTE')          AS anon,
       EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee = 0) AS public_grant,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  AS service_role
FROM pg_proc p
WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'actor_is_organiser';
```

Expected after this migration: grants UNCHANGED (anon true, authenticated true, service_role true), because of the
precondition below. Decision needed, see section 6.

**Precondition result.** `public.v_access_matrix` (baseline :25032) is `security_invoker`, is granted SELECT to `anon`
(baseline :38646), and calls `can_create_game(...)`, which calls `actor_is_organiser`. As anon, `auth.uid()` is NULL so the
view returns 0 rows today; with anon EXECUTE revoked it would raise `permission denied for function actor_is_organiser`.
So no REVOKE was issued.

## 3. View diff against baseline (C5)

Baseline `:25086-25104` against the migration: same `WITH (security_invoker='true')`, same CTE `pref`, same three columns in
the same order (`preferred_actor_type`, `player_profile_id`, `organiser_profile_id`). Only two predicates differ:

- `player_profile_id`: `profile_type = 'player'` → `persona_type = 'player'`
- `organiser_profile_id`: `profile_type = 'organiser'` → `persona_type = 'organiser'`

Read-back for Ops: `SELECT pg_get_viewdef('public.v_actor_context'::regclass, true);` and
`SELECT column_name, ordinal_position FROM information_schema.columns WHERE table_schema='public' AND table_name='v_actor_context' ORDER BY 2;`
Expected: the three columns in the order above. (CREATE OR REPLACE keeps the owner, grants and view comment.)

## 4. Role-persona proofs, no write to live data (C7)

Everything runs inside one transaction that ends in ROLLBACK. Use the KAN-646 fixture helpers (`mk_user`, `mk_legacy`)
from `supabase/tests/kan646_personas_s3/probes.sql`, or insert directly as below.

```sql
BEGIN;
-- fixtures: one active organiser persona, one player persona, one inactive organiser persona
-- (profile_type per profiles_profile_type_check: organiser -> 'business', player -> 'personal')
-- :uO :uP :uI are three existing or freshly created auth users; :sport is any sports.id
INSERT INTO public.profiles(user_id, profile_type, username, display_name, persona_type, primary_sport, onboard, is_active)
VALUES (:'uO','business','p674_org','P org','organiser',:'sport',true,true),
       (:'uP','personal','p674_pl','P player','player',:'sport',true,true),
       (:'uI','business','p674_ina','P inactive','organiser',:'sport',true,false);

SELECT p.username,
       public.actor_is_organiser(p.id) AS is_organiser,
       public.actor_capabilities(p.persona_type) AS caps
FROM public.profiles p WHERE p.username IN ('p674_org','p674_pl','p674_ina');

-- per-profile capability flags (v_access_matrix columns can_create_*), as the owning user
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', json_build_object('sub', :'uO', 'role','authenticated')::text, true);
SELECT can_create_meetup, can_create_challenge, can_create_game_hosted, can_create_game_casual
FROM public.v_access_matrix;                      -- organiser: true, true, true, true
SELECT organiser_profile_id IS NOT NULL AS has_org, player_profile_id IS NULL AS no_player
FROM public.v_actor_context;                      -- true, true

SELECT set_config('request.jwt.claims', json_build_object('sub', :'uP', 'role','authenticated')::text, true);
SELECT can_create_meetup, can_create_challenge, can_create_game_hosted, can_create_game_casual
FROM public.v_access_matrix;                      -- player: false, false, false, true

-- organiser_required raised for the player
DO $$ BEGIN
  PERFORM public.rpc_challenge_create('organiser','x','public',NULL);
  RAISE EXCEPTION 'organiser_required_not_raised';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK: %', SQLERRM; END $$;   -- expect organiser_required
ROLLBACK;
```

Expected: organiser → `actor_is_organiser` true, `create_meetup`, `create_challenge`, `create_hosted` all true;
player → all three false and `create_casual` true; inactive organiser → false; the player's `rpc_meetup_create` /
`rpc_challenge_create` raise `organiser_required`; the organiser's succeed. (Column names of `v_access_matrix` follow
baseline :25032-25050; adjust the select list if a name differs.)

## 5. KAN-646 probe expectations that change (C8)

`supabase/tests/kan646_personas_s3/probes.sql` is outside this ticket's allowed paths (only `docs/personas/` probe notes
are), so it was left byte-identical and the updated expectations are recorded here for whoever applies them.

| Probe | Old expected | New expected | Why |
|---|---|---|---|
| L6 (:293) | `NOT actor_is_organiser(lO) AND NOT actor_is_player(lO)`, "unchanged (false, F1)" | `actor_is_organiser(lO) AND NOT actor_is_player(lO)` | `lO` is `mk_legacy(.., 'organiser', ..)`: `persona_type = 'organiser'`, active. F1 is fixed, so it is now an organiser. |
| L7 (:294) | `ERR:organiser_required` from `rpc_challenge_create('organiser','x','public',NULL)` | the call succeeds (no `organiser_required`) | same profile, now an organiser. Add a player-profile variant that keeps `ERR:organiser_required`. |
| R2 (:309-313) | `actor_is_organiser` ACL = `{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` | unchanged | this migration does not touch grants (section 2). |
| R5 (:318-325) | `actor_is_organiser` is not `prosecdef` | unchanged | still SECURITY INVOKER. |
| T1–T6 (:138-143) | contributor + organiser row is an organiser | unchanged | the contributor branch is kept (section 0). |

Until L6 and L7 are updated, re-running the old probe file will show those two failing; that is the intended delta.

## 6. Decision needed (one)

May `actor_is_organiser` be revoked from `anon` (and PUBLIC) as the CTO asked, given that `v_access_matrix` is
`security_invoker`, granted to `anon`, and reaches the function through `can_create_game`? Revoking turns its empty
result for anon into `permission denied`. Existing grants were kept. Alternatives: (a) keep as is, (b) revoke and also
revoke anon SELECT on `v_access_matrix`, or (c) revoke and accept the permission error for direct anon REST calls.
