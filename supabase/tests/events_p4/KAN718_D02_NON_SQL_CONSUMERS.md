# KAN-718 D02: dynamic SQL, functions, scripts, Worker and admin consumers of the slated columns

Ticket KAN-770 (Epic KAN-708, Events P4). It diffs against the KAN-734 (B15) coverage matrix
(`supabase/tests/events_p2/kan714_b15_coverage_probe.sql`, `KAN714_READ_MANIFEST.md`).
The catalogue probe is `kan718_d02_dynamic_and_functions_scan.sql` in this folder.

**Status: scan only.** Nothing was changed, dropped or applied, and production was not read. The probe ran on a
disposable local cluster (`build_kan731.sh`).

## VERDICT: DELETION BLOCKED

Supported consumers still read the slated `games`/`meetups` columns, at every layer this ticket scans:
- **Functions:** 28 functions are open or trigger-class. Another 5 are B15-converted but still name a legacy table next to a slated column.
- **Triggers:** 21 non-infra triggers on `games`/`meetups` read slated `NEW.`/`OLD.` columns. They would fail at runtime after a drop.
- **Policies:** 4 RLS policies hold a column-level dependency on `meetups.creator_user_id`/`listing_visibility`.
  - `meetups_select_visible`
  - `meetup_attendees_select`
  - `meetup_attendees_select_visible`
  - `meetup_attendees_write`
- **Dynamic SQL:** 1 non-infra dynamic-SQL function, `admin_cleanup_user_data`.
- **Infra dependencies (pending):** the KAN-711/712/713/718 infra, 8 functions plus their triggers, reads every slated column. It is a
  **pending dependency**, not a retired one: it is retired together with the columns, in the same step, and not before.

The client side is blocked separately by KAN-771 (D03, `KAN718_D03_OLD_CLIENT_MATRIX.md`).

The slated set is the 22 `games` / 20 `meetups` columns defined in D03 §1. It comes from `kan711_events_map_*`, minus `id`.

## 1. Non-SQL consumers

| Surface | What was scanned | Reads a slated column? | Evidence |
|---|---|---|---|
| Edge Functions | every `supabase/functions/*/index.ts` (and shared modules) | **no** | No function selects from `games` or `meetups`. Details below the table |
| Messaging Worker | `workers/messaging/src/**` | **no direct read** | RPC calls only. Details below the table |
| Worker D1 migrations | `workers/messaging/migrations/0001-0005` | no | Cloudflare D1 (SQLite) schema, not Postgres; no `games`/`meetups` |
| `scripts/` | every file | no | Details below the table |
| Admin tooling | repo-wide | no client code here | Details below the table |
| pg_cron | catalogue (A6) | not present locally | `cron` schema absent in the harness. Hosted cron jobs are **not documented** here (production not read) |

**Edge Functions.**
- `send-push-notification` reads `game_roster(game_id, user_id, status)` and `meetup_attendees(meetup_id, user_id)`. None of those is a slated column.
- `broadcast-notification` calls `is_admin` and `rpc_broadcast_inapp_notification`.
- `detect-country` and `send-export-email` touch `audit_events` only.

**Messaging Worker.** It makes RPC calls only:
- `msg_authorize` and `msg_my_conversations`: converted by B11.
- `msg_game_conversation`: pinned `unchanged` by B11.
- `msg_set_muted`, `msg_dm_exists`, `msg_start_dm`, `msg_report_message`, `msg_notify`, `msg_ack_receipt`, `msg_typing`, `is_admin`, `admin_actor`.
- It also reads the view `v_mod_queue_open`.

The Worker inherits whatever those RPCs read. That is the SQL scan's question, not a direct dependency.

**`scripts/`.**
- `check_app_association.py` lists deep-link paths only.
- `scripts/ci/check_anon_allowlist_test.sh` names views (`v_game_card`, `v_meetup_list`, `v_my_games`, `v_rateable_after_game`), never columns.
- `check_anon_function_grants_test.sh` tests a `p_game_id` parameter name.

**Admin tooling.**
- There is no admin app directory in this repo. The admin surface is SQL: `rpc_admin_launch_funnel` (KAN-700), and `admin_overview_row` and `admin_cleanup_user_data` (B13).
- The admin dashboard repository is **not documented** here and was not scanned.

