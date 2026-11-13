# KAN-693 (B2): rpc_create_game_series and the N-ahead generator

Status: AUTHORED, NOT APPLIED, probes NOT EXECUTED (the authoring seat may not write to the database). Memphis applies.

## Order of application
1. `20261027120000_kan671_game_series.sql` (KAN-671, B1; exists only on branch `alpha-671-habu`).
2. `20261030120000_kan693_rpc_create_game_series.sql` (this ticket). It has a pre-check that raises if `game_series` or
   `games.series_id` is missing, so applying it first fails safely.
3. Run `probes_kan693.sql` (ends in ROLLBACK). Rollback: `rollback_kan693.sql` (reverses only this migration).

## Live finding for KAN-671 (read-only, 2026-10-30, project wtncuzcskpigqpmnxwws)
KAN-671 is NOT applied. Query used:

```sql
select to_regclass('public.game_series') as game_series,
       (select count(*) from information_schema.columns where table_schema='public' and table_name='games' and column_name='series_id') as games_series_id_cols,
       (select count(*) from pg_policies where schemaname='public' and tablename in ('games','game_series')) as policies,
       (select count(*) from supabase_migrations.schema_migrations where version='20261027120000') as kan671_migration_rows
```
Result: `game_series = null`, `games_series_id_cols = 0`, `policies = 0`, `kan671_migration_rows = 0`.

## Contract
- `rpc_create_game_series(p_actor_type, p_sport_id, p_sport_variant_id, p_geo_location_id, p_area_id, p_starts_on, p_start_time_local, p_duration_minutes, p_timezone, p_frequency, p_capacity, p_title, p_venue_space_id, p_ends_on, p_listing_visibility, p_join_policy, p_occurrences_ahead, p_price_aed) -> uuid` (series id).
  `p_frequency` is `weekly` or `biweekly`. Host is `effective_actor_uid()` plus `choose_actor(p_actor_type)`; no caller-supplied identity. A non-zero price raises `series_paid_not_supported`.
  SECURITY DEFINER, `search_path = public, pg_temp`, EXECUTE revoked from PUBLIC and anon, granted to authenticated and service_role.
- `fn_generate_game_series_occurrences(p_series_id uuid default null) -> integer` (games created). Keeps `occurrences_ahead` future non-cancelled games per active series. service_role only. Idempotent: skips an existing (series_id, start_at), backed by the unique index `games_series_id_start_at_key`.
- Each occurrence is created through the existing `rpc_create_game` (26-arg), so validation and the kan440 persona gate apply; `games.series_id` is set afterwards. The generator sets the transaction-local `request.jwt.claim.sub` to the series creator for that call and restores it.
- Limits: 52 occurrence slots per series (hard cap, slots counted from `starts_on`); `ends_on` stops generation; null `ends_on` runs until the series is ended.
- Additive change: `game_series.sport_variant_id uuid` (nullable; `rpc_create_game` requires a variant and KAN-671 does not store one).

## Not in scope / open
- Cancelling a series and notifying players (v1 decision 3) and renewing after the cap are later tickets.
- Scheduling the generator (cron) is for Memphis; call `select public.fn_generate_game_series_occurrences();` as service_role.
- BYDAY is not generated: an occurrence falls on the weekday of `starts_on`.
