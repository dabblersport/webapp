# KAN-671: game_series and games.series_id (T-099)

AUTHORED, NOT APPLIED. Operations applies `supabase/migrations/20261027120000_kan671_game_series.sql`, then runs
`probes.sql` (one BEGIN..ROLLBACK). Revert with `rollback.sql`.

## Read-path finding: how `games` is actually read

- `public.games` has RLS **enabled** and **no policy**: `20260829080500_baseline_schema.sql:32378` is the only RLS statement
  on it, and no `CREATE POLICY ... ON public.games` exists in any migration. Direct `from('games')` selects by a signed-in
  caller therefore return no rows.
- Reads go through objects owned by `postgres` that bypass row policies: SECURITY DEFINER RPCs (for example
  `rpc_get_nearby_games`, and the active-stream function in `20261020120000_kan595_active_stream.sql:40`, which says so in
  its own header) and `public.v_my_games` (a plain, non-`security_invoker` view whose own `WHERE` limits rows to the caller's
  created or rostered games, baseline `:25861`).
- Not verified against the live database: this team's session may not run `execute_sql` (ops guard, even read-only), so
  `pg_policies` was not re-read live. The T-099 ruling records 0 policies on the 2026-10-27 live read, which matches the repo.
  Probe P7 re-checks it after apply.

## Consequence for the policies

`game_series` does not copy the no-policy state. It has its own owner-only policy, so it does not depend on the games path:
`game_series_select_owner FOR SELECT TO authenticated USING (creator_user_id = (SELECT auth.uid()))`. No insert, update or
delete policy and no write grant: series are written by SECURITY DEFINER RPCs in the follow-up stories. `anon` and `PUBLIC`
hold nothing. Public discovery of recurring games is unaffected because each occurrence is an ordinary `games` row read through
the existing RPCs.

## Does adding `series_id` open any games row?

No. A column carries no row filter. `games` still has no policy, so the set of rows any caller can read directly is unchanged
(none). The definer RPCs and `v_my_games` keep their own filters; `v_my_games` lists explicit columns, so it does not expose
`series_id`. Column privileges on `series_id` are inherited from the table grant, and probe P8 shows they equal those of an
existing column. A definer function that returns a whole `games` row would now carry `series_id` for rows it already returned.
That is a new column value, not a new row. Probes P7 to P10 cover this.

## Notes

- Host is `creator_user_id` / `creator_profile_id`, the names `games` uses (T-099 says "host user id").
- `rrule` is checked as `FREQ=WEEKLY` with optional `INTERVAL=1|2` and `BYDAY`; the scheduled job that keeps N occurrences
  ahead is a later story.
- `games.series_id` FK is `ON DELETE SET NULL`; `game_series` has no authenticated DELETE.
