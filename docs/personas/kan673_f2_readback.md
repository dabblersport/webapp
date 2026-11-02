# KAN-673 — F2 read-back and probe notes

Migration: `supabase/migrations/20261027100000_kan673_rpc_create_sport_profile_owner_check.sql`.
Applied by Ops (Memphis). The team ran none of this SQL: there is no database access on this branch.
Each block below is run by Ops after applying, and its output is pasted on KAN-673.

## 1. Privilege read-back (C3)

```sql
SELECT p.oid::regprocedure AS fn,
       has_function_privilege('anon', p.oid, 'EXECUTE')          AS anon,
       EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee = 0) AS public_grant,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  AS service_role
FROM pg_proc p
WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'rpc_create_sport_profile';
```

Expected, one row per overload (there is one): `anon=false, public_grant=false, authenticated=true, service_role=true`.
The migration also asserts this itself and aborts if it is not so.

## 2. Definition read-back (C4)

```sql
SELECT pg_get_functiondef('public.rpc_create_sport_profile(uuid,uuid,text,integer)'::regprocedure);
SELECT prosecdef, prorettype::regtype, proconfig
FROM pg_proc WHERE oid = 'public.rpc_create_sport_profile(uuid,uuid,text,integer)'::regprocedure;
```

Expected: `user_id = auth.uid()` in the player check, `SECURITY DEFINER`, `search_path=public, pg_temp`,
`RETURNS void`, signature `(p_profile_id uuid, p_sport_id uuid, p_sport_key text, p_skill_level integer DEFAULT 1)`.

## 3. Denial proof, no write to the live data (C8)

Nothing is committed: the transaction ends in ROLLBACK, and the call raises before any INSERT.
Pick any player profile `:owner_profile` owned by user `:owner_uid`, and any other user id `:other_uid`.

```sql
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', json_build_object('sub', :'other_uid', 'role', 'authenticated')::text, true);
DO $$
BEGIN
  PERFORM public.rpc_create_sport_profile(:'owner_profile'::uuid, gen_random_uuid(), 'football', 1);
  RAISE EXCEPTION 'denial_not_raised';
EXCEPTION WHEN SQLSTATE '42501' THEN
  RAISE NOTICE 'OK 42501: %', SQLERRM;
END $$;
ROLLBACK;
```

Expected notice: `OK 42501: sport_profile requires owned player profile`.
The same call as `anon` must fail with `permission denied for function rpc_create_sport_profile` (SQLSTATE 42501).

## 4. KAN-646 probes (C7)

Re-run `supabase/tests/kan646_personas_s3/probes.sql` (G and J sets against the real
`rpc_onboard_unified_profile`) in its usual rollback harness. L6 and L7 are not affected: `actor_is_organiser`
and the policy at baseline `:25102` are not touched by this migration.

**Known expected delta (needs a decision).** Probes S5, S6 and S7 match the old message
`sport_profile requires persona_type=player`. The CTO ruling sets one new message, so those three
now see `sport_profile requires owned player profile` and their substring match in `pg_temp.expect` fails until the
three expected strings in `supabase/tests/kan646_personas_s3/probes.sql` are updated. That file is outside this
ticket's allowed paths, so it was left byte-identical.

## 5. Behaviour kept and changed

- Legacy player branch: now needs `profiles.user_id = auth.uid()`.
- Owned-contributor branch added by KAN-646 (uses `effective_actor_uid()`): carried over unchanged, so S1 still passes.
- Failure: one exception for not-yours and not-a-player, ERRCODE 42501.
- No DROP, no new overload, no change to `actor_is_organiser` or any policy.
- The repository holds no separate SQL registry file; the migration file is the registry entry Memphis releases.
