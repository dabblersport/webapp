# KAN-734 (KAN-714 B15) — read-coverage manifest for the events-parent conversion

**Status:** coverage audit only. This ticket adds no migration and changes no function.
**Executable companion:** `supabase/tests/events_p2/kan714_b15_coverage_probe.sql`. It re-derives this matrix from a local
catalogue and fails if the catalogue and this file disagree. It must be run on local databases only.
**Tree audited:** the tracked `supabase/migrations/*.sql` in this commit. The untracked
`20261105100000_*` and `20261105110000_*` files are excluded (see §6).
**Refreshed by KAN-789 (after KAN-785).** KAN-785 (`20261104110400_kan785_retire_rpc_meetup_my.sql`) dropped
`public.rpc_meetup_my()`. It is no longer a candidate, so every total below is recomputed without it (161 → 160
candidates, 95 → 94 unchanged, 7 → 6 pinned, 100 → 99 present locally, 26 → 25 residual). Its matrix row (Unchanged
#73) is kept, marked RETIRED and not counted, so the history is not silently lost.

## 1. Totals

| Category | Total | Converted | Unchanged (with reason) | Open |
|---|---|---|---|---|
| Candidate functions (identity = name + argument types) | **160** | **32** (27 by a B migration, 5 by KAN-713) | **94** | **34** |
| Views reading `games`/`meetups` | **8** | **6** | **2** | **0** |
| Inbound FKs to `games`/`meetups` | **21** | 0 | **21** | **0** |

**What "converted" means here.** It means the latest definition reads the shared facts from `public.events`. It does
**not** mean the function is ready for a DROP COLUMN. KAN-713's rule is *intersection, never widen*, so most
converted readers keep the legacy visibility predicate alongside the `events` check. §4 lists every one of these
residual references.

### Unchanged, by sub-reason (94)

| Code | n | Meaning |
|---|---|---|
| `name-only` | 40 | The name matches game/meetup, but the body and signature never reference `public.games`/`public.meetups`. For a trigger function, the only column use is NEW/OLD on the table it is attached to. |
| `infra` | 25 | Events-programme infrastructure from KAN-710/711/712/713/718: mirror, backfill, write contract, guards, and the new KAN-713 helpers. Where it reads legacy, it does so by design. |
| `trigger` | 9 | A trigger on a legacy row that reads no other games/meetups row by alias. It is write side. |
| `pinned` | 6 | Pinned unchanged, with a reason, by the named B header (B09, B11, B14). B06's pin, `rpc_meetup_my`, was RETIRED by KAN-785 and is no longer counted. |
| `legacy` | 6 | A renamed superseded overload (`*_legacy_vN`, `*_v1`). |
| `write` | 5 | A KAN-712-wrapped write RPC. Shared-field writes are routed through `events` by the KAN-712 guard, so this is not a read conversion. |
| `noshared` | 2 | References `games`/`meetups` only for id/subtype; no shared-column token appears in the body. |
| `fp` | 1 | `process_notification_event`: `games` appears only inside the deep-link string `'/sports/games/'`. |

### Open, by sub-reason (34)

| Code | n | |
|---|---|---|
| `open-read` | 14 | A reader that still references legacy shared columns, with no B migration that converts it. |
| `open-write` | 15 | A write/mutation RPC whose auth gate or validation reads legacy shared columns, and which is not KAN-712-wrapped. |
| `open-trigger` | 5 | A trigger function that reads another `games` row's shared columns by alias. |

## 2. Reconciliation with the 2026-11-01 production audit (141 functions, 7 views, 20 FKs)

**The audit artefact is not in this repository.** A search for `141` under `supabase/` found nothing relevant. The
audited figures are taken from the KAN-734 brief, and production was not read (the brief forbids it). This means the
reconciliation compares repository text against a number, not against the audit's list.

| | Audit | Repo at audit cut (`< 20261101140000`, before KAN-710) | Repo now (tracked) | Explanation |
|---|---|---|---|---|
| Functions, by name OR body | 141 | **136** (134 names) | **160** (158 names) | **Now:** 136 plus the 25 identities the events programme added after the audit (KAN-710..718 infra, the KAN-712 `_kan712_inner` bodies folded onto their wrappers, and `kan711_events_backfill_run`, a procedure), minus `rpc_meetup_my()`, dropped by KAN-785 (161 before KAN-785). **The gap of 5 at the cut (136 vs 141) is not documented.** Likely causes: functions present in production with no migration (drift), objects outside `public`, or a different identity rule. None of these was verified. |
| Functions, by body only | — | 95 (93 names) | 108 (106 names) | `body` means the comment-stripped body names `games`/`meetups` (excluding `games(`), or the signature/header does, or a B migration is the latest definition. |
| Functions, by name only | — | 107 (105) | 119 (117) | The name contains `game` or `meetup`. |
| Views | 7 | **7** | 8 | Exact match at the cut. The 8th is `kan711_events_parity` (KAN-711 infra, added after the audit). |
| Inbound FKs | 20 | **21** | 21 | **The +1 is not documented.** All 21 come from tracked migrations. The 4 added after the baseline: `favorites_game_id_fkey`, `favorites_meetup_id_fkey` (20261008120000), `msg_conversations_game_id_fkey` (20261013150000), `msg_conversations_meetup_id_fkey` (20261017130000). Any one of them may be missing from production or may not have been counted. |

**How the 160 is derived.** It is a text scan of every tracked migration in filename order, with the latest definition
winning. The scan applies `CREATE [OR REPLACE] FUNCTION|PROCEDURE`, `DROP FUNCTION|PROCEDURE` (one overload, or every
overload when no argument list is given) and `ALTER FUNCTION … RENAME TO`. Argument lists are normalised to catalogue
spelling: names, `DEFAULT` and `OUT` arguments are dropped, and `int`→`integer`, `timestamptz`→`timestamp with time
zone`, `time`→`time without time zone` and so on. The identity is `name(argtypes)`, so overloads count separately.

## 3. Return composite types, %rowtype, table-typed code (DROP COLUMN exposure)

These were measured on the local post-B14 catalogue (probe checks C7 and C8) and cross-checked by the repo scan.

- **Functions taking or returning a table row type:**
  - `kan711_events_map_game(games) → events`
  - `kan711_events_map_meetup(meetups) → events`
  - `kan711_events_upsert(events) → void`

  All three are KAN-711 infra. Their whole-row argument means **any DROP COLUMN on games/meetups changes their input
  type**, and their bodies read the columns by name. They must be retired or re-authored before phase 4.
- **No function `RETURNS games`, `RETURNS meetups` or `SETOF games|meetups`**, in either the repo or the local
  catalogue.
- **No table column is typed `games`, `meetups` or `events`** (`pg_attribute`).
- **No view has a whole-row dependency on games/meetups** (`pg_depend`, `refobjsubid = 0`). No view outside
  `kan711_events_parity` depends on any shared column of games/meetups (C9). The six converted views therefore survive
  a DROP COLUMN of the shared columns, although `kan711_events_parity` does not.
- **`%rowtype` declarations of games/meetups** (DROP COLUMN changes the variable's shape; columns read by name break):
  - `can_current_user_join_game(uuid,text,uuid)` (KAN-713): `g public.games%rowtype`, plus `e public.events%rowtype`.
    It dual-reads `g.creator_user_id`, `is_cancelled`, `join_policy`, `listing_visibility` and `start_at`.
  - `can_current_user_rsvp_meetup(uuid,uuid)` (KAN-713): `m meetups%rowtype`, plus `e events%rowtype`.
  - `rpc_meetup_update(...)`, which means its KAN-712 inner: `m public.meetups%rowtype`. It reads `m.creator_user_id`,
    `end_at`, `is_cancelled` and `start_at`.
  - **Repo only (absent from the local harness):** `rpc_meetup_decide_request` (reads `m.creator_user_id` and
    `is_cancelled`) and `rpc_meetup_remove_attendee` (reads `m.creator_user_id`), both declaring
    `m public.meetups%rowtype`. Both are open.
  - `SELECT * INTO g FROM public.games` with a record variable: `rpc_join_game` (open). It has the same exposure.
- **RETURNS TABLE functions** that read games/meetups: `admin_cleanup_user_data`, `admin_overview_row`,
  `meetup_counts`, `rpc_games_following_joined`, `rpc_meetup_attendees`, `rpc_sport_overview`,
  `rpc_get_nearby_games(6)`, `rpc_join_game`, `msg_evaluate`, `msg_authorize`, `msg_my_conversations`,
  `msg_game_conversation`, `rpc_get_activity_feed`, `active_stream`. (`rpc_meetup_my` was on this list until KAN-785
  retired it.) Their declared column lists are explicit, so a
  DROP COLUMN does not change their result type, only bodies that read a dropped column. **C13 asserts the result
  type, security, volatility and `proconfig` of all 40 converted objects present locally, plus the column list of the
  6 converted views, are unchanged from their pre-B image.**
- **Dynamic SQL (`EXECUTE`) among candidates:** `admin_cleanup_user_data(uuid,boolean)` (B13 converted),
  `kan711_events_backfill_batch(text,integer)` and `kan712_wrap_rpc(regprocedure,text)` (infra). Their dynamic text
  cannot be dependency-tracked. The probe pins the set (C10), so a new dynamic reader fails the probe.
- **Transitive helpers:** a converted caller still calls an open helper in exactly one place (C11):
  **`rpc_rate_venue` (B08) → `_user_hosted_game` (open)**. `rpc_rate_venue` is therefore only as converted as
  `_user_hosted_game`. Other converted-to-candidate calls go to converted or pinned callees: `active_stream` /
  `rpc_games_following_joined` → `_can_view_game`; `can_current_user_join_game` → `game_slots_left`;
  `msg_authorize` → `msg_evaluate`; `rpc_rate_venue` → `_game_belongs_to_venue` (pinned);
  `rpc_edit_game_series_future` inner → `fn_generate_game_series_occurrences` (pinned); KAN-712 wrappers → inners.
- **Pre-image defect seen in passing (not fixed; out of scope):** `rpc_meetup_invite_user`, `rpc_meetup_mint_link`
  and `rpc_meetup_set_attendee` read `m.owner_user_id`, and `public.meetups` has `creator_user_id`. This is the same
  defect class B06 recorded for `rpc_meetup_my` (since RETIRED by KAN-785, migration 20261104110400). **Whether these
  raise 42703 in production is not documented.** They
  are absent from the local harness.

## 4. Residual legacy shared-column references in converted code (phase-4 DROP COLUMN blockers)

Every row below appears in the local catalogue (probe check C6, textual alias heuristic). They exist **by design**:
KAN-713 intersection predicates, B04's verbatim intersection predicate, B05's `meetups.search_tsv` MATCH, B08's
pre-image fallback branch in `game_slots_left`, and the KAN-712 write path. They are listed because a phase-4
`DROP COLUMN` breaks each one. The table is at the end of §5.

**Not covered by C6:** the 9 `trigger` and 40 `name-only` trigger functions that use `NEW.<shared column>` on
games/meetups. These are write side, and a DROP COLUMN also breaks them. The heuristic only sees `alias.column` where
the alias binds games/meetups.

## 5. Matrix

### Converted functions (32)

| # | Object | Args | Latest def | Ticket / migration | Code | Local | Reason |
|---|---|---|---|---|---|---|---|
| 1 | `_can_view_game` | `uuid` | 20261104100000 | KAN-713 | K713 | yes | access helper/location trigger redefined by KAN-713 20261104100000 reading events |
| 2 | `_can_view_game_for_join` | `uuid` | 20261104100000 | KAN-713 | K713 | yes | access helper/location trigger redefined by KAN-713 20261104100000 reading events |
| 3 | `_is_game_host` | `uuid` | 20261104100000 | KAN-713 | K713 | yes | access helper/location trigger redefined by KAN-713 20261104100000 reading events |
| 4 | `_slot_conflicts_game` | `uuid,timestamp with time zone,timestamp with time zone` | 20261104100900 | KAN-728 B09 | B | yes | latest definition is B migration 20261104100900 (reads events) |
| 5 | `active_stream` | `text[],text,integer,timestamp with time zone,text,uuid` | 20261104101200 | KAN-731 B12 | B | yes | latest definition is B migration 20261104101200 (reads events) |
| 6 | `admin_cleanup_user_data` | `uuid,boolean` | 20261104101300 | KAN-732 B13 | B | yes | latest definition is B migration 20261104101300 (reads events) [dynamic-sql] |
| 7 | `admin_overview_row` | `` | 20261104101300 | KAN-732 B13 | B | yes | latest definition is B migration 20261104101300 (reads events) |
| 8 | `can_current_user_join_game` | `uuid,text,uuid` | 20261104100000 | KAN-713 | K713 | yes | access helper/location trigger redefined by KAN-713 20261104100000 reading events [rowtype] |
| 9 | `can_current_user_rsvp_meetup` | `uuid,uuid` | 20261104100000 | KAN-713 | K713 | yes | access helper/location trigger redefined by KAN-713 20261104100000 reading events [rowtype] |
| 10 | `game_slots_left` | `uuid` | 20261104100800 | KAN-727 B08 | B | yes | latest definition is B migration 20261104100800 (reads events via KAN-713 helper / capacity function) |
| 11 | `meetup_slots_left` | `uuid` | 20261104100800 | KAN-727 B08 | B | yes | latest definition is B migration 20261104100800 (reads events via KAN-713 helper / capacity function) |
| 12 | `msg_authorize` | `uuid,text` | 20261104101100 | KAN-730 B11 | B | yes | latest definition is B migration 20261104101100 (reads events) |
| 13 | `msg_evaluate` | `uuid,uuid,text` | 20261104101100 | KAN-730 B11 | B | yes | latest definition is B migration 20261104101100 (reads events) |
| 14 | `msg_my_conversations` | `integer` | 20261104101100 | KAN-730 B11 | B | yes | latest definition is B migration 20261104101100 (reads events) |
| 15 | `rpc_booking_hold_for_meetup` | `uuid,uuid,timestamp with time zone,timestamp with time zone` | 20261104100900 | KAN-728 B09 | B | yes | latest definition is B migration 20261104100900 (reads events) |
| 16 | `rpc_cancel_game_series` | `uuid,text` | 20261104101400 | KAN-733 B14 | B | yes | latest definition is B migration 20261104101400 (reads events) |
| 17 | `rpc_edit_game_series_future` | `uuid,text,integer,time without time zone,integer,uuid,date,boolean` | 20261104101400 | KAN-733 B14 | B | yes | latest definition is B migration 20261104101400 (reads events) |
| 18 | `rpc_edit_game_series_occurrence` | `uuid,text,timestamp with time zone,timestamp with time zone,integer,uuid` | 20261104101400 | KAN-733 B14 | B | yes | latest definition is B migration 20261104101400 (reads events) |
| 19 | `rpc_games_following_joined` | `uuid[]` | 20261104100400 | KAN-723 B04 | B | yes | latest definition is B migration 20261104100400 (reads events) |
| 20 | `rpc_get_activity_feed` | `text,integer,timestamp with time zone` | 20261104101200 | KAN-731 B12 | B | yes | latest definition is B migration 20261104101200 (reads events) |
| 21 | `rpc_get_nearby_games` | `double precision,double precision,integer,uuid,text` | 20261104100400 | KAN-723 B04 | B | no | latest definition is B migration 20261104100400 (reads events) |
| 22 | `rpc_get_nearby_games` | `double precision,double precision,integer,uuid,text,numeric` | 20261104100400 | KAN-723 B04 | B | yes | latest definition is B migration 20261104100400 (reads events) |
| 23 | `rpc_meetup_attendees` | `uuid,text,integer,integer` | 20261104100600 | KAN-725 B06 | B | yes | latest definition is B migration 20261104100600 (reads events) |
| 24 | `rpc_meetup_card` | `uuid,text` | 20261104100600 | KAN-725 B06 | B | yes | latest definition is B migration 20261104100600 (reads events) |
| 25 | `rpc_rate_game` | `uuid,uuid,jsonb,text` | 20261104100800 | KAN-727 B08 | B | yes | latest definition is B migration 20261104100800 (reads events via KAN-713 helper / capacity function) |
| 26 | `rpc_rate_user` | `uuid,uuid,uuid,jsonb,text` | 20261104100800 | KAN-727 B08 | B | yes | latest definition is B migration 20261104100800 (reads events via KAN-713 helper / capacity function) |
| 27 | `rpc_rate_venue` | `uuid,uuid,uuid,jsonb,text` | 20261104100800 | KAN-727 B08 | B | yes | latest definition is B migration 20261104100800 (reads events via KAN-713 helper / capacity function) |
| 28 | `rpc_sport_overview` | `uuid,text` | 20261104100700 | KAN-726 B07 | B | yes | latest definition is B migration 20261104100700 (reads events) |
| 29 | `rpc_unified_search_sectioned` | `text,uuid,double precision,double precision,double precision,integer` | 20261104100500 | KAN-724 B05 | B | yes | latest definition is B migration 20261104100500 (reads events) |
| 30 | `settle_game` | `uuid,boolean` | 20261104101000 | KAN-729 B10 | B | yes | latest definition is B migration 20261104101000 (reads events) |
| 31 | `trg_meetup_rsvps_notify` | `` | 20261104101200 | KAN-731 B12 | B | yes | latest definition is B migration 20261104101200 (reads events) |
| 32 | `trg_meetups_cancel_notify` | `` | 20261104101200 | KAN-731 B12 | B | yes | latest definition is B migration 20261104101200 (reads events) |

### Unchanged functions (94, plus row 73 kept as a RETIRED record and not counted)

| # | Object | Args | Latest def | Ticket / migration | Code | Local | Reason |
|---|---|---|---|---|---|---|---|
| 1 | `_game_belongs_to_venue` | `uuid,uuid` | 20260829080500 | KAN-728 B09 (pinned) | pinned | yes | reads only games.id/venue_space_id (subtype columns); B09 header |
| 2 | `_meetup_link_consume` | `uuid,uuid` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 3 | `_meetup_link_valid` | `uuid,uuid` | 20260829080500 | - | name-only | yes | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 4 | `_user_played_in_game` | `uuid,uuid` | 20260829080500 | - | name-only | yes | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 5 | `actor_capabilities` | `text` | 20260829080500 | - | noshared | no | no shared-column token in body (textual): references games/meetups for id/subtype only |
| 6 | `can_create_game` | `uuid,text` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 7 | `can_create_meetup` | `uuid` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 8 | `can_join_game` | `uuid` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 9 | `can_view_game` | `uuid,uuid` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 10 | `compute_game_fingerprint` | `jsonb` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 11 | `compute_meetup_fingerprint` | `jsonb` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 12 | `events_check_parent_children` | `` | 20261101140000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 13 | `events_check_series_occurrence` | `` | 20261101140000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 14 | `events_check_subtype_link` | `` | 20261101140000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 15 | `fill_game_with_seed_profiles` | `uuid,uuid,text,integer,uuid[]` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 16 | `fn_game_roster_activity_sync` | `` | 20260829080500 | - | trigger | no | trigger function on legacy row (NEW/OLD); write-side |
| 17 | `fn_games_activity_sync` | `` | 20260829080500 | - | trigger | yes | trigger function on legacy row (NEW/OLD); write-side |
| 18 | `fn_games_inherit_geo` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 19 | `fn_games_sync_joining_rule` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 20 | `fn_generate_game_series_occurrences` | `uuid` | 20261030140000 | KAN-733 B14 (pinned) | pinned | yes | write path (generator), KAN-712 wrapped; B14 pinned byte-identical |
| 21 | `fn_meetup_rsvps_activity_sync` | `` | 20260829080500 | - | trigger | no | trigger function on legacy row (NEW/OLD); write-side |
| 22 | `fn_meetups_activity_sync` | `` | 20260829080500 | - | trigger | yes | trigger function on legacy row (NEW/OLD); write-side |
| 23 | `fn_meetups_enforce_solo_sport` | `` | 20260829080500 | - | trigger | yes | trigger function on legacy row (NEW/OLD); write-side |
| 24 | `fn_meetups_inherit_geo` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 25 | `fn_meetups_sync_joining_rule` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 26 | `game_rating_rebuild_all` | `` | 20260829080500 | - | noshared | no | no shared-column token in body (textual): references games/meetups for id/subtype only |
| 27 | `game_rating_recompute` | `uuid` | 20260829080500 | - | name-only | yes | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 28 | `get_seed_profiles_for_games` | `` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 29 | `handle_game_created` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 30 | `handle_player_joined_game` | `` | 20260829080500 | - | name-only | no | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 31 | `kan711_events_backfill_batch` | `text,integer` | 20261102120000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all [dynamic-sql] |
| 32 | `kan711_events_backfill_run` | `integer,integer` | 20261102120000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 33 | `kan711_events_map_game` | `games` | 20261102110000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all [table-typed-arg] |
| 34 | `kan711_events_map_meetup` | `meetups` | 20261102110000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all [table-typed-arg] |
| 35 | `kan711_events_validate_links` | `` | 20261102120000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 36 | `kan711_games_mirror` | `` | 20261102110000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 37 | `kan711_meetups_mirror` | `` | 20261102110000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 38 | `kan712_events_compat_mirror` | `` | 20261103100000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 39 | `kan712_legacy_after_delete` | `` | 20261103100000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 40 | `kan712_legacy_guard` | `` | 20261103100000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 41 | `kan712_wrap_rpc` | `regprocedure,text` | 20261103100000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all [dynamic-sql] |
| 42 | `kan713_events_location` | `` | 20261104110000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 43 | `kan713_games_joining` | `` | 20261104110000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 44 | `kan713_games_location` | `` | 20261104110000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 45 | `kan713_games_venue_geo` | `` | 20261104110000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 46 | `kan713_meetup_attendee_visible` | `uuid` | 20261104100000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 47 | `kan713_meetup_can_read_row` | `uuid` | 20261104100000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 48 | `kan713_meetup_can_write_row` | `uuid` | 20261104100000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 49 | `kan713_meetup_visible` | `uuid` | 20261104100000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 50 | `kan713_meetups_joining` | `` | 20261104110000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 51 | `kan713_meetups_location` | `` | 20261104110000 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 52 | `kan718_series_occurrence_guard` | `` | 20261104110300 | KAN-71x infra | infra | yes | events program infrastructure (KAN-710/711/712/713/718 mirror, backfill, write contract, access/location helpers): created for the events parent, reads legacy by design where it reads it at all |
| 53 | `meetup_my_status` | `uuid,uuid` | 20260915120000 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 54 | `meetups_search_tsv_trigger` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 55 | `msg_game_conversation` | `uuid,text` | 20261017120000 | KAN-730 B11 (pinned) | pinned | yes | reads only games.id existence; shared facts via msg_evaluate (converted); B11 header |
| 56 | `msg_my_conversations_v1` | `integer` | 20261013161000 | - | legacy | no | renamed superseded overload (legacy); no current definition replaces it in place |
| 57 | `msg_system_game_trg` | `` | 20261013160000 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 58 | `normalize_game_scores` | `jsonb` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 59 | `process_notification_event` | `uuid,text,text,uuid,uuid,text,text` | 20260829080500 | - | fp | yes | false-positive candidate: games appears only in a deep-link string literal (/sports/games/<id>); no table read |
| 60 | `rpc_booking_cancel` | `uuid` | 20260829080500 | KAN-728 B09 (pinned) | pinned | yes | reads creator_user_id of games/meetups as auth gate; B09 header: out of piece |
| 61 | `rpc_booking_hold_for_game` | `uuid,uuid,timestamp with time zone,timestamp with time zone` | 20260829080500 | KAN-728 B09 (pinned) | pinned | yes | accepted exception under KAN-712 wrap; reads games.creator_user_id auth gate, writes venue_space_id; B09 header |
| 62 | `rpc_cancel_game` | `uuid,text` | 20260829080500 | KAN-733 B14 (pinned) | pinned | yes | write path, KAN-712 wrapped; B14 pinned byte-identical |
| 63 | `rpc_create_game_legacy_v1` | `text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer` | 20260829080500 | - | legacy | yes | renamed superseded overload (legacy); no current definition replaces it in place |
| 64 | `rpc_create_game_legacy_v2` | `text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric` | 20261008140000 | - | legacy | yes | renamed superseded overload (legacy); no current definition replaces it in place |
| 65 | `rpc_create_game_series` | `text,uuid,uuid,uuid,uuid,date,time without time zone,integer,text,text,integer,text,uuid,date,text,text,integer,numeric` | 20261030120000 | - | name-only | yes | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 66 | `rpc_create_meetup_legacy_v1` | `text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb` | 20260915120000 | - | legacy | yes | renamed superseded overload (legacy); no current definition replaces it in place |
| 67 | `rpc_create_meetup_legacy_v2` | `text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean` | 20261008140000 | - | legacy | yes | renamed superseded overload (legacy); no current definition replaces it in place |
| 68 | `rpc_draft_publish_game` | `uuid` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 69 | `rpc_draft_publish_meetup` | `uuid` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 70 | `rpc_get_nearby_games_legacy_v1` | `double precision,double precision,integer,uuid,text` | 20260829080500 | - | legacy | no | renamed superseded overload (legacy); no current definition replaces it in place |
| 71 | `rpc_leave_game` | `text,uuid` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 72 | `rpc_meetup_cancel` | `uuid` | 20260915120000 | KAN-712 write | write | yes | KAN-712 wrapped write RPC (write path; shared-field writes routed through events by the KAN-712 guard); not a read conversion |
| 73 | `rpc_meetup_my` | `` | 20261104110400 (DROP) | KAN-785 (retired) | retired | no | **RETIRED by KAN-785** (migration 20261104110400, `DROP FUNCTION`). It does not read `events`, it is no longer pinned, it is not in the catalogue, and it is not counted in any total. History: KAN-725 B06 pinned it unchanged because the pre-image raised 42703 on every call (columns owner_user_id/starts_at/visibility do not exist) and had no app call site. |
| 74 | `rpc_meetup_update` | `uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer` | 20260915120000 | KAN-712 write | write | yes | KAN-712 wrapped write RPC (write path; shared-field writes routed through events by the KAN-712 guard); not a read conversion [rowtype] |
| 75 | `rpc_reschedule_game` | `uuid,timestamp with time zone,timestamp with time zone` | 20260829080500 | KAN-712 write | write | yes | KAN-712 wrapped write RPC (write path; shared-field writes routed through events by the KAN-712 guard); not a read conversion |
| 76 | `rpc_update_game` | `uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric` | 20261008140000 | KAN-712 write | write | yes | KAN-712 wrapped write RPC (write path; shared-field writes routed through events by the KAN-712 guard); not a read conversion |
| 77 | `rpc_update_game_legacy_v1` | `uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer` | 20260829080500 | KAN-712 write | write | yes | KAN-712 wrapped write RPC (write path; shared-field writes routed through events by the KAN-712 guard); not a read conversion |
| 78 | `schedule_game_reminders_for_user` | `uuid,uuid,timestamp with time zone,jsonb` | 20260829080500 | - | name-only | no | name-only candidate: name matches game/meetup but body/signature never references public.games or public.meetups |
| 79 | `sync_game_geo` | `` | 20260829080500 | - | name-only | no | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 80 | `trg_after_game_rating_event` | `` | 20260829080500 | - | name-only | no | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 81 | `trg_fn_games_inherit_sport_from_space` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 82 | `trg_fn_games_inherit_venue_geo` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 83 | `trg_fn_games_require_challenge_sport` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 84 | `trg_game_invite_notify` | `` | 20260829080500 | - | name-only | no | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 85 | `trg_game_join_request_notify` | `` | 20260829080500 | - | trigger | no | trigger function on legacy row (NEW/OLD); write-side |
| 86 | `trg_game_updated_notify` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 87 | `trg_game_waitlist_promoted_notify` | `` | 20260829080500 | - | trigger | no | trigger function on legacy row (NEW/OLD); write-side |
| 88 | `trg_games_set_search_tsv` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 89 | `trg_meetup_invite_notify` | `` | 20260829080500 | - | name-only | no | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 90 | `trg_welcome_notify` | `` | 20260829080500 | - | trigger | no | trigger function on legacy row (NEW/OLD); write-side |
| 91 | `trgfn_games_block_frozen` | `` | 20260829080500 | - | name-only | no | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 92 | `trgfn_games_set_host_user` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 93 | `trgfn_invite_block_frozen` | `` | 20260829080500 | - | trigger | no | trigger function on legacy row (NEW/OLD); write-side |
| 94 | `trgfn_meetups_outbox` | `` | 20260829080500 | - | name-only | yes | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |
| 95 | `trgfn_norm_game_scores` | `` | 20260829080500 | - | name-only | no | name-only candidate (trigger function): body never references public.games/meetups; column use, if any, is NEW/OLD on the table it is attached to (write side) |

### Open functions (34)

| # | Object | Args | Latest def | Ticket / migration | Code | Local | Reason |
|---|---|---|---|---|---|---|---|
| 1 | `_recent_activity_score` | `uuid,integer` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 2 | `_user_hosted_game` | `uuid,uuid` | 20260829080500 | - | open-read | yes | reader still references legacy shared columns; no B migration converts it |
| 3 | `game_is_joinable` | `uuid` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 4 | `get_games_needing_players` | `` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 5 | `get_nearby_games` | `double precision,double precision,double precision` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 6 | `get_nearby_games` | `double precision,double precision,integer` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 7 | `get_open_games_for_seeding` | `` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 8 | `getnearbygames` | `double precision,double precision,double precision` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 9 | `getnearbymeetups` | `double precision,double precision,double precision` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 10 | `meetup_counts` | `uuid` | 20260915120000 | - | open-read | yes | reader still references legacy shared columns; no B migration converts it |
| 11 | `nearby_games` | `double precision,double precision,integer,text,integer,integer` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 12 | `rpc_autocomplete_entities` | `text,text[],text,integer` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 13 | `rpc_challenge_spawn_game` | `uuid,timestamp with time zone,uuid` | 20260829080500 | - | open-write | yes | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 14 | `rpc_create_game` | `text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid` | 20261021120200 | - | open-write | yes | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 15 | `rpc_create_meetup` | `text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid` | 20261021120300 | - | open-write | yes | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 16 | `rpc_decide_join_request` | `uuid,boolean` | 20260829080500 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 17 | `rpc_invite_user` | `uuid,uuid` | 20260829080500 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 18 | `rpc_join_game` | `text,uuid,uuid` | 20260829080500 | - | open-write | yes | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 19 | `rpc_meetup_decide_request` | `uuid,uuid,text` | 20260915120000 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B [rowtype] |
| 20 | `rpc_meetup_invite_user` | `uuid,uuid,timestamp with time zone` | 20260829080500 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 21 | `rpc_meetup_mint_link` | `uuid,timestamp with time zone,integer` | 20260829080500 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 22 | `rpc_meetup_remove_attendee` | `uuid,uuid` | 20260915120000 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B [rowtype] |
| 23 | `rpc_meetup_rsvp` | `uuid,text,uuid,uuid` | 20260912190747 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 24 | `rpc_meetup_set_attendee` | `uuid,uuid,text` | 20260829080500 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 25 | `rpc_meetup_visible` | `` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 26 | `rpc_mint_join_link` | `uuid,timestamp with time zone,integer` | 20260829080500 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 27 | `rpc_recreate_from_game` | `uuid,boolean` | 20260829080500 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 28 | `rpc_remove_player` | `uuid,uuid` | 20260829080500 | - | open-write | no | write/mutation RPC still reading legacy shared columns (auth gate / validation); not converted by any B |
| 29 | `rpc_search_entities` | `text,text[],text,integer` | 20260829080500 | - | open-read | no | reader still references legacy shared columns; no B migration converts it |
| 30 | `trgfn_invite_block_frozen_guard` | `` | 20260829080500 | - | open-trigger | no | trigger function that reads legacy shared columns of games/meetups by alias (g.creator_user_id); not converted by any B |
| 31 | `trgfn_joinreq_block_frozen_guard` | `` | 20260829080500 | - | open-trigger | no | trigger function that reads legacy shared columns of games/meetups by alias (g.creator_user_id); not converted by any B |
| 32 | `trgfn_posts_set_geo` | `` | 20260829080500 | - | open-trigger | no | trigger function that reads legacy shared columns of games/meetups by alias (g.area_id,g.geo_location_id); not converted by any B |
| 33 | `trgfn_roster_block_frozen_guard` | `` | 20260829080500 | - | open-trigger | no | trigger function that reads legacy shared columns of games/meetups by alias (g.creator_user_id); not converted by any B |
| 34 | `trgfn_waitlist_block_frozen_guard` | `` | 20260829080500 | - | open-trigger | no | trigger function that reads legacy shared columns of games/meetups by alias (g.creator_user_id); not converted by any B |

### Views (8)

| # | Object | Args | Latest def | Ticket / migration | Code | Local | Reason |
|---|---|---|---|---|---|---|---|
| 1 | `kan711_events_parity` | `` | 20261102120000 | KAN-711 | infra | view | events parity/validation infrastructure: compares legacy with events by design |
| 2 | `v_game_card` | `` | 20261104100100 | KAN-720 B01 | B | view | shared columns from events (pg_rewrite) |
| 3 | `v_game_rating` | `` | 20260829080500 | - | noshared | view | depends only on games.id (subtype id); no shared column |
| 4 | `v_host_weekly_metrics` | `` | 20261104100700 | KAN-726 B07 | B | view | shared columns from events (pg_rewrite) |
| 5 | `v_meetup_counts` | `` | 20261104100200 | KAN-721 B02 | B | view | shared columns from events (pg_rewrite) |
| 6 | `v_meetup_list` | `` | 20261104100200 | KAN-721 B02 | B | view | shared columns from events (pg_rewrite) |
| 7 | `v_my_games` | `` | 20261104100100 | KAN-720 B01 | B | view | shared columns from events (pg_rewrite) |
| 8 | `v_rateable_after_game` | `` | 20261104100300 | KAN-722 B03 | B | view | shared columns from events (pg_rewrite) |

### Residual legacy shared-column references (C6, local catalogue)

| Function (local identity) | alias.column refs |
|---|---|
| `_can_view_game(uuid)` | g.creator_user_id, g.listing_visibility |
| `_can_view_game_for_join(uuid)` | g.creator_user_id, g.listing_visibility |
| `_is_game_host(uuid)` | g.creator_user_id |
| `_slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)` | g.end_at, g.is_cancelled, g.start_at |
| `_user_hosted_game(uuid,uuid)` | g.creator_user_id |
| `active_stream(text[],text,integer,timestamp with time zone,text,uuid)` | g.creator_user_id, g.is_cancelled, m.creator_user_id, m.is_cancelled, m.listing_visibility |
| `can_current_user_join_game(uuid,text,uuid)` | g.creator_user_id, g.is_cancelled, g.join_policy, g.listing_visibility, g.start_at |
| `can_current_user_rsvp_meetup(uuid,uuid)` | m.creator_user_id, m.is_cancelled, m.listing_visibility, m.rsvp_policy, m.start_at |
| `fn_generate_game_series_occurrences(uuid)` | g.is_cancelled, g.start_at |
| `game_slots_left(uuid)` | g.capacity |
| `kan712_events_compat_mirror()` | g.area_id, g.cancelled_at, g.cancelled_reason, g.capacity, g.cost_cover, g.creator_profile_id, g.creator_user_id, g.end_at, g.geo_location_id, g.is_cancelled, g.join_policy, g.joining_rule, g.listing_visibility, g.max_skill, g.min_skill, g.request_id, g.sport_id, g.start_at, g.title, g.venue_id, mt.area_id, mt.capacity, mt.cost_cover, mt.creator_profile_id, mt.creator_user_id, mt.end_at, mt.geo_location_id, mt.is_cancelled, mt.joining_rule, mt.listing_visibility, mt.max_skill, mt.min_skill, mt.request_id, mt.rsvp_policy, mt.sport_id, mt.start_at, mt.title, mt.venue_id |
| `meetup_counts(uuid)` | m.creator_user_id, m.listing_visibility |
| `rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid)` | g.creator_user_id, g.request_id |
| `rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid)` | m.creator_user_id, m.request_id |
| `rpc_edit_game_series_future(uuid,text,integer,time without time zone,integer,uuid,date,boolean)` | g.start_at |
| `rpc_get_activity_feed(text,integer,timestamp with time zone)` | g.is_cancelled |
| `rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)` | g.creator_user_id, g.listing_visibility |
| `rpc_meetup_cancel(uuid)` | m.creator_user_id |
| `rpc_meetup_update(uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer)` | m.creator_user_id, m.end_at, m.is_cancelled, m.start_at |
| `rpc_rate_game(uuid,uuid,jsonb,text)` | g0.is_cancelled |
| `rpc_rate_user(uuid,uuid,uuid,jsonb,text)` | g0.creator_user_id, g0.is_cancelled, g0.start_at |
| `rpc_rate_venue(uuid,uuid,uuid,jsonb,text)` | g0.creator_user_id, g0.is_cancelled |
| `rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)` | g.is_cancelled, g.listing_visibility, m.is_cancelled, m.listing_visibility, m.search_tsv |
| `rpc_update_game(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)` | g.capacity, g.creator_user_id, g.end_at, g.is_cancelled, g.join_policy, g.listing_visibility, g.max_skill, g.min_skill, g.title |
| `rpc_update_game_legacy_v1(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer)` | g.capacity, g.creator_user_id, g.join_policy, g.listing_visibility, g.title |

`rpc_meetup_my()` (`m.title`) was in this table until KAN-785 retired the function; C6 now expects 25 rows.

### Inbound foreign keys (21)

| # | Table | Constraint | Target | Defined in | Status | Reason |
|---|---|---|---|---|---|---|
| 1 | `activity_events` | `activity_events_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 2 | `challenge_fixtures` | `challenge_fixtures_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 3 | `favorites` | `favorites_game_id_fkey` | `games.id` | 20261008120000_games_listing_match1_card_fields.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 4 | `favorites` | `favorites_meetup_id_fkey` | `meetups.id` | 20261008120000_games_listing_match1_card_fields.sql | unchanged | targets the subtype PK `meetups.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 5 | `game_invites` | `game_invites_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 6 | `game_join_requests` | `game_join_requests_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 7 | `game_link_tokens` | `game_link_tokens_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 8 | `game_rating_aggregate` | `game_rating_aggregate_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 9 | `game_rating_events` | `game_rating_events_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 10 | `game_roster` | `game_roster_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 11 | `game_settlements` | `game_settlements_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 12 | `game_waitlist` | `game_waitlist_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 13 | `meetup_attendees` | `meetup_attendees_meetup_id_fkey` | `meetups.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `meetups.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 14 | `meetup_invites` | `meetup_invites_meetup_id_fkey` | `meetups.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `meetups.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 15 | `meetup_link_tokens` | `meetup_link_tokens_meetup_id_fkey` | `meetups.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `meetups.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 16 | `meetup_rsvps` | `meetup_rsvps_meetup_id_fkey` | `meetups.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `meetups.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 17 | `msg_conversations` | `msg_conversations_game_id_fkey` | `games.id` | 20261013150000_kan505_msg_registry.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 18 | `msg_conversations` | `msg_conversations_meetup_id_fkey` | `meetups.id` | 20261017130000_kan558_msg_meetup_chat.sql | unchanged | targets the subtype PK `meetups.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 19 | `posts` | `posts_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 20 | `user_reputation_events` | `user_reputation_events_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |
| 21 | `venue_rating_events` | `venue_rating_events_game_id_fkey` | `games.id` | 20260829080500_baseline_schema.sql | unchanged | targets the subtype PK `games.id`, which the product contract keeps (events.id = subtype id); no shared column involved |

## 6. Open list (34) — no fix in this ticket

These are listed by capability. Every one is backend schema work, and each needs a ticket from `po`. **17 of the 34
are also named by the untracked, uncommitted `20261105100000_kan714_events_parent_reads.sql` /
`20261105110000_*_2.sql` in this worktree.** Those files belong to no B ticket I own, are excluded from this audit by
the brief, and are not evidence of conversion: get_games_needing_players, get_open_games_for_seeding, meetup_counts,
nearby_games, rpc_autocomplete_entities, rpc_create_game, rpc_create_meetup, rpc_decide_join_request,
rpc_invite_user, rpc_join_game, rpc_meetup_decide_request, rpc_meetup_remove_attendee, rpc_meetup_rsvp,
rpc_mint_join_link, rpc_recreate_from_game, rpc_remove_player, rpc_search_entities.

- **open-read (14):**
  - `_recent_activity_score`
  - `_user_hosted_game` (**transitive**: called by converted `rpc_rate_venue`)
  - `game_is_joinable`
  - `get_games_needing_players`
  - `get_nearby_games` ×2
  - `get_open_games_for_seeding`
  - `getnearbygames`
  - `getnearbymeetups`
  - `meetup_counts(uuid)`
  - `nearby_games`
  - `rpc_autocomplete_entities`
  - `rpc_meetup_visible`
  - `rpc_search_entities`
- **open-write (15):**
  - `rpc_challenge_spawn_game`
  - `rpc_create_game`
  - `rpc_create_meetup`
  - `rpc_decide_join_request`
  - `rpc_invite_user`
  - `rpc_join_game`
  - `rpc_meetup_decide_request`
  - `rpc_meetup_invite_user`
  - `rpc_meetup_mint_link`
  - `rpc_meetup_remove_attendee`
  - `rpc_meetup_rsvp`
  - `rpc_meetup_set_attendee`
  - `rpc_mint_join_link`
  - `rpc_recreate_from_game`
  - `rpc_remove_player`
- **open-trigger (5):** `trgfn_invite_block_frozen_guard`, `trgfn_joinreq_block_frozen_guard`,
  `trgfn_roster_block_frozen_guard` and `trgfn_waitlist_block_frozen_guard` (all read `g.creator_user_id`), and
  `trgfn_posts_set_geo` (`g.area_id`, `g.geo_location_id`).
- **Phase-4 prerequisites, not open reads, but recorded here so they are not lost:**
  - the §3 whole-row KAN-711 functions;
  - the §4 residual references;
  - the NEW.* trigger functions.

## 7. Method

1. **Repo scan.** Every tracked migration is read in filename order, with SQL comments stripped and the latest
   definition winning (see §2). A function is a candidate when any of these holds:
   - its body, header or argument list names `games`/`meetups`;
   - its name contains `game`/`meetup`;
   - its latest definition is a B01–B14 migration (`2026110410(01..14)00_kan714_b*`).

   Views are found by `CREATE/DROP VIEW`. FKs are found from `REFERENCES public.games|meetups` in
   `CREATE TABLE` / `ALTER TABLE … ADD CONSTRAINT|ADD COLUMN`, and are removed by `DROP CONSTRAINT` / `DROP TABLE`.
2. **Classification.** Rules are applied in order:
   1. the latest definition is in a B file → converted (that B);
   2. a B header pins it → unchanged, pinned;
   3. events infrastructure;
   4. a KAN-713 redefinition → converted (KAN-713);
   5. KAN-712 write;
   6. legacy overload;
   7. name-only;
   8. false positive;
   9. trigger (open when it reads another games/meetups row by alias);
   10. write RPC (open);
   11. no shared token (unchanged);
   12. otherwise open-read.
3. **Local catalogue.** The full chain was rebuilt in local PG16: harnesses, KAN-710/711 backfill, KAN-712/713/718,
   then B01–B14 with each B's own pre-image fixture. The probe then re-derives the following from `pg_proc`,
   `pg_depend`/`pg_rewrite`, `pg_constraint` and `pg_attribute`, and compares each to this manifest:
   - candidate coverage (C2);
   - the present set (C3);
   - converted reads events (C4);
   - open still reads legacy (C5);
   - residual references (C6);
   - rowtype (C7);
   - composites (C8);
   - views (C9);
   - dynamic SQL (C10);
   - transitive calls (C11);
   - FKs (C12);
   - pre-image shapes (C13).
4. **Scenario (S1–S5).** Inside a transaction that ends in ROLLBACK, the probe seeds:
   - 1 public game;
   - 1 private game with a NULL title;
   - 1 public meetup;
   - 1 hidden meetup.

   It seeds them through the plain legacy INSERT path, then checks:
   - each row gets exactly one `events` parent, with id kept and NULL preserved (S1);
   - no doubled rows, and the owner sees each game once in `v_my_games` (S2);
   - stranger and anon see +1 game and +1 meetup (public only), the owner sees 2/2, and `game_slots_left` /
     `meetup_slots_left` equal the legacy reference (S3);
   - a user blocked by the owner sees none of the 4 rows, and non-owners see none in `v_my_games` (S4);
   - the md5 fingerprints of games, meetups and events are identical after ROLLBACK (S5).
5. **Negative controls (in the clean proof):**
   - before B01, the probe fails T0;
   - with `-v corrupt=1`, which swaps an open row and a converted row (so the totals still match), the probe fails C4;
   - with one recorded pre-image shape tampered, the probe fails C13.

## 8. Limitations

- **Textual heuristics:**
  - The alias heuristic misses unqualified column references (for example `select is_cancelled from public.games`).
    Classification therefore treats any shared-column token as possibly legacy, which is conservative.
  - Dynamic SQL cannot be resolved.
  - plpgsql has no `pg_depend` for function bodies, so every function-level dependency is textual.
- **Local catalogue is a harness subset.** 99 of the 160 manifest function identities exist locally (100 of 161 before KAN-785). 6 of the 34
  open functions exist locally (`_user_hosted_game`, `meetup_counts`, `rpc_challenge_spawn_game`, `rpc_create_game`,
  `rpc_create_meetup`, `rpc_join_game`). The other 61 are covered by the repo scan only. Only 1 of the 21 FKs exists
  locally; C12 checks that one and the rule.
- **Production was not read.** Production drift, functions outside `public`, and the 141/20 audit list are **not
  documented** here.
- **The 5-argument `rpc_get_nearby_games`** that B04 converts "only if present" is absent from the local chain, so it
  is classified from the repo only.
- C13 compares against the first shape captured before each B migration. An object created by a harness after its
  first capture is compared against the earlier capture.