## 2. Dynamic SQL, repo-wide

The local catalogue is a harness subset, about 100 of B15's 161 functions. So the dynamic-SQL question was also answered over
the whole migration history:
- The scan takes the latest `CREATE [OR REPLACE] FUNCTION|PROCEDURE` per name across `supabase/migrations/`, with comment lines stripped.
- It found **794 latest definitions; 10 contain `EXECUTE <string>`.**

| Function (latest file) | Can reach games/meetups? | Slated tokens | Class / disposition |
|---|---|---|---|
| `_you_invited`, `_you_joined` (baseline) | no | none | `game_invites`/`game_roster` only |
| `admin_cleanup_user_data` (B13 `20261104101300`) | **yes** | `creator_profile_id` (static part) | **B15 converted, still names a legacy table**. The dynamic part loops `information_schema.columns` for `user_id`/`profile_id` and excludes `games`; the static part deletes by `creator_profile_id`. **Blocks** |
| `admin_force_delete_auth_user` (baseline) | no | none | `auth` schema only |
| `kan711_events_backfill_batch` (KAN-711) | **yes** | all, via the mapping functions | **infra, pending dependency**. It must be retired with the columns. A re-run after a drop fails |
| `kan712_wrap_rpc`, `kan712_unwrap_rpc` (KAN-712) | wrapper only | none | infra: renames and re-points RPCs, reads no row |
| `posts_mapping_check` (baseline) | no | none | `posts` only |
| `rpc_meetup_create`, 2 overloads (baseline) | yes (inserts `title`, `start_at`…) | `start_at`, `title` | **retired with evidence:** both overloads are dropped in `20260915120000_meetups_hardening.sql:95-96` and never re-created. It is not judged by its name |
| `vibes_base_candidates` (baseline) | no | none | `profiles` only |

No legacy RPC was classified as retired on its name. The `_legacy_v1`/`_v2` functions (`rpc_create_game_legacy_v1/v2`,
`rpc_create_meetup_legacy_v1/v2`, `rpc_update_game_legacy_v1_kan712_inner`) are present and still write slated columns. A2
lists them as **open**.

## 3. Diff against the B15 coverage matrix

The B15 dynamic set was `admin_cleanup_user_data`, `kan711_events_backfill_batch` and `kan712_wrap_rpc`.

The repo scan adds 7 functions:
- 6 cannot reach a legacy table.
- `rpc_meetup_create` is dropped, with file:line evidence.

**There is no new dynamic consumer.**

The catalogue disagrees with "converted" for two kinds of B15 entry (A2/A7):
- **Converted, but the body still names `games`/`meetups` with a slated token and does not read `events`** (`converted-without-events`):
  - `active_stream`, `admin_cleanup_user_data`, `game_slots_left`, `rpc_booking_hold_for_meetup`
  - `rpc_get_activity_feed`, `rpc_meetup_card`, `trg_meetup_rsvps_notify`

  These are B15 "converted" entries as built in this chain. They are a dependency to re-check before deletion, not retired.
- **Converted and reading `events`, but still naming a legacy table with a slated token** (`converted`):
  - `_can_view_game`, `_can_view_game_for_join`, `_is_game_host`
  - `can_current_user_join_game`, `can_current_user_rsvp_meetup`

  These are textual hits. Each may be a fallback join or a comment-free reference, and it needs a per-function check before the drop.

Several B15 entries (`msg_*`, `v_*`, `rpc_rate_*` and others) are **absent from this harness**, so this catalogue could not judge them.
Section 2 covers them only for dynamic SQL. Their static reads stay B15's evidence.

## 4. Local run (C2)

Command, from the repo root, against the disposable cluster built by `supabase/tests/events_p2/build_kan731.sh <dir> 54770`:

```
psql -X -h /tmp -p 54770 -U postgres -d k731 -v ON_ERROR_STOP=1 -P pager=off \
     -f supabase/tests/events_p4/kan718_d02_dynamic_and_functions_scan.sql      # exit=0
```

Output, abridged. A2 and A4 are summarised, and the full rows are reproducible with the command.

