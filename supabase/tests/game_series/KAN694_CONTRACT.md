# KAN-694 (B3): edit this vs all future, and cancel a series

Status: AUTHORED, NOT APPLIED, probes NOT EXECUTED (the authoring seat may not write to the database). Memphis applies.

## Order of application
1. `20261027120000_kan671_game_series.sql` (KAN-671; only on branch `alpha-671-habu`, cherry-pick with no edits).
2. `20261030120000_kan693_rpc_create_game_series.sql` (KAN-693).
3. `20261030130000_kan694_rpc_series_edit_cancel.sql` (this ticket; pre-check raises if KAN-671/693 are missing).
4. `20261030140000_kan694_fix_same_day_topup.sql` (fix cycle; pre-check raises if step 3 is not applied).
5. `probes_kan694.sql` (ends in ROLLBACK).
Rollback: `rollback_kan694.sql` drops only the three step-3 functions (edited or cancelled data is not reverted). Step 4 is a **forward-only replace** of `fn_generate_game_series_occurrences`: `rollback_kan694.sql` does not undo it, and dropping the function would break `rpc_create_game_series`. To restore the previous body, re-run the CREATE OR REPLACE from step 2.

## Top-up rule (fix cycle, CTO ruling dreq-216a029a)
`fn_generate_game_series_occurrences` never creates an occurrence on a local calendar date (in the series timezone) that already holds a non-cancelled row of the same series, whatever its time. That date counts once toward the rolling window of 4 (null `ends_on`) and once toward the cap of 52. Nothing is created past `ends_on`. Rows with joined players are never touched. The exact `start_at` check stays for cancelled rows (unique index). Probes F8 and F9 cover it; F6 and F7 are unchanged. `rpc_edit_game_series_future` is unchanged: its `topup_skipped` guard is now redundant but still reported.

## Contract (all SECURITY DEFINER, `search_path = public, pg_temp`, EXECUTE revoked from PUBLIC and anon, granted to authenticated and service_role)
Host = `effective_actor_uid()` against `game_series.creator_user_id` / `games.creator_user_id`. A non-host and an unknown id both raise `not_host_or_not_found`; no session raises `not_authenticated`.

- `rpc_edit_game_series_occurrence(p_game_id, p_title, p_start_at, p_end_at, p_capacity, p_venue_space_id) -> jsonb {game_id, series_id}`
  Edits ONE future, non-cancelled occurrence. NULL = unchanged. `series_id` is never written (T-099). Errors: `occurrence_not_editable`, `occurrence_time_invalid`, `occurrence_capacity_invalid` (2..64 and not below active players), `occurrence_time_taken` (same start as another occurrence of the series).
- `rpc_edit_game_series_future(p_series_id, p_title, p_capacity, p_start_time_local, p_duration_minutes, p_venue_space_id, p_ends_on, p_clear_ends_on) -> jsonb`
  Updates the `game_series` template, then for future non-cancelled occurrences:
  - no joined players: updated IN PLACE to the template (no delete, so no games row is ever removed); if now past `ends_on`, cancelled via `rpc_cancel_game` (nobody to notify);
  - joined players: never rewritten; their ids come back in `kept_with_players` so the client can tell the organiser.
  Result: `{series_id, updated, cancelled_after_end_date, created, topup_skipped, kept_with_players[]}`. `p_clear_ends_on = true` makes the series run until ended. Errors: `series_not_active`, `series_capacity_invalid`, `series_schedule_invalid`.
- `rpc_cancel_game_series(p_series_id, p_reason) -> jsonb {series_id, status:'ended', cancelled, player_notifications, past_kept}`
  Sets status `ended` first (the generator then skips it), then cancels each future non-cancelled occurrence through the existing `rpc_cancel_game`; the existing `trg_game_updated_notify` trigger notifies every roster member other than the host. Past occurrences and history are untouched; nobody is carried over. Calling it again on an ended series is safe.

## Definitions and limits
- "Joined player" = a `game_roster` row for the game whose `user_id` is not the game's creator (exactly the set `trg_game_updated_notify` notifies). Waitlist-only users are not counted.
- When the time of day or duration changes AND a joined occurrence kept its old time, the generator top-up is skipped (`topup_skipped: true`): the generator matches existing rows by exact `start_at` and would otherwise add a second game on that day. The next scheduled generator run tops up.
- `notification` evidence: probes assert the `is_cancelled` flip that fires the trigger and the player count returned; they do not read the notifications table (not touched by this ticket).
- Paid games remain blocked in a series (KAN-693); nothing here handles price.
