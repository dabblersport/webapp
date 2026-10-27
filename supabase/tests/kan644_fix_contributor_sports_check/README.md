# KAN-644 fix (P0): `trgfn_contributor_sports_check` probes

Migration: `supabase/migrations/20261027120000_kan644_fix_contributor_sports_check_branches.sql`
cto decision: `dreq-0ca2aa6e`.

## The change

The function is shared by `trg_contributor_sports_profiles` (on `profiles`) and `trg_contributor_sports_sp`
(on `sport_profiles`). Its earlier version resolved `v_pid` with one DECLARE-time CASE that referenced
`NEW.id`, `OLD.profile_id` and `NEW.profile_id` together. That failed with `record "new" has no field ...`
on the other table. The fix assigns `v_pid` in an `IF / ELSIF / ELSE` in the body, so each field is read
only in its own table's branch. Nothing else changes: the rule, the exception text, the attributes, the
ACL and the triggers stay as they were.

## How to run

The function must already be replaced on the target database. Run as `postgres`, as one script:

```
psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/kan644_fix_contributor_sports_check/probes.sql
```

The script is a single `BEGIN ... ROLLBACK`, so nothing persists. Each case sets both constraint triggers
`IMMEDIATE` inside its own sub-block. The deferred trigger then fires at the end of each statement inside
the transaction, and a failing case's writes and queued trigger events are discarded with its sub-block.
You need at least 2 active sports and at least 5 `auth.users` with no profile. The script raises a
`kan644fix_probe_*` precondition error if either is missing.

## Expected results (all `ok = true`; the final DO raises if any is false)

| Probe | Expects |
|---|---|
| Z1 | `md5(pg_get_functiondef)` is no longer `c9cb15016b1aecbda961d2c952306b98` (the defective body) |
| Z2 | `prosrc` contains `IF TG_TABLE_NAME = 'profiles' THEN` and no `CASE WHEN TG_TABLE_NAME` |
| Z3 | `proacl` = `{postgres=X/postgres,service_role=X/postgres}` |
| Z4 | `anon` and `authenticated` cannot EXECUTE |
| Z5 | `plpgsql`, not SECURITY DEFINER, `proconfig = {search_path=public, pg_temp}` |
| Z6 | both triggers still bound to the function, DEFERRABLE INITIALLY DEFERRED |
| A1 | legacy player: profiles INSERT + UPDATE do not raise (`NEW.id` branch) |
| B1–B3 | legacy player: sport_profiles INSERT, UPDATE, DELETE do not raise (`NEW.profile_id` / `OLD.profile_id` branches). `B0` appears only on failure and carries SQLERRM |
| C1 | partner: profiles INSERT, onboard UPDATE and UPDATE do not raise |
| D1 | onboarded contributor whose `interests` drops `primary_sport` raises `contributor_sports_incomplete` |
| E1–E2 | complete contributor (onboard, primary_sport in interests, matching sport_profiles row, every sport_profile sport in interests) passes creation, then a profiles UPDATE and a sport_profiles INSERT/UPDATE/DELETE. `E0` appears only on failure |

**Pre-fix red check.** On a database still carrying the defective body (a branch or local copy, never
live), A1, B0, C1 and E0 are expected to fail with `record "new" has no field ...`, and D1 to fail because
SQLERRM is the field error and not `contributor_sports_incomplete`. Z1/Z2 fail by construction. That is
how these probes are shown to fail before they count as passing.

## Post-apply read-back (read-only)

```sql
SELECT md5(pg_get_functiondef('public.trgfn_contributor_sports_check()'::regprocedure)) AS def_md5,
       p.proacl::text, p.prosecdef, p.proconfig::text, l.lanname
  FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
 WHERE p.oid = 'public.trgfn_contributor_sports_check()'::regprocedure;
-- expect: def_md5 <> c9cb15016b1aecbda961d2c952306b98 (record the new value),
--         proacl = {postgres=X/postgres,service_role=X/postgres}, prosecdef = f,
--         proconfig = {"search_path=public, pg_temp"}, lanname = plpgsql

SELECT tgname, tgrelid::regclass, tgdeferrable, tginitdeferred
  FROM pg_trigger WHERE tgfoid = 'public.trgfn_contributor_sports_check()'::regprocedure ORDER BY tgname;
-- expect: trg_contributor_sports_profiles on profiles, trg_contributor_sports_sp on sport_profiles, both t/t
```