```
== A0 slated columns present:  games 22 | meetups 20 | missing: none
== A1 column-level pg_depend on slated columns: 46 constraint, 14 default, 3 index, 12 trigger, 4 policy
   policy meetup_attendees_select / _select_visible / _write on meetup_attendees -> meetups creator_user_id,listing_visibility
   policy meetups_select_visible on meetups -> creator_user_id,listing_visibility
== A1b views reading slated columns: (0 rows)
== A2 class counts: converted 5 | converted-without-events 7 | infra 8 | open 18 | trigger 3   (41 functions)
   open: rpc_create_game, rpc_create_game_legacy_v1/v2, rpc_create_meetup, rpc_create_meetup_legacy_v1/v2,
         rpc_challenge_spawn_game, fn_generate_game_series_occurrences_kan712_inner, and the 10 *_kan712_inner write RPCs
   trigger: fn_games_activity_sync, fn_meetups_activity_sync, fn_meetups_enforce_solo_sport
== A3 dynamic SQL in catalogue:
   admin_cleanup_user_data          names_legacy=t  %I=t  catalogue-driven=t  converted-without-events
   kan711_events_backfill_batch     names_legacy=t  %I=t  catalogue-driven=f  infra
   kan712_unwrap_rpc                names_legacy=f  %I=t                      no-slated-token
   kan712_wrap_rpc                  names_legacy=t  %I=t                      no-slated-token
== A4 triggers on games/meetups: 41 (infra 17, consumer 24; 21 consumers read slated NEW./OLD. columns)
== A5 policies on other tables naming games/meetups: meetup_attendees_select, _select_visible, _write
== A6 cron schema absent: no jobs to scan here
== A8 views_on_slated 0 | functions_open 28 | converted_still_naming_legacy 5 | dynamic_non_infra 1
      | triggers_reading_slated 21 | infra_retired_with_columns 8 | verdict DELETION BLOCKED
NOTICE:  KAN-770 B1 PASS: 1 game + 1 meetup seeded; one events parent each, id kept, no duplicate events ids
NOTICE:  KAN-770 B2 PASS: games 11 = game events, meetups 12 = meetup events, events 23 = sum
NOTICE:  KAN-770 B3 PASS: legacy reads return what was written; events parent equal; meetup NULL end_at/capacity preserved
NOTICE:  KAN-770 B4: events refused to API roles (42501), as designed
NOTICE:  KAN-770 B4 PASS: stranger and blocked see 0 new games/events; stranger sees the public meetup (legacy), blocked sees 0; _can_view_game(blocked) = false
NOTICE:  KAN-770 B5 PASS: md5 of games 376339d5, meetups 073fc892, events 9d8ad265 and the column shape identical after ROLLBACK
NOTICE:  KAN-770 SCENARIO PASS
```

## 5. Conditions to lift the block (not done here)

1. Convert or retire every A2 `open`/`trigger` function and the 21 A4 consumer triggers. Re-point them to `events`, or drop them with
   evidence that no caller remains.
2. Re-check the 12 B15 entries in §3 that still name a legacy table with a slated token.
3. Rewrite the 4 policies on `events` visibility before the columns go.
4. Retire the infra in the same migration as the drop, and never earlier:
   - the KAN-711 mirror and backfill
   - the KAN-712 compat mirror and guard
   - the KAN-713 location and joining triggers
   - the KAN-718 series guard
5. Lift the client block (D03).
6. Re-run this probe on the full catalogue. A8 must report 0 in every non-infra column before the verdict line may change.

## 6. Handoff

- **Changed files:**
  - `supabase/tests/events_p4/kan718_d02_dynamic_and_functions_scan.sql` (new)
  - this file (new)
- **Migrations:** none. **Applied:** nothing.
- **Rollback:** delete the two files. The probe's Part A is READ ONLY, and Part B runs inside `BEGIN … ROLLBACK` with an md5 proof,
  so no data is touched.
- **Limitations:**
  - The function scan is textual over `prosrc` with comments stripped, so it is conservative and over-reports. A2 hits are candidates; A1 is exact.
  - The local catalogue is a harness subset. Functions absent here are covered only by §2 (dynamic SQL) and by B15.
  - The live catalogue, hosted pg_cron, Supabase webhooks/realtime config and the admin dashboard repo were not read.
