# docs/SCHEMA.md — Supabase Schema

**Owner:** master-analyst (write) · all agents (read)
**Project:** `wtncuzcskpigqpmnxwws` (org: Onebrain)
**Verified live via Supabase MCP:** 2026-08-26. Not transcribed from Dart models.

> **A second, unrelated project exists on this account. Never read or write it.**

**No credentials or connection strings appear in this file, and none may be added.**

---

## SCOPE OF THIS DOCUMENT — read before relying on it

The `public` schema has **184 tables**, **~180 RPCs**, **~200 triggers** and **71 views**.
Column-level documentation of all 184 tables would be tens of thousands of lines, would
drift within a week, and would compete with the database itself as a source of truth.

**So this file documents what cannot be discovered quickly, and points at the database for
what can:**

- **Every table's RLS position** — stated for all 184, none blank. This is the security
  surface and it is not obvious from any query an agent thinks to run.
- **The RPC generations** — where several coexist for the same job and only one is current.
- **The triggers** — grouped, with the ones that carry business rules named.
- **Known mismatches** — where the app expects something the database does not have.

**For columns, types, nullability and foreign keys, query the live database.** Use
`list_tables` with `verbose: true`, or `information_schema.columns`. That is authoritative;
this file would only be a stale copy of it.

---

## 1. RLS POSITION — ALL 184 TABLES

**Summary:** 184 tables · 183 RLS-enabled · 153 with policies · 336 policies total.

### 1a. RLS ENABLED, ZERO POLICIES — 30 tables

**These deny all access to `anon` and `authenticated`.** A query against one returns an
empty result, not an error, so client code reading them appears to work and silently gets
nothing. Verified: `select count(*) from games` as `authenticated` returns **0**.

```
admins                app_admins            blackouts             challenge_fixtures
challenge_invites     challenge_squads      challenge_stages      challenge_types
content_drafts        context_rating_config game_invites          game_link_tokens
games                 meetup_invites        meetup_link_tokens    moderation_ban_terms
moderation_tickets    reputation_config     reuse_fingerprints    reuse_user_stats
safety_blocklist_terms safety_takedowns     space_slot_holds      squad_invites
squad_join_requests   squad_link_tokens     squad_members         surface_catalog
user_hidden_modes     vibes_reco_config
```

**Each needs one of two verdicts, and neither has been given.** Either the table is reached
only through `SECURITY DEFINER` RPCs — in which case that is a legitimate design and must be
**documented as such** so the next audit does not re-flag it — or it is missing policies.
Triage is KAN-26.

**KAN-26 triage, proposed by `backend-owner` 2026-09-01 (verify before treating as final —
this section stays `master-analyst`'s to confirm).** Ran
`pg_proc.prosrc ILIKE '%tablename%' AND prosecdef` across all 30 — a population count, not an
advisor guess, per `T-020`.

* **28 of 30 — intentional, RPC-only.** At least one live `SECURITY DEFINER` function
  references the table by name. `admins`, `app_admins`, `blackouts`, `challenge_fixtures`,
  `challenge_invites`, `challenge_squads`, `challenge_stages`, `content_drafts`,
  `context_rating_config`, `game_invites`, `game_link_tokens`, `games`, `meetup_invites`,
  `meetup_link_tokens`, `moderation_ban_terms`, `moderation_tickets`, `reputation_config`,
  `reuse_fingerprints`, `reuse_user_stats`, `safety_blocklist_terms`, `safety_takedowns`,
  `space_slot_holds`, `squad_invites`, `squad_join_requests`, `squad_link_tokens`,
  `squad_members`, `user_hidden_modes`, `vibes_reco_config`. No policy added; deny-all at the
  table is correct, reads go through the definer funnel by design (matches the `games`/`T-024`
  finding above). `games` alone has 38 definer-function references — the funnel is real and
  heavily used, not a one-off.
* **`games`'s dead direct-table path, settled.** `lib/features/games/data/repositories/games_repository_impl.dart`
  (`GamesRepository`, ~15.5k LOC across the slice) issues direct `.from('games')` calls and
  would return nothing under this RLS shape — but it is never imported by any provider or
  screen, and not in `lib/providers.dart`. **Dead, not dead-and-broken**: nothing live
  exercises the path this deny-all would break, because nothing live calls it. A removal call
  belongs to KAN-31/32, not this ticket.
* **2 of 30 — genuine gap, fixed.** `challenge_types` (8 seed rows, has `is_active`) and
  `surface_catalog` (30 seed rows) are static read-only catalog tables — same shape as
  `sports`/`sport_variants`, which already carry a `<table>_read_active` SELECT policy +
  `<table>_no_write` deny-all policy pair. Zero `SECURITY DEFINER` functions and zero Dart
  callers reference either today, but both already carried pre-KAN-67 `anon`/`authenticated`
  table-level GRANTs — the intent was public read, nobody added the RLS policy after enabling
  RLS. Fixed in `supabase/migrations/20260901153415_kan26_definer_view_and_rls_triage.sql`
  (authored, not applied) using the `sports`/`sport_variants` pattern exactly.

**`games` is the consequential one.** It is the core domain table, it has no policies, and
`lib/features/games/data/datasources/supabase_games_datasource.dart` issues 20 direct
`.from(gamesTable)` queries against it. Every one returns nothing. The live game path
avoids this by reading the `v_game_card` view and calling RPCs instead.

**KAN-950 (2026-11-14): `games` still has no policy, on purpose; the listing nudge has its own
table.** Realtime applies the subscriber's SELECT RLS, so the KAN-755 games listing nudge never
reached a client. A games SELECT policy was rejected because several invoker gates treat "the
caller sees no games row" as their deny signal: `trgfn_joinreq_block_frozen_guard`, the roster,
waitlist and invite guards, `trgfn_posts_set_geo`, `_user_hosted_game`, `game_is_joinable` and
`_recent_activity_score`. A policy would change the path each of them takes. A direct client insert
into `game_join_requests` would still fail, at `kan803_game_host_uid` (postgres and service_role
only; PEER 16342), but the gates would no longer fail where they were designed to. It would also expose
`squad_id`, `sport_specific_data` and `event_id`, which `v_game_card` does not return.
`public.game_listing_nudges` (game_id pk, changed_at) works this way:
- RLS is on, with one SELECT policy for `authenticated`: `_can_view_game(game_id)`, the
  `v_game_card` predicate.
- Grants: SELECT to `authenticated` only. `anon` has nothing (it gets 42501), and no client role
  can write.
- It is upserted by the SECURITY DEFINER triggers `trg_kan950_games_listing_nudge_ins` and
  `trg_kan950_games_listing_nudge_upd` on games: on insert, and when `event_changed_at` moves
  (KAN-949).
- It is published in `supabase_realtime`.
- No FK, and rows are never deleted, because Realtime does not apply RLS to DELETE.

Migration `20261114124928`, live test
`supabase/tests/events_p4/kan950_game_listing_nudges_live_test.sql`. Any new gate that needs
"can this caller see the game" should call `_can_view_game` rather than rely on games RLS.

**Independent client-side corroboration that the definer funnel is deliberate** *(added
2026-08-28, found by `cto`)*. The zero-policy tables read as drift until you find that the
app was written to route around them on purpose. `game_composer_screen.dart:205-207` says so
in a doc comment:

```dart
/// Prefills the composer from an existing game (edit mode). Reads the same
/// `v_game_card` view the detail screen uses — the raw `games` table is not
/// client-readable (RLS with no policies).
```

Verified: `select count(*) from public.games` as `anon` returns **0**. So whoever built this
knew the base tables deny and funnelled reads through definer views by design — which matches
what the `prosrc` measurement showed from the database side. **Two independent sources, one
conclusion: the definer funnel is architecture, not accident.**

That does not make the funnel safe — SEC-16 exists because the same mechanism grants writes
nobody intended — but it does mean **the remediation must preserve the read path.** Anyone
tempted to "fix" the zero-policy tables by converting the views to `security_invoker` would
blank the app: with no policies on the base tables, an invoker view returns nothing.

**RULING (`cto` `T-024`, counts re-verified here 2026-08-28): a definer view over a
zero-policy base table stays definer.** The constraint above turned out to expose a direct
conflict between two earlier decisions — one said "flip the definer views to
`security_invoker`, adding base-table policies first so screens don't blank"; the other said
the zero-policy tables are served through the definer funnel *by design* and rejected "add
policies to all 30". **Both cannot be executed.** The first one's safety step is the exact
thing the second rejects.

Measured policy counts on the base tables reached by definer views:

| Base table | RLS | Policies |
|---|---|---:|
| `games` | on | **0** |
| `content_drafts` | on | **0** |
| `user_hidden_modes` | on | **0** |
| `user_reputation_aggregate` | on | 1 |
| `meetups` | on | 2 |
| `notifications` | on | 4 |
| `posts` | on | 5 |
| `profiles` | on | 13 |

`games` has RLS on and **zero policies**, and `v_game_card` reads it. Flipping that view to
invoker returns **zero rows to every user, signed in or not** — explore, social feed, game
history, nearby games, the detail screen. That is a certainty, not a risk, and it lands on
the most-used surfaces first.

**Refinement to the ruling, added here:** a non-zero policy count is **necessary but not
sufficient** to make a view safe to flip. `notifications` has 4 policies, but the only
INSERT policy is `n_block_insert WITH CHECK (false)` — a policy count says nothing about
whether the policies serve the *read pattern the view depends on*. **Before flipping any
view, check that the base table's policies admit the rows that view is expected to return
for the roles that call it** — count first as a filter, then read the policies.

**The corollary about failure modes:** "a blank screen is the correct failure, it surfaces
the missing policy" holds where a policy is *missing*. It does not hold where the absence is
the *design*. Shipping a blank explore tab to make a point about a table that was never meant
to be client-readable is not a correct failure.

### 1b. RLS DISABLED — 1 table

`spatial_ref_sys` — **not a finding.** PostGIS system table, owned by the extension. RLS
cannot be enabled on it and it holds no application data.

### 1c. RLS ENABLED WITH POLICIES — 153 tables

Policy counts, grouped by domain. A high count is not automatically good — `profiles` has 13
policies, which is a complexity worth understanding before adding a fourteenth.

**Identity & profile:** `profiles` 13 · `sport_profiles` 9 · `privacy_settings` 3 ·
`profile_follows` 4 · `profile_locations` 4 · `profile_circles` 1 · `profile_circle_members` 1 ·
`profile_tiers` 2 · `profile_verifications` 1 · `player` 3 · `host` 3 · `organiser` 6 ·
`user_settings` 4 · `user_preferences` 1 · `user_status` 3 · `user_actor_pref` 1 ·
`consent_records` 4 · `roles` 1 · `role_grants` 2 · `restrictions` 1

**Usernames & display names:** `username_registry` 3 · `username_changes` 2 ·
`username_attempts` 2 · `username_banned` 2 · `username_reserved` 2 · `display_name_banned` 2

**Social:** `posts` 5 · `comments` 4 · `likes` 4 · `reactions` 4 · `post_media` 2 ·
`post_mentions` 5 · `comment_mentions` 3 · `post_hashtags` 2 · `hashtags` 2 · `post_views` 2 ·
`post_reposts` 3 · `post_hides` 4 · `post_circles` 1 · `post_squads` 2 · `post_themes` 1 ·
`circles` 6 · `circle_members` 5 · `feed_items` 1 · `feed_rank_config` 1 ·
`public_activities` 2 · `activity_events` 1 · `activity_log` 2 · `user_blocks` 3 ·
`user_hashtag_preferences` 2 · `friend_requests_audit` 1

**Games & meetups:** `game_roster` 4 · `game_waitlist` 3 · `game_join_requests` 3 ·
`game_rating_events` 1 · `game_rating_aggregate` 1 · `game_rating_dimensions` 1 ·
`game_settlements` 1 · `meetups` 2 · `meetup_attendees` 6 · `meetup_rsvps` 1 · `challenges` 4 ·
`squads` 3

**Venues:** `venues` 3 · `venue_spaces` 3 · `venue_bookings` 5 · `venue_members` 4 ·
`venue_favorites` 3 · `venue_photos` 1 · `venue_blackouts` 2 · `venue_price_rules` 2 ·
`venue_submissions` 7 · `venue_submission_sports` 1 · `venue_rating_events` 1 ·
`venue_rating_aggregate` 1 · `venue_rating_dimensions` 1 · `venue_payouts` 1 ·
`space_prices` 1 · `space_slot_grid` 2 · `opening_hours` 1 · `amenities_catalog` 1

**Notifications:** `notifications` 4 · `notification_settings` 3 ·
`notification_user_preferences` 2 · `notification_deliveries` 2 · `notification_kinds` 1 ·
`notification_scores` 1 · `notification_aggregates` 1 · `notification_aggregation_rules` 1 ·
`notification_hourly_caps` 1 · `fcm_tokens` 4

**Rewards & reputation:** `badges` 2 · `badge_rules` 2 · `user_badges` 1 ·
`sport_profile_badges` 1 · `sport_profile_profile_badges` 1 · `sport_profile_tiers` 1 ·
`sport_profile_events` 1 · `point_ledger` 1 · `reward_rules` 1 · `levels` 1 · `tiers` 1 ·
`user_reputation_events` 1 · `user_reputation_aggregate` 1 · `reputation_dimensions` 1 ·
`user_check_ins` 3 · `check_in_logs` 2

**Money:** `wallets` 2 · `wallet_ledger` 2 · `payment_intents` 1 · `payouts` 5 ·
`payout_beneficiaries` 4 · `financial_ledger` 1 · `commission_rules` 2 ·
`subscription_plans` 1 · `subscription_features` 1 · `user_subscriptions` 1

**Moderation & safety:** `moderation_reports` 2 · `moderation_actions` 1 ·
`moderation_flags` 1 · `safety_cooldowns` 2 · `user_freezes` 2 · `rating_reports` 1 ·
`ratings` 1 · `audit_events` 1

**Geography:** `geo_locations` 2 · `areas` 1 · `location_tags` 3 · `ref_countries` 1 ·
`ref_regions` 1 · `ref_cities` 1

**Sports reference:** `sports` 2 · `sport_variants` 2 · `sport_aliases` 1 ·
`sport_skill_levels` 1 · `sportskilllevels` 1 · `sport_governing_bodies` 2 ·
`sport_governing_body_links` 2 · `sport_popularity_countries` 1 · `sport_popularity_regions` 1 ·
`sport_primary_sport_countries` 1

**Vibes:** `vibes` 1 · `vibe_collections` 1 · `vibe_collection_items` 1 · `visibility_scopes` 1

**Other:** `news` 1 · `briefs` 1 · `demo_content` 4 · `analytics_events` 2 ·
`content_draft_events` 1 · `reuse_global_stats` 1

---

## 2. VIEWS — FULL ANON-EXPOSURE CENSUS

**Verified 2026-08-27. 71 views in `public`** — not 49, which is what an earlier version of
this file said. See §10 for how that number was wrong.

| Position | Count | Meaning |
|---|---:|---|
| **EXPOSED** | **19** | `SECURITY DEFINER` + anon-selectable + **no `auth.uid()` predicate**. Bypasses RLS for an unauthenticated caller |
| definer + anon-granted, returns rows | **2** | **CORRECTED 2026-08-28 — `v_game_card` (216 rows) and `v_meetup_list` (1 row) are readable by `anon`.** Not an RLS bypass of private data — both return only `listing_visibility = 'public'` rows — but both expose `creator_user_id`, `creator_username`, `creator_display_name`, `creator_avatar_url`, start time and venue to an unauthenticated caller. See SEC-15. **SEC-17 (KAN-87) — RESOLVED 2026-09-01.** Dart call sites migrated 2026-08-30; the view migration (originally `20260830120000_...`, re-applied as `20260901..._kan87_drop_creator_user_id_from_v_game_card_v2` via `DROP VIEW`+`CREATE VIEW` since `CREATE OR REPLACE VIEW` cannot drop a column) is live. `v_game_card` no longer returns `creator_user_id`; only `creator_profile_id` is exposed. Verified: anon row count unchanged (217), `reloptions` unchanged (NULL) |
| definer + anon-granted, returns 0 | 6 | Empty for `anon`, **verified by query, not by reading the definition** |
| anon-revoked | 23 | `anon` has no SELECT grant — safe by grant |
| invoker | 21 | `security_invoker = true` — the underlying table's RLS applies |
| **Total** | **71** | |

**Every view has a stated position. That is the point of this section** — the previous
version gave counts without a per-view verdict, and that gap is exactly why two live leaks
went unnoticed.

### 2a. EXPOSED — 19 views readable by `anon` with no uid predicate

**Confirmed leaking real user data — CRITICAL when measured. All five are now CLOSED; see the
resolution note below the table. The table is retained as the record of what was exposed, and the
per-row verdicts are marked with their closing ticket.**

| View | Rows to `anon` | Exposure |
|---|---:|---|
| `v_notifications_feed` | **609** | `to_user_id`, `title`, `body`, `action_route`, `context` across **49 distinct recipients**. KAN-36 |
| `v_notifications_ranked` | **609** | Same base table, same exposure. KAN-37 |
| `v_mod_queue_open` | 9 | Open moderation tickets. KAN-38 |
| `v_safety_overview` | 1 | Admin safety metrics. KAN-38 |
| `v_circle_feed` | 6 | Scoped circle content |

**The base table is not the problem.** `select count(*) from notifications` as `anon`
returns **0** — RLS on `notifications` works correctly. Two `SECURITY DEFINER` views route
around it. That distinction matters: this is not "RLS is missing", it is "RLS is bypassed".

**Reproduction — run this before and after any fix:**
```sql
set local role anon;
select count(*) as rows, count(distinct to_user_id) as recipients
  from public.v_notifications_feed;          -- currently 609 / 49; must become 0
select count(*) from public.notifications;   -- 0 — the control. If this is ever
                                             -- non-zero, the base RLS broke too
```
A probe without a control proves nothing. `v_my_drafts` returning 0 under the same role is
the second control that shows the method discriminates.

**CORRECTED 2026-08-29. The previous heading read "RESOLVED — all twelve now have an explicit verdict, none is outstanding." That was false, and it was false about the three worst views in the section.** `task-auditor` caught it reviewing KAN-19.

**Three CRITICAL-leaking views had no verdict row and were silently deferred to KAN-25** — the deferral was real but recorded nowhere in §2a, so the section claimed completeness it did not have. **The arithmetic gives it away and I did not check it:** 19 exposed − 2 PostGIS = **17 app views needing a verdict**; the table below covers **14**. The three missing are exactly the gap.

**They are live right now — re-measured as `anon` 2026-08-29, with two controls in the same transaction** (`v_notifications_feed` = 0, confirming the KAN-37 fix; `v_game_card` = 216, confirming the probe discriminates):

| View | Rows to `anon` | What is exposed | Verdict |
|---|---:|---|---|
| `v_mod_queue_open` (**CLOSED**) | **9** | `reporter_username`, `target_username`, `reason`, `details`, `target_user_id` — 7 reports on posts, 2 on users, all `status = 'open'` | **CRITICAL when measured — RESOLVED 2026-08-29, KAN-56** (`anon` now gets `42501`). **This deanonymised reporters to the people they reported.** Worse in kind than a data leak: it is a safety risk to the reporter, and the moderation screen is correctly gated (`moderation_queue_screen.dart:22`) while the data behind it is not. `SEC-03` |
| `v_circle_feed` (**CLOSED**) | **6** | `author_user_id` (auth UUID), `author_display_name`, `body`, `circle_name` — **all 6 rows are `visibility = 'circle'` inside `circle_type = 'private'`** | **CRITICAL when measured — RESOLVED 2026-08-29, KAN-56** (flipped to invoker, 0 rows). Private circle posts were readable with no account. **Not the `v_game_card` public-listing class** — nothing here was marked public by anyone |
| `v_safety_overview` (**CLOSED**) | **1** | `reports_open`, `active_enforcements`, `takedowns_active`, `audits_24h` | **HIGH when measured — RESOLVED 2026-08-29, KAN-56** (`anon` now gets `42501`). Aggregate only, no per-user rows — the moderation posture of the platform, readable by anyone. Lower than the other two because it names nobody. `SEC-02` |

**RESOLVED 2026-08-29 — all three, by KAN-56, applied before my flag arrived.** Re-verified here as `anon`: **`v_mod_queue_open` and `v_safety_overview` now raise `42501 permission denied`** — the SELECT grant is revoked, which is a stronger closure than returning zero rows. **`v_circle_feed` returns 0** (was 6) and `v_circle_feed_visible` 0, both flipped to invoker. Controls in the same transaction unchanged: `v_game_card` 216, `v_comments` 66 — **no cascade.** The table above is kept as the record of what was exposed and for how long; the exposure itself is closed. **My pre-flight — `v_mod_queue_open` must be revoked, not flipped, because `moderation_reports`' two policies both deny SELECT — arrived after the migration and matched the ruling that shipped.** It stands as a third independent confirmation, not a fresh finding. They were the same class KAN-37/KAN-67 closed and were left behind by both.

**The other fourteen do have verdicts, and those stand:**

The list below used to read *"not yet probed, deferred to KAN-26"*, with the note that
*"probably public" is not a security position*. KAN-37 and KAN-38 ruled on all of them and
shipped fixes for most, but §2a was never updated while §2d's counts were. **State re-measured
rather than transcribed**; every row is a live reading, control `v_game_card` = 216 in the same
transaction.

| View | `anon` SELECT | invoker | Rows to `anon` | Verdict |
|---|:--:|:--:|---:|---|
| `v_challenge_standings` | **revoked** | — | n/a | **Closed** — SELECT revoked for `anon`+`authenticated`, migration `20260828193807` |
| `v_game_rating` | **revoked** | — | n/a | **Closed** — same migration |
| `v_user_badges_summary` | **revoked** | — | n/a | **Closed** — scoped to `WHERE user_id = auth.uid()` **and** `anon` SELECT revoked |
| `v_notifications_feed` / `_ranked` | granted | **yes** | **0** | **Closed** — flipped to invoker; were 611 rows across 51 users. SEC-01 |
| `v_user_reputation` | granted | **yes** | **0** | **Closed** — flipped to invoker |
| `v_meetup_counts` | granted | **yes** | **0** | **Closed** — flipped to invoker |
| `v_comments` | granted | **yes** | 66 | **Closed** — invoker + **LEFT JOIN** `profiles`; 67 → 66, the one leaking row was a comment on a non-public parent. The 18 null-author rows are retained deliberately |
| `v_post_comments` | granted | **yes** | 66 | **Closed** — same migration |
| `v_circle_feed_visible` | granted | no | **0** | **No leak.** Definer and anon-granted, but returns nothing. Left as-is |
| `v_potential_vibes_default` | granted | no | **0** | **Intentionally public — `T-027`.** Function-backed: `security_invoker` is a **no-op** when the `FROM` is a set-returning function. `KAN-162` established the caller-controlled-identity chain that voided this for a sibling view; `KAN-174`/`T-070` closed the matching gap here by dropping the 7-arg `rpc_potential_vibes(..., p_me uuid)` overload entirely — only the 6-arg, `auth.uid()`-deriving form remains, `EXECUTE` verified live post-fix (`has_function_privilege`) and over an actual PostgREST HTTP round-trip: anon gets `200 []`, and the removed 7-arg signature is unreachable (`404 PGRST202`). Access control now genuinely lives inside the one remaining function. Probed, not assumed |
| `v_recreate_quickpicks` | granted | no | **0** | **Intentionally public — `T-027`.** Same mechanism |
| `username_registry_public` | *dropped* | n/a | n/a | **DROPPED — `KAN-141`.** The `T-027` note below ("a lookup queried with a predicate") did not match the object: the view body was `SELECT list_active_usernames()`, which returns **every** active username, and `anon` could select it unfiltered. Its `0` was an empty `username_registry`, not a control. `SECURITY DEFINER` on the function bypassed the table's own `username_registry_no_read` RLS. Dropped with the function; signup availability is served by `rpc_username_availability(text)` |
| `v_space_slots_today` | granted | no | **errors (until KAN-74 applied)** | **`BUG-05`, being fixed via KAN-74 + KAN-104.** `find_slots()` referenced the dropped `public.venue_opening_hours`; KAN-74 (`20260831130000`) corrects the reference to `opening_hours`/`day_group`. Separately, KAN-104/`T-044` found `is_booked` reads `false` for every anon/non-privileged-authenticated caller regardless of actual occupancy (RLS on `venue_bookings` denies those callers all rows, so `find_slots`'s internal EXISTS always finds none) — fixed by making `find_slots` `SECURITY DEFINER` (`20260901120000`, must apply after KAN-74, restates its body) plus `security_invoker = true` on this view. Both migrations authored, not yet applied |

**The condition that makes "access control lives inside the function" true — `T-070`, 2026-09-10.**
A function-backed public view is safe only while **every function in its call chain** derives
caller identity internally. **A caller-supplied identity parameter anywhere in that chain voids
the claim, and the view's own definition will not show it.**

`v_potential_vibes_default` met the claim; the 6-arg `rpc_potential_vibes` it reads does inject
`auth.uid()`. Behind that wrapper sat a **7-arg overload** taking `p_me uuid` from the caller,
`SECURITY DEFINER`, `EXECUTE` to `anon` — which returned **147 rows / 137 distinct users** to an
anonymous caller. It read as safe only because `spw.user_id <> NULL` is NULL for every row. The
row above is not being withdrawn: it was correct about the view. It was silent about the chain.

**Closed — `KAN-174`, 2026-09-11.** The 7-arg overload and `rpc_potential_vibes_debug` were
dropped in the same migration that folded the 7-arg's body into the 6-arg (identity now derived
exclusively from `auth.uid()`); the row above reflects that fixed state. The chain this section
warns about no longer has a caller-supplied-identity link in it.

**And the finding that generalises: `anon-allowlist-check.yml` cannot see this.** The gate checks
**views**; the exposure was a **function** two hops down, and the gate passed throughout.
Passing it is evidence about view grants and about nothing else. The gate is not broken and is
not being changed — it is bounded, and this is where that bound is recorded.

**Where the earlier guesses landed.** The old note guessed `v_comments`, `v_game_rating` and
`v_user_badges_summary` were "probably public". **One of three.** `v_comments` is public and
was also leaking one row; the other two had their `anon` grant revoked outright. That is the
case for the rule the note stated and did not follow — a guess about intent is not a verdict,
and two of these three would have been left open on a plausible-sounding hunch.

See `DECISIONS.md` `T-027` for the five views confirmed intentionally public, and §2d for the
reconciled aggregate counts.

**KAN-26 Part 1 re-verification, `backend-owner` 2026-09-01 — all 19 confirmed closed, no new
fix.** Re-ran the ticket's own enumeration query live. First pass used a buggy catalogue check
(`'security_invoker=true' = any(reloptions)` — wrong spelling; Postgres stores the reloption as
`security_invoker=on`) that produced false "still open" flags for `v_comments`, `v_circle_feed`,
`v_meetup_counts`, `v_user_reputation`, `v_notifications_feed`/`_ranked`. Caught before authoring
anything by reading raw `reloptions` and then empirically probing every candidate `as anon` (per
`T-020`/the memory lesson this ticket's own text is built on: an advisor or a catalogue flag is
not a verdict). All five actually carry `reloptions = {security_invoker=on}` live, and:
- `v_user_reputation`, `v_meetup_counts`: 0 rows to `anon`.
- `v_comments`: `permission denied for table profiles` to `anon` (fails closed — the LEFT JOIN
  profiles has no `anon` grant to fall back on; a robustness wart, not a leak). 66 rows to
  `authenticated`, matching this file's existing "67 → 66" count exactly.
- `v_circle_feed`: also `permission denied for table profiles` to `anon`, despite the view's own
  SELECT list never touching `profiles`. Traced to `circle_member_count(uuid)`: it is marked
  `SECURITY DEFINER` but is `LANGUAGE sql` and trivially simple, so Postgres's planner is free to
  **inline** it into the calling query — and an inlined SQL function does not run with the
  definer's privileges, it runs as whatever role executes the outer query. That is why its
  internal `profiles`-referencing subquery gets evaluated as `anon` and denied. Net effect today
  is safe (fails closed), but `SECURITY DEFINER` on `circle_member_count` is not reliably doing
  what its name promises — worth a future function-language fix (e.g. `plpgsql`, which is not
  planner-inlined), not urgent since nothing is currently exploitable. Not fixed in this
  migration; noted here for whoever next touches that function.
- `v_notifications_feed`/`_ranked`: notification-domain (table `notifications`) — out of
  `backend-owner`'s ownership per `CONTRACT.md`, not probed/fixed here, flagged directly to
  `notifications-specialist` and in the KAN-26 Jira comment.
- `v_potential_vibes_default`, `v_recreate_quickpicks`: `reloptions IS NULL` (documented no-op —
  function-backed, `security_invoker` governs table/view access inside the view and there is
  none to govern). 0 rows to `anon` for both, confirming the wrapped RPCs
  (`rpc_potential_vibes`, `rpc_recreate_suggestions`) gate on auth internally. Matches `T-027`.

No view/grant changes needed for Part 1 — every named view already carries a verdict, and this
sweep re-confirmed each one live rather than trusting the date on the existing table.

**Not a finding — PostGIS extension metadata:** `geography_columns`, `geometry_columns`.
They describe geometry columns, hold no application data, and are owned by the extension.
They are in the 19 by measurement and excluded from the work.

**Arithmetic, reconciled 2026-08-29: 19 exposed → 2 PostGIS → 17 app views needing a verdict.**
**All 17 are now closed or accounted for — updated 2026-08-29.** The last three
(`v_mod_queue_open`, `v_circle_feed`, `v_safety_overview`) closed under KAN-56 and are re-verified
as `anon` in the resolution note at the top of this section. **The history here is worth keeping:
this line first read "all 17 resolved" (wrong by three), was corrected to "3 remain open", and is
only now genuinely at zero — so read the date on it, not the claim.**
Current census, reconciled with §2d: **71 views · 28 invoker · 43 definer · 45 anon-readable**,
of which **five are confirmed intentional (`T-027`)** and the rest carry a stated position.
**The 45 anon-readable views are not 45 findings.**

### 2b. Definer + anon-granted — 8 views, **2 of which return rows**

**CORRECTED 2026-08-28. The previous version of this section was wrong and it was wrong in
the way this file keeps warning other people about: I classified these 8 by reading their
definitions for `auth.uid()` instead of querying them as `anon`.** Six are empty. Two are not.

| View | Rows to `anon` | Position |
|---|---:|---|
| `v_game_card` | **216** | Only `listing_visibility = 'public'` rows. Filter is the visibility column, **not** `auth.uid()` |
| `v_meetup_list` | **1** | Same — `listing_visibility = 'public'` only |
| `v_challenge_card` | 0 | Empty for `anon` |
| `v_hidden_list` | 0 | Empty for `anon` |
| `v_my_drafts` | 0 | Empty for `anon` |
| `v_my_games` | 0 | Empty for `anon` |
| `v_rateable_after_game` | 0 | Empty for `anon` |
| `v_recreate_candidates` | 0 | Empty for `anon` |

Control in the same transaction: `select count(*) from public.games` as `anon` returns **0**,
so the 216 rows from `v_game_card` are a genuine definer-view read over a table whose RLS
denies `anon` directly.

**These two are not in the same class as the §2a leaks and must not be filed with them.**
Every row they return is one the visibility model marks public, so this is consistent with
public game discovery without an account — plausibly the intended product behaviour. The
open question is the *columns*, not the rows: an unauthenticated caller gets
`creator_user_id` (the `auth.users` UUID), username, display name, avatar, exact start time
and venue. That is `SEC-15`, a **MED** privacy finding needing a PO decision, not a blocker.

`v_game_card` is also the live game path (`game_view_controller.dart:399`), so it cannot
simply be revoked.

**SEC-17 (KAN-87) closes the `creator_user_id` column exposure specifically.** `v_game_card`
deliberately stays anon-readable — that is the whole point of §2b — but it should expose
`creator_profile_id` (a `profiles.id`, opaque and already present in the view) and **not**
`creator_user_id` (a raw `auth.users` UUID, a durable cross-surface identifier for a real
person). The view's internal `is_creator`/ownership logic keeps comparing against
`creator_user_id` server-side via `auth.uid()` — only the column leaves the SELECT list, not
the authorization check. All Dart call sites were migrated to `creator_profile_id` 2026-08-30;
the column-drop migration is written but not yet applied — see the note in §2 above.

**SEC-17b (KAN-106) is the base-table version of SEC-17, and is larger.** `public.profiles`
hands `anon` its own `user_id` column directly — no view in front of it — via the
`profiles_select_public` policy (`USING (is_active = true)`, `polroles = NULL` i.e. PUBLIC)
combined with an `anon` column-`SELECT` grant on `user_id`. Measured 2026-09-01:
**154 distinct raw `auth.users` UUIDs**, six times SEC-17's 26. Same defect class, same
reasoning: `profiles` is deliberately public pre-login browsing surface (the row policy is
correct and untouched), the problem is one column. Fix is a column-level
`REVOKE SELECT (user_id) ON public.profiles FROM anon` —
`supabase/migrations/20260901100000_kan106_revoke_profiles_user_id_anon.sql`, authored,
**not yet applied**. `authenticated` keeps the column; every in-app Dart caller runs
authenticated (the router gates unauthenticated users to landing before any profile fetch),
so this is a no-op for real traffic. Full reachability sweep (Dart call sites, every view
selecting `user_id`, every anon-executable `SECURITY DEFINER` function returning it) is in
the migration file's header comment.

**Separate, more severe finding surfaced by that sweep, deliberately not folded into
KAN-106:** `public.whois(p_username)` is `SECURITY DEFINER`, carries no auth check at all,
is `EXECUTE`-granted to `anon`, and directly resolves any username to its raw `user_id` —
and it is not called anywhere in `lib/`, so it is live, reachable, and dead to the app at
the same time. A column-level `REVOKE` on `profiles.user_id` does not touch this: a definer
function reads with its own privileges, not the caller's grants. Several other
anon-executable definer functions (`rpc_search_users`, `rpc_get_friends`,
`rpc_get_friend_suggestions`, `rpc_friend_requests_inbox`/`_outbox`, `admin_whois_profile`; all but
`admin_whois_profile` dropped by KAN-941) also return `user_id` and were not individually audited for an auth gate here — this
overlaps the open "SECURITY DEFINER RPC census" (61 of 303 definer functions with no visible
auth check). Needs its own ticket; per the KAN-87/SEC-17 precedent this does not change
KAN-106's scope.

**Do not cite the old "safe by predicate" line.** Six of these are safe by *outcome*, two are
filtered by a *different* mechanism than the one this file claimed, and none of that was
knowable from the definition text.

### 2c. Anon-revoked — 23 views safe by grant

`any_user_id` · `v_admin_overview` · `v_any_author` · `v_autocomplete_debug_prefix` ·
`v_autocomplete_internal_checks` · `v_bench_status` · `v_frozen_users` ·
`v_host_weekly_metrics` · `v_moderation_metrics` · `v_needs_organiser` ·
`v_posts_integrity_violations` · `v_posts_time_preview` · `v_reliable_teammate_candidates` ·
`v_reputation_leaderboard` · `v_rewards_summary` · `v_sport_profiles_with_user` ·
`v_top_hosts_week` · `v_top_venue_lighting_by_district` · `v_user_balance` ·
`v_venue_balance` · `v_venue_dimension_by_district` · `v_wallet_admin_overview` ·
`v_wallet_balance`

Note the financial and admin views are correctly in this group.

### 2d. Invoker — 21 views at the 2026-08-27 census; **26 as of 2026-08-28**

**Updated after migration `20260828193807` (KAN-37).** Four views were flipped to
`security_invoker`: `v_notifications_feed`, `v_notifications_ranked`, `v_user_reputation`,
`v_meetup_counts`. **Then two more by `20260828194512` (KAN-38b):** `v_comments` and `v_post_comments`.
Census at end of 2026-08-28: **71 total · 28 invoker · 43 definer · 45 anon-readable** (was 48;
three SELECT revokes). Invoker = **6 flipped today** (written `security_invoker=on`) **+ 22
pre-existing** (`=true`) — if a report says "6 invoker views", that is the count changed today,
not the population. The list below is the 2026-08-27 set and includes none of the six.

**Bucket precedence, so the arithmetic reconciles.** A direct count of
`reloptions is not null` returns **22** explicit `security_invoker` views, not 21. The
difference is `v_rewards_summary`, which is *both* invoker **and** anon-revoked. **Each view
appears in exactly one bucket, and revocation is checked first** — a view `anon` cannot
select is safe by grant regardless of its invoker setting, so it is listed in §2c. Hence
22 invoker − 1 also-revoked = **21 here**, and the four buckets still sum to 71.

Precedence order: **anon-revoked → EXPOSED → definer+uid → invoker.**

`published_news` · `v_access_matrix` · `v_activity_inbox` · `v_actor_context` ·
`v_collection_vibes` · `v_location_suggestions` · `v_my_actors` · `v_people_search` ·
`v_potential_vibes_candidates` · `v_profile_editable` · `v_profile_public` ·
`v_profile_verification` · `v_public_collections` · `v_public_vibes` · `v_space_card` ·
`v_squad_card` · `v_squad_detail` · `v_unread_counts` · `v_user_badges_public` ·
`v_venue_rating` · `v_venues_with_sports`

### 2e. Regenerating this census

**CORRECTED 2026-08-28. The previous version of this query was wrong twice, and the second
error would have reported an applied fix as unapplied.**

```sql
select c.relname,
  case when coalesce((select option_value::boolean
                      from pg_options_to_table(c.reloptions)
                      where option_name = 'security_invoker'), false)
       then 'invoker' else 'DEFINER' end as mode,
  has_table_privilege('anon', c.oid, 'SELECT') as anon,
  (pg_get_viewdef(c.oid) ilike '%auth.uid()%') as uid_filter_TEXT_MATCH_ONLY
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'v' order by 1;
```

**What was wrong, both worth avoiding elsewhere:**

1. `case when c.reloptions is null then 'DEFINER' else 'invoker'` treats **any** reloption as
   invoker. A view carrying only `security_barrier=true`, or an explicit
   `security_invoker=false`, is definer and this called it invoker. It happened to give the
   right answer only because every non-null view here also set `security_invoker` truthy.
2. A variant used elsewhere tested `option_value = 'true'`. **Postgres accepts `on`, `true`,
   `yes` and `1` for a boolean reloption, and they are the same setting.** Migration
   `20260828193807` wrote `security_invoker=on`; every earlier view was written `=true`. The
   string test read the four newly-fixed views as still definer — **it would have reported a
   real remediation as not applied.** `option_value::boolean` parses all four spellings.

**The `uid_filter` column is a text match and is not evidence of anything** — see §2b, where
that exact instrument certified two leaking views as safe. Use it to decide what to probe,
never to decide what is safe.

**Do not substitute the Supabase advisor's `security_definer_view` count for this.** The
advisor returned 25; the real number is 49. An advisor reports what it flags, not what
exists — see §10.

**Rule going forward:** new views are created `security_invoker = true`.

### 2f. CI allowlist — machine-readable, drives KAN-61 / `T-002`

**This is the enforced list, not a summary of it.** `scripts/ci/check_anon_allowlist.sh`
parses the block below verbatim between the HTML comment markers and fails the build if any
view in `public` is `anon`-readable and lacks `security_invoker` and is not one of these
names. **Widening this list is how a PR shows up as a reviewable diff** — that is the
mechanism `T-002` describes, not a separate process.

Generated 2026-08-29 by re-running the §2e catalogue query live against `wtncuzcskpigqpmnxwws`
(not transcribed from the prose above, which the same re-run showed to be stale in three
places — `v_mod_queue_open`, `v_circle_feed` and `v_safety_overview` are no longer
anon-exposed at all). **`version-control` flagged this discrepancy rather than silently editing
§2a, which was the correct call — the generated block and the prose disagreed, and only one of
them is measured. Reconciled in prose by master-analyst 2026-08-29: §2a's three rows now read
CLOSED. This block is unchanged and remains the authority.**
Every name below was independently confirmed `anon`-readable with no
`security_invoker` at generation time:

* `geography_columns`, `geometry_columns` — PostGIS system views, allowlisted from the start
  per the KAN-61 ticket text, never a finding.
* `username_registry_public` — **removed from this allowlist by `KAN-141`**: the view and its
  backing `list_active_usernames()` were dropped. `T-027`'s justification for it was based on
  an inaccurate description of the object (see §2a) and needs formal supersession by `cto`.
  The other two `T-027` entries below are unaffected.
* `v_potential_vibes_default`, `v_recreate_quickpicks` — intentionally public, `T-027`,
  function-backed (`security_invoker` is a no-op on these; access control lives in the
  function).
* `v_challenge_card`, `v_my_games`, `v_rateable_after_game`, `v_recreate_candidates` — §2b,
  0 rows to `anon` at last measurement, but still carry the grant.
* `v_game_card`, `v_meetup_list` — §2b, return rows but only `listing_visibility = 'public'`
  ones; open privacy question is the columns (`SEC-15`), not the rows, and is a PO call, not
  a CI-gate call.
* `v_space_slots_today` — `BUG-05`, errors for every role including `postgres`; not a
  security finding.
* `kan718_games_compat`, `kan718_meetups_compat` — `KAN-773` (KAN-718 D05) compatibility
  projections owned by `postgres`, `security_barrier`, restating the legacy tables' row
  security in the view (API roles have no SELECT on `events`). Measured live 2026-11-13 as
  `anon`: `kan718_games_compat` 0 rows (= `games`), `kan718_meetups_compat` 32 rows (= the 32
  `meetups` rows `anon` sees through `meetups_select_visible`). Same visibility as the tables
  they stand in for; nothing newly exposed.

**Adding a name here without one of these justifications is exactly the review conversation
`T-002` exists to force — don't add one to make the gate pass without checking why it is
newly anon-readable.**

<!-- ANON_ALLOWLIST_START -->
geography_columns
geometry_columns
v_space_slots_today
<!-- ANON_ALLOWLIST_END -->

### 2g. CI function allowlist — machine-readable, drives KAN-175

**A SEPARATE BLOCK FROM §2f, and deliberately so.** §2f holds VIEW names and is parsed by
`scripts/ci/check_anon_allowlist.sh`, whose SQL reads `WHERE c.relkind = 'v'`. Widening it to
hold function signatures would break that parser. This block holds FUNCTION SIGNATURES and is
parsed by `scripts/ci/check_anon_function_grants.sh`. Two object classes, two gates, two lists.

**Why this block exists.** The KAN-61 view gate has no `pg_proc`, `proacl` or `EXECUTE`
coverage anywhere in it. A `SECURITY DEFINER` function that `anon` can call was therefore
outside every control the project had, and the gate ran green throughout the live window of
the exposure it was meant to catch. The control and the exposure sat on different Postgres
object classes.

**What the gate fails on.** Not "is `SECURITY DEFINER`" and not "is anon-executable" — those
are **303** and **1,746** functions respectively (of 1,761 in `public`; their intersection is
290), reported as a census on every run and never failing, because an allowlist nobody can
maintain goes green by exhaustion.

> Those four figures were measured against `wtncuzcskpigqpmnxwws` on **2026-09-10** by
> `backend-5`. They are reproducible — the gate prints them live on every run, and the same
> numbers come from `anon_function_census_sql()` in `scripts/ci/anon_function_grants_diff.sh`:
>
> ```sql
> SELECT count(*)                                                    AS all_functions,
>        count(*) FILTER (WHERE p.prosecdef)                          AS security_definer,
>        count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE'))
>                                                                     AS anon_executable,
>        count(*) FILTER (WHERE p.prosecdef
>                     AND has_function_privilege('anon', p.oid, 'EXECUTE')) AS both
>   FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
>  WHERE n.nspname = 'public' AND p.prokind = 'f';
> ```
>
> **Prefer the gate's own printed census to this paragraph.** These numbers drift; the
> command does not. (Corrected 2026-09-10: this said "303 and 292", attributing the `both`
> count to the anon-executable bullet and understating that population ~6×.)
>
> **`303 / 1,746 / 290` were independently measured twice** — by `backend-5` and by
> `backend-7`, separately, on 2026-09-10, agreeing exactly. **The `1,761` total-functions
> denominator rests on `backend-5`'s reading alone** and has never been reproduced: the
> Supabase token expired before `backend-7` could check it. Re-verify that one figure when
> database access returns. It is the only number here with a single source, and this section
> exists because an unchecked number sat in it for weeks.

It fails on the narrow
intersection: **`SECURITY DEFINER`, effectively executable by `anon`, taking a uuid argument
whose name denotes a PERSON, whose body never COMPARES that argument to `auth.uid()`.** That
is a function which lets an unauthenticated caller choose whose data to act on while running
with its owner's privileges. Measured 74 live on 2026-09-10.

**Three things the predicate deliberately does not do**, each because a weaker version was
demonstrated failing against fabricated cases in `check_anon_function_grants_test.sh`:

* **It never text-matches `proacl` for `anon`.** A bare `=X/postgres` entry is a grant to
  `PUBLIC` that `anon` inherits, so a function whose ACL never names `anon` is still callable
  by it. 60 of the 292 definer+anon functions (2026-09-10 reading; 290 later that day) are
  reachable only that way. `has_function_privilege` is required.
* **It requires a COMPARISON to `auth.uid()`, not a mention.** Of the functions carrying an
  identity argument (76 at the first 2026-09-10 reading, 74 after two were contained), 47
  mentioned `auth.uid()` and only **2** compared the argument to it. The
  common shape is `v := COALESCE(p_user_id, auth.uid())`, which reads as authentication and is
  not — supply any uuid and you win. `rpc_get_friends(p_user_id uuid)` does exactly this today.
* **It does not require a same-named overload.** An earlier draft did, on the
  `rpc_potential_vibes` wrapper/implementation shape. `rpc_get_friend_suggestions` has no
  overload and is the worst instance found, so that requirement made the gate blind to it.

Also note `DEFAULT auth.uid()` on a parameter is **decoration, not mitigation** — a default
applies only when the caller omits the argument. It lives in `pg_get_function_arguments()`,
never in `prosrc`, so testing the body ignores it automatically.

**THIS LIST IS A MEASURED BASELINE OF EXISTING DEBT, NOT A CERTIFICATE OF SAFETY.** Every
signature below was flagged by the predicate on 2026-09-10 and is recorded so the gate can
detect the 75th. Several are plainly alarming on their face — `admin_cleanup_user_data`,
`rpc_admin_freeze_user`, `admin_take_action`, `request_payout`, `set_session_user`,
`is_admin(p_user uuid)` — and **nothing here says they are acceptable**. Triaging them is
separate work; freezing the population so it cannot silently grow is this gate's job.
**Removing a name from this list by fixing the function is always the preferred direction.**

**The live set may be SMALLER than this list, and that is not a failure.** The diff is
one-directional by design (`comm -23 live allowlist`), matching §2f: a signature that leaves
the flagged set because someone fixed the function is a stale entry to tidy, never a red build.
Verified 2026-09-10 by `backend-5`: `create_system_post` and `process_notification_event` were
contained by `REVOKE` after this baseline was taken — both now resolve
`has_function_privilege('anon', …)` false — so 72 of the 74 below are live and the gate is
correctly green. That is the preferred direction stated above, actually happening.

#### §2g.1 — EXECUTE containment applied 2026-09-10: the full set of seven, five of which were recorded nowhere

**Five of the seven revokes applied to production on 2026-09-10 existed only in a session
transcript.** `create_system_post` and `process_notification_event` were recorded (the paragraph
above); the rest were not — no migration, no `SCHEMA.md` entry, no `DECISIONS.md` entry named them.
Found by `devops` while reconstructing why the gate's flagged count moved **72 → 70**; it could
narrow the two departing signatures by elimination but could not corroborate either from the repo.
This block closes that gap.

| Function | Resulting EXECUTE holders | Why narrowed |
|---|---|---|
| `settle_game` | `postgres`, `service_role` | Money write; `T-069` — no trusted amount source, organiser/sport/gross derived, not parameters |
| `rpc_potential_vibes` (bare, 7-arg) | `postgres`, `service_role` | `T-070` — the identity parameter is the whole vulnerability; the 7-arg *is* the implementation |
| `create_system_post` | `postgres`, `service_role` | Caller-supplied `p_profile_id` — post authorship forgeable. **Already recorded** |
| `process_notification_event` | `postgres`, `authenticated`, `service_role` | `anon` had no business reaching it. **Already recorded** |
| `set_session_user` | `postgres`, `service_role` | Session-identity setter reachable by `anon`; named in the "plainly alarming" list above |
| `rpc_remove_player` | `anon` removed, `authenticated` retained | Roster mutation by an unauthenticated caller |
| `rpc_decide_join_request` | `anon` removed, `authenticated` retained | Join-request adjudication by an unauthenticated caller |

Plus the **`content_hits_blocklist(text, text)` bundle (KAN-68)**: revoked from `PUBLIC`, `anon` and
`authenticated`; re-granted `authenticated` and `service_role`. Recorded here because the `PUBLIC`
revoke is the load-bearing half — see the next paragraph.

**Verification of any row above uses `has_function_privilege`, never a `proacl` text match** — the
reason is already stated once at §2g and is not restated here: a bare `=X/postgres` entry is a grant
to `PUBLIC` that `anon` inherits without ever being named. A `REVOKE … FROM anon, authenticated` that
leaves the `PUBLIC` grant standing looks like containment and is not. That nearly happened once on
2026-09-10.

**Status: applied 2026-09-10; resulting `proacl` as reported by the applying seat, PENDING LIVE
RE-READ.** The Supabase MCP has been disconnected since `T-077` Amendment 1 and `T-068` makes the repo
authoritative for nothing about what ran. **None of these seven is confirmed current state.** They are
on the `T-077` owed-on-reconnect list.

**Live re-read, 2026-11-24 (`KAN-1038`, `backend-3`), `has_function_privilege` on `wtncuzcskpigqpmnxwws`:** none of the
rows above is anon-executable today. `settle_game(uuid, boolean)`, `create_system_post`, `process_notification_event` and
`set_session_user` are executable by neither `anon` nor `authenticated`. `rpc_remove_player(uuid, uuid, text, text)`,
`rpc_decide_join_request(uuid, boolean)` and `content_hits_blocklist(text, text)` are `authenticated` only. The 7-arg
`rpc_potential_vibes` no longer exists; the remaining 6-arg wrapper is still anon-executable and has no identity argument.

**`KAN-1038` (SEC-8), 2026-11-24, migration `20261124183000_kan1038_sec8_definer_fixes`:** `PUBLIC` and `anon` revoked
(`authenticated` kept) on `admin_actor`, `admin_approve_payout`, `admin_assert_posts_integrity`, `admin_cancel_payout`,
`admin_cleanup_user_data`, `admin_force_delete_auth_user`, `admin_is_hidden`, `admin_mark_payout_paid`,
`admin_mark_payout_processing`, `admin_overview_row`, `admin_resolve_report`, `admin_take_action`,
`rpc_admin_submission_action_state`, `rpc_submission_approval_state`, `rpc_submission_audit_timeline` and
`upsert_area_from_mapbox`. `_debug_can_view`, `_whoami_definer`, `effective_actor_uid_debug`: service_role only.
`rpc_expire_freezes`: service_role only. `rpc_toggle_post_vibe` dropped (its table `post_vibes` is gone).
`rpc_squad_request_join` now raises 42501 unless `p_profile_id` is the caller's profile. **Kept anon on purpose:**
`admin_override()` and `can_review_venue_submission(uuid)`, because RLS policies with role PUBLIC on `challenges`,
`demo_content` and `venue_submissions` call them, and an anon read of those tables would fail with 42501 without them.
The allowlist below was pruned to the 17 signatures still anon-executable on that date.

**Why this record is load-bearing and not bookkeeping.** A revoke that exists in no artefact is one
`DROP` + `CREATE` away from being silently undone, because a recreated function re-derives its grants
from `pg_default_acl`. `T-045` closed the **`postgres` default-privilege rule for tables**; whether
the **function** default in `public` still carries `anon=X` is **not settled by `T-045` and not
repo-determinable**. If it does, all seven revokes are permanently fragile and every future
`CREATE FUNCTION` in `public` re-opens the same hole. **That is work, not a record** — see
`DECISIONS.md` `T-078`.

**`T-078` answered, `KAN-189`/`KAN-194`, 2026-09-11 — the function default DID exist, on BOTH
channels, and is now closed for `postgres`.** `pg_default_acl` for schema `public`,
`defaclobjtype='f'`, checked live:

* **`postgres` grantor — FIXED.** Two channels, not one, and closing only the first was proven
  live to be insufficient (`KAN-189`): the NAMED default (`postgres=X, anon=X, authenticated=X,
  service_role=X` in the schema-scoped row) was revoked (`ALTER DEFAULT PRIVILEGES FOR ROLE
  postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon`, ledger `20260911133843`), and
  PostgreSQL's own built-in **global** EXECUTE-to-PUBLIC default on new functions — separate from
  and layered on top of any per-schema entry, and NOT removable by a schema-scoped revoke — was
  separately revoked (`ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM
  PUBLIC`, no `IN SCHEMA` clause, ledger `20260911163938`). Both re-confirmed live on `KAN-194`'s
  own re-read (2026-09-11, after `KAN-189` landed): `postgres`'s schema-scoped row is now
  `{postgres=X, authenticated=X, service_role=X}` — no `anon`, no bare `PUBLIC` — and a fresh
  disposable probe function created by `postgres` carries exactly that ACL, confirmed twice
  independently (`KAN-189`'s own close, and again on `KAN-194`'s re-read). Existing functions'
  explicit grants are unaffected — default-privilege changes are forward-only.
* **`supabase_admin` grantor — UNCHANGED, OUT OF SCOPE, NOT FIXED.** `T-045`'s role split reserves
  this for its own ruling; neither `KAN-189` nor `KAN-194` had authority to touch it, and neither
  did. Its schema-scoped row is unchanged: `{postgres=X, anon=X, authenticated=X, service_role=X}/
  supabase_admin`. It also carries no global-scope (`defaclnamespace=0`) override, meaning
  PostgreSQL's built-in global PUBLIC-EXECUTE default is inferred still active for it too — **this
  is a catalogue inference, not a live-probe proof**: the reading role (`postgres`) cannot `SET
  ROLE supabase_admin` in this environment (`pg_has_role(...) = false`), so a function created BY
  `supabase_admin` was never actually created to test it. **Do not read this row as fixed.** A
  function created by `supabase_admin` today would still inherit `anon` EXECUTE on both channels.

**Do not describe the function-default hole as fully closed.** It is closed for the `postgres`
grantor only. Whatever creates functions as `supabase_admin` remains exposed until a future ticket
with its own authorized ruling addresses that half.

**KAN-497 baseline note (2026-10-13, AUTHORED, NOT APPLIED).** Five allowlisted functions below are the
subject of an authored-only change: `is_blocked(user_a uuid, user_b uuid)`, `rpc_block_user(p_peer uuid)`,
`rpc_block_user(p_peer uuid, p_block boolean)`, `rpc_unblock_user(p_peer uuid)` and
`rpc_unfollow_user(p_target_profile_id uuid)`. State per the KAN-496 live check of 2026-10-13: each is
`SECURITY DEFINER`, holds a `PUBLIC` grant **and** an explicit `anon` grant, so `anon` can execute all five
(`is_blocked` was a disclosure: anyone with the anon key could ask whether one user blocked another).
Authored fix, not applied anywhere: `supabase/migrations/20261013100000_kan497_is_blocked_narrow_to_caller.sql`
(answers only for the caller's own pairs) and, later, `20261013110000_kan497_revoke_anon_block_rpcs.sql`
(revokes `PUBLIC` and `anon` on the four RPCs; `is_blocked` is held back because anon-reachable invoker
callers need it). Caller map, probes, rollback and the held decision: `supabase/tests/anon_block_grants/`.
**This block below is unchanged.** If the revoke is applied, the four RPC lines become stale; the gate does
not fail on a stale line, and removing them is a separate change.

**KAN-499 baseline note (2026-10-13, AUTHORED, NOT APPLIED).** `rpc_block_user(p_peer uuid, p_block boolean)` (listed in
the block below) is the second block entry point: it writes `restrictions` (`type = 'blocked'`), a store that nothing reads, while
the app and the 1-argument `rpc_block_user(p_peer uuid)` use `user_blocks`. The app never calls the 2-argument form. Authored fix,
not applied anywhere: `supabase/migrations/20261013120000_kan499_collapse_rpc_block_user_overload.sql` renames it to
`rpc_block_user_legacy_v1`, revokes ALL from `PUBLIC`, `anon` and `authenticated`, and copies `restrictions` `blocked` rows into
`user_blocks` (no DROP, nothing written to `restrictions`). It is written to apply after KAN-497's two migrations. Caller map,
probes, rollback and the residual finding (`rpc_restrict_set`/`rpc_restrict_clear` still accept `'blocked'`):
`supabase/tests/block_overload_collapse/`. **This block below is unchanged.** If the migration is applied, the
`rpc_block_user(p_peer uuid, p_block boolean)` line becomes stale; the gate does not fail on a stale line, and removing it is a
separate change.

**Adding a name here needs a written justification in the PR**, exactly as §2f requires — that
reviewable diff is the whole mechanism. Do not add one to make the gate pass without
establishing why a new function needs an unguarded caller-supplied identity.

<!-- ANON_FUNCTION_ALLOWLIST_START -->
audit_log(p_action text, p_target_type mod_target, p_target_id uuid, p_target_user_id uuid, p_meta jsonb)
can_review_venue_submission(p_user_id uuid)
can_view_circle(p_circle_id uuid, p_profile_id uuid)
can_view_post(p_post_id uuid, p_user_id uuid, p_profile_id uuid)
is_blocked(user_a uuid, user_b uuid)
is_circle_member(p_circle_id uuid, p_user_id uuid)
is_frozen(p_user uuid)
is_post_owner(p_post_id uuid, p_profile_id uuid)
perform_check_in(p_user_id uuid, p_device_info jsonb)
request_payout(p_amount_aed numeric, p_beneficiary_id uuid)
respond_vibe_request(p_other_user uuid, p_action text)
rpc_feed_ranked(p_scope text, p_author_user_id uuid, p_sport text, p_lat double precision, p_lng double precision, p_radius_km numeric, p_since timestamp with time zone, p_limit integer)
rpc_is_following_user(p_target_profile_id uuid)
send_vibe_request(p_to_user uuid)
set_hidden_mode(p_target_user uuid, p_enable boolean, p_reason text)
switch_active_profile(p_profile_id uuid)
unsync(p_other_user uuid)
<!-- ANON_FUNCTION_ALLOWLIST_END -->

## 3. STORAGE BUCKETS — 4

| Bucket | Public | SELECT | INSERT | UPDATE | DELETE | State |
|---|:--:|:--:|:--:|:--:|:--:|---|
| `Avatar` | yes | 1 | 1 | 1 | 1 | Healthy |
| `post-media` | yes | 1 | 1 | 1 | 1 | Healthy |
| `dabbler-news` | yes | **0** | 1 | 0 | 0 | **Broken read-back** |
| `venue` | yes | **0** | **0** | 0 | 0 | **No policies at all — uploads impossible** |

**The SELECT-for-read-back rule.** An upload is not a write-only operation: the client reads
the object back after writing it. A bucket with INSERT and no SELECT produces an upload that
appears to fail or a broken image, with no error at the write. This is a recurring bug class
in this project — grant for the whole round trip, not for the verb in the function name.

**Bucket names in code that do not exist:**

| Code | Names | Reality |
|---|---|---|
| `lib/core/config/supabase_config.dart:4` | `venueImagesBucket = 'venue-images'` | **No such bucket.** Real name is `venue` |
| `lib/features/profile/data/datasources/supabase_profile_datasource.dart:16` | `_avatarBucket = 'avatars'` | **No such bucket.** Real name is `Avatar`, already correct in `SupabaseConfig.avatarsBucket` |

Both sit in dead code paths today, which makes them traps rather than outages. KAN-27.

---

## 4. RPCs — FIVE GENERATIONS OF `nearby`

The proximity search has been rewritten five times and **every generation is still
callable.** Nothing was dropped. An agent picking by name alone will pick wrong.

| Gen | Functions | Signature shape | Status |
|---|---|---|---|
| 1 | `getnearbygames`, `getnearbyvenues`, `getnearbymeetups` | `(p_lat, p_lng, p_radius double)` | **Legacy** — no underscores, no filters |
| 2 | `get_nearby_games` ×2, `get_nearby_venues`, `get_nearby_posts`, `get_nearby_profiles` | `(p_lat, p_lng, p_radius)` — `get_nearby_games` exists as **both** `integer` and `double precision` overloads | **Legacy** |
| 3 | `nearby_games`, `nearby_venues`, `nearby_posts` | `(p_lat, p_lng, p_radius int, p_sport, p_limit, p_offset)` | **Legacy** |
| 4 | `rpc_get_nearby_games`, `rpc_get_nearby_venues` | `(p_lat, p_lng, p_radius_meters int, p_sport_id uuid, p_sort text)` | **CURRENT** — matches the `rpc_` convention, takes `sport_id` not a text key, supports sort |
| — | `geo_nearby_venues` | `(in_lat, in_lng, in_radius_m, in_limit, in_offset)` | Separate lineage, `in_` prefix |
| — | `rpc_nearby_users` | `(p_lat, p_lng, p_delta, p_limit)` | Uses a bounding delta, not a radius |

**Use generation 4.** Do not add a sixth.

### Which generation each caller actually uses — measured 2026-08-27

Callers extracted with a **multiline-safe** parse (`\.rpc\(\s*'name'`). A single-line grep
misses these: the RPC name sits on the line *after* `.rpc(` throughout this codebase.

| RPC | Gen | Called from | Reachable? |
|---|:--:|---|---|
| `rpc_get_nearby_games` | **4** | `features/games/data/datasources/nearby_games_datasource.dart` | **LIVE** → `games_screen.dart` (routed, `app_router.dart:51`) |
| `rpc_get_nearby_venues` | **4** | `features/venues/data/datasources/nearby_venues_datasource.dart` | **LIVE** → `venues_screen.dart` (routed, `app_router.dart:55`) |
| `get_nearby_games` | 2 | `data/repositories/nearby_games_repository_impl.dart` · `features/games/data/datasources/supabase_games_datasource.dart` | **DEAD** — consumers are `explore_nearby_screen.dart` (orphan) and the dead games stack |
| `get_nearby_venues` | 2 | same, plus `features/games/data/datasources/venues_datasource.dart` | **DEAD** on the `nearby_games_repository_impl` path |
| `get_nearby_posts` | 2 | `nearby_games_repository_impl.dart` · **`data/repositories/feed_repository_impl.dart`** | **feed path is LIVE** — reached via `explore/providers/feed_providers.dart` |
| `get_nearby_profiles` | 2 | `nearby_games_repository_impl.dart` | **DEAD** |
| `geo_nearby_venues` | — | `data/repositories/geo_repository_impl.dart` | **LIVE** — reached via `core/providers/geo_providers.dart` |
| gen 1 (`getnearbygames`, `getnearbyvenues`, `getnearbymeetups`) | 1 | **nothing in `lib/`** | **DEAD — no caller at all** |
| gen 3 (`nearby_games`, `nearby_venues`, `nearby_posts`) | 3 | **nothing in `lib/`** | **DEAD — no caller at all** |
| `rpc_nearby_users` | — | nothing in `lib/` | **DEAD — no caller** |

**Safe to drop after a caller re-check: generations 1 and 3, and `rpc_nearby_users`** —
nine functions with zero references in the client. Generation 2 cannot be dropped wholesale:
`get_nearby_posts` and `geo_nearby_venues` are both on live paths.

### Two hazards in this area

**1. `get_nearby_games` has two overloads** — `p_radius integer` and `p_radius double
precision`. `nearby_games_repository_impl.dart` passes a Dart `num` as `p_radius`, so which
overload resolves depends on the serialised JSON type. Anything relying on it is relying on
an accident. Another reason to finish moving to generation 4.

**2. Generation 2 calls bypass `SupabaseConfig`.** `nearby_games_repository_impl.dart` calls
`'get_nearby_games'`, `'get_nearby_venues'`, `'get_nearby_posts'`, `'get_nearby_profiles'`
as **string literals** — a violation of `MANIFESTO.md` R3, which the audit measured at 0
violations for tables and buckets but did not check for RPCs. `SupabaseConfig` declares
`getNearbyVenuesFunction = 'get_nearby_venues'` (line 24) and **nothing uses it.**

### The name collision worth knowing about

`nearbyGamesProvider` is declared **three times** and `nearbyVenuesProvider` **three times**:

| Provider | Declared at | Generation |
|---|---|:--:|
| `nearbyGamesProvider` | `features/games/presentation/providers/nearby_games_provider.dart:125` | **4 — live** |
| `nearbyGamesProvider` | `features/explore/providers/nearby_games_providers.dart:62` | 2 |
| `nearbyGamesProvider` | `features/games/providers/games_providers.dart:190` | dead stack |
| `nearbyVenuesProvider` | `features/venues/presentation/providers/nearby_venues_provider.dart:70` | **4 — live** |
| `nearbyVenuesProvider` | `features/explore/providers/nearby_games_providers.dart:76` | 2 |
| `nearbyVenuesProvider` | `features/games/providers/games_providers.dart:319` | dead stack |

Live code already works around this: `games_screen.dart:17` and `venues_screen.dart:21` both
import `package:dabbler/providers.dart` **`hide nearbyGamesProvider`** / **`hide
nearbyVenuesProvider`** to stop the export hub's version shadowing the one they want.

**A `hide` clause in a screen import is a symptom, not a style choice.** Anyone adding a
nearby feature will import the wrong one by default, because the export hub gives them
generation 2.

### Other duplicated RPCs

Several functions exist as multiple overloads that are not obviously versions of each other.
Check the signature, not just the name:

`is_admin()` and `is_admin(p_user uuid)` · `rpc_block_user(p_peer)` and
`rpc_block_user(p_peer, p_block boolean)` · `rpc_get_friends()` and
`rpc_get_friends(p_user_id)` · `rpc_hide_user(target_user)` and
`rpc_hide_user(p_peer, p_hide)` · `rpc_meetup_create` ×2 (a 4-arg and an 14-arg form) ·
`rpc_meetup_rsvp` ×2 ·
`rpc_squad_respond_invite` ×2 (`p_action` vs `p_decision`)

Also near-duplicates by name: `rpc_admin_revoke_venue` and
`rpc_admin_revoke_venue_submission`; `rpc_freeze_user` / `rpc_admin_freeze_user` and
`rpc_unfreeze_user` / `rpc_admin_unfreeze_user`.

### RPC families (~180 total)

**Games:** `rpc_create_game` (23 params), `rpc_update_game`, `rpc_cancel_game`,
`rpc_reschedule_game`, `rpc_join_game`, `rpc_leave_game`, `rpc_remove_player`,
`rpc_decide_join_request`, `rpc_invite_user`, `rpc_mint_join_link`, `rpc_recreate_from_game`,
`rpc_recreate_suggestions`
**Meetups:** `rpc_create_meetup`, `rpc_meetup_rsvp`, `rpc_meetup_cancel`,
`rpc_meetup_attendees`, `rpc_meetup_card`, `rpc_meetup_mint_link`, `rpc_meetup_my`,
`rpc_meetup_invite_user`, `rpc_meetup_set_attendee`, `rpc_meetup_unrsvp`
**Social:** `rpc_create_post`, `rpc_delete_post`, `rpc_add_comment`, `rpc_toggle_like`,
`rpc_repost_post`, `rpc_hide_post`, `rpc_report_post`, `rpc_feed_ranked`,
`rpc_toggle_post_vibe`, `rpc_set_post_primary_vibe`
**Friends:** none. There is no friendship relation; "friends" is a mutual follow on `profile_follows`
(`are_synced`, KAN-931). Blocking is `rpc_block_user(p_peer)` / `rpc_unblock_user(p_peer)` on `user_blocks`.
**Dropped (KAN-931, KAN-941).** KAN-931: `rpc_search_entities`, `rpc_meetup_visible` (no caller; raised on
every call). KAN-941 (`20261113231811_kan941_post_friend_functions`): `rpc_search_posts`, `rpc_trending_posts`
(read the absent `v_post_discovery`), `rpc_search_users`, `v_activity_inbox()`, `rpc_friend_request_send`,
`rpc_friend_request_accept`, `rpc_friend_request_reject`, `rpc_friend_remove`, `rpc_friend_unfriend`,
`rpc_get_friends()`, `rpc_get_friendship_status`, `rpc_get_friend_suggestions`, `rpc_friend_requests_inbox`,
`rpc_friend_requests_outbox` (read the absent `public.friendships`; no reachable caller). KAN-941 re-authored:
`rpc_block_user(p_peer)` no longer touches `friendships` (inserts `user_blocks`, removes `profile_follows` both
ways); `can_view_post(p_viewer uuid, p_post posts)` decides `circle` by delegating to
`can_view_post(p_post_id, p_user_id, p_profile_id)`, the `posts_select_policy` function (`post_circles`
membership: private circle member, followers-circle follower of the owner, or public circle), so the two
overloads cannot disagree; a mutual follower outside the circle sees the post through neither.
**Squads & challenges:** `rpc_squad_create`, `rpc_create_squad`, `rpc_squad_add_member`,
`rpc_squad_invite`, `rpc_squad_request_join`, `rpc_squad_respond_invite`,
`rpc_squad_set_captain`, `rpc_squad_remove_member`, `rpc_challenge_create`,
`rpc_challenge_add_squad`, `rpc_challenge_generate_fixtures`, `rpc_challenge_record_result`,
`rpc_challenge_spawn_game`, `rpc_challenge_invite_squad`, `rpc_challenge_respond_invite`,
`rpc_challenge_set_status`
**Identity:** `rpc_create_profile`, `rpc_ensure_profile`, `rpc_onboard_profile`,
`rpc_profile_update_basic`, `rpc_profile_search`, `rpc_act_as`, `rpc_set_actor`,
`rpc_post_as`, `rpc_create_sport_profile`, `rpc_verify_profile`, `rpc_unverify_profile`
**Usernames:** `rpc_username_availability`, `rpc_username_claim`, `rpc_username_release`,
`rpc_username_suggest`, `rpc_ban_username`, `rpc_ban_display_name` *(`list_active_usernames`
dropped by `KAN-141`)*
**Moderation:** `rpc_flag_content`, `rpc_report_rating`, `rpc_review_report`,
`rpc_moderation_take_ticket`, `rpc_moderation_resolve_ticket`, `rpc_admin_hide_post`,
`rpc_shadow_hide`, `rpc_shadow_unhide`, `rpc_takedown`, `rpc_freeze_user`,
`rpc_admin_freeze_user`, `rpc_expire_freezes`, `rpc_ban_term_upsert`, `rpc_restrict_set/clear`
**Venue submissions:** `rpc_submit_venue_submission`, `rpc_admin_approve_venue_submission`,
`rpc_admin_reject_venue_submission`, `rpc_admin_return_venue_submission`,
`rpc_admin_revoke_venue_submission`, `rpc_submission_approval_state`,
`rpc_submission_audit_timeline`, `rpc_admin_submission_action_state`,
`rpc_my_venue_permissions`
**Bookings:** `rpc_booking_hold_for_game`, `rpc_booking_hold_for_meetup`, `rpc_booking_cancel`
**Ratings:** `rpc_rate_game`, `rpc_rate_user`, `rpc_rate_venue`
**Drafts:** `rpc_draft_create/update/archive`, `rpc_draft_publish_game/meetup/challenge`
**Search:** `rpc_unified_search_sectioned`,
`rpc_autocomplete_entities`, `rpc_autocomplete_people`
**Notifications:** `rpc_mark_all_read`, `rpc_notification_clicked`,
`rpc_broadcast_inapp_notification`
**Bench mode:** `rpc_toggle_bench`, `rpc_end_bench`, `rpc_get_my_status`
**Misc:** `rpc_track_event`, `rpc_get_activity_feed`, `rpc_circle_list`,
`rpc_rewards_apply_event`, `rpc_test_ping`

---

## 5. TRIGGERS — ~200

Grouped by what they do. The ones carrying business rules are the ones to know about.

**Auth / account creation**
- `trg_strip_signup_password` on `auth.users` → `strip_signup_password()` — **forces
  `encrypted_password` NULL on every insert.** This is decision 002; a NULL password is
  correct, not a bug.
- `trg_create_default_privacy_settings` on `auth.users`
- `trg_user_created` on `profiles` → `handle_user_created`
- `trg_welcome_notify` on `profiles`
- `trg_set_default_avatar` on `profiles`

**Geo inheritance** — a row's location is derived, not supplied
- `trg_games_inherit_geo`, `trg_games_inherit_venue_geo`, `trg_meetups_inherit_geo`
- `trg_games_sync_geo`, `trg_meetups_sync_geo`, `trg_venues_sync_geo`,
  `trg_profile_locations_sync_geo` — all → `fn_sync_geo_fields`
- `trg_posts_set_geo` on `posts`
- `trg_set_geohash` on `geo_locations` → `set_geohash_before_insert`
- `trg_normalize_area_location` on `areas` → `fn_normalize_area_location`

**Notification fan-out** — this is why the notification system works without app-side polling
- `trg_push_on_notification_insert` on `notifications` — fires the push edge function
- `trg_friend_request_notify`, `trg_game_invite_notify`, `trg_game_join_request_notify`,
  `trg_game_updated_notify`, `trg_game_waitlist_promoted_notify`, `trg_squad_invite_notify`,
  `trg_meetup_invite_notify`, `trg_circle_join_notify`, `trg_post_comment_notify`,
  `trg_post_mention_notify`, `trg_comment_mention_notify`, `trg_post_reaction_notify`,
  `trg_profile_follow_notify`, `trg_badge_awarded_notify`, `tr_likes_notify`,
  `tr_public_activities_notify`, `trg_notify_admins_of_report`, `trg_notify_admins_of_block`

**Activity feed sync** — `tr_*_activity_sync` on `posts`, `comments`, `reactions`,
`post_reposts`, `games`, `game_roster`, `meetups`, `meetup_rsvps`, `news`, `profile_follows`,
`user_badges`; plus `tr_feed_items_fanout` and `tr_activity_log_sync` on `public_activities`

**Freeze / safety guards** — block writes from frozen users
- On `games`, `game_roster`, `game_waitlist`, `game_invites`, `game_join_requests`
- **Note the ordering-hack prefixes:** `trg_90_waitlist_block_frozen` and
  `trg_zz_waitlist_block_frozen`, `trg_zz_invite_recipient_not_frozen`. Postgres fires
  triggers in name order, so `90_` and `zz_` are being used to force these last. That is a
  real constraint: **renaming one of these changes when it fires.**

**Profile field guards** — reject updates to fields the client must not change:
`trg_block_profile_type_updates`, `trg_block_profile_verified_updates`,
`trg_block_profile_skill_level_updates`, `trg_block_legacy_persona_updates`,
`trg_limit_active_profiles`, `trg_validate_persona_compatibility`

**Denormalisation / counters** — `trg_comment_counter`, `trg_repost_count`,
`trg_increment_view`, `trg_hashtag_usage`, `trg_reaction_insert/update/delete` →
`sync_reaction_breakdown`, plus `trg_post_reaction_breakdown`

**Search vectors** — `*_search_tsv` on `posts`, `comments`, `games`, `meetups`, `squads`,
`venues`, `profiles`, `hashtags`, `challenges`

**Sport-profile derived stats** — `trg_update_sport_profiles_xp`,
`trg_update_sport_profiles_form`, `trg_update_sport_profiles_reliability`,
`trg_update_overall_level`, `trg_assign_sport_profile_tier`, `trg_sport_profiles_level_event`

**`sport_id` backfill** — `trgfn_set_*_sport_id` on `posts`, `badges`, `squads`,
`challenges`, `venue_spaces`, `sport_profiles`, `user_badges`, `point_ledger`,
`sport_profile_profile_badges`

**`updated_at` touches** — ~25 triggers, several naming conventions in parallel
(`trg_touch_updated_at`, `touch_updated_at`, `_touch_updated_at`, `_set_updated_at`,
`fn_set_updated_at`, `set_current_timestamp_updated_at`, `update_updated_at_column`).

**Suspected duplicates — verify before touching, do not assume**
- `trg_squads_owner_default` **and** `trg_squads_owner_defaults` — both on `squads`
- `trg_meetups_touch` **and** `trg_meetups_updated` — both touch `updated_at` on `meetups`
- `trg_roster_set_user` **and** `trg_roster_set_user_and_guard` — both on `game_roster`
- `trg_roster_block_frozen` **and** `trg_roster_block_frozen_guard`
- `trg_invite_block_frozen` **and** `trg_invite_block_frozen_guard`
- `trg_joinreq_block_frozen` **and** `trg_joinreq_block_frozen_guard`

These pairs look like a refactor that added the `_guard` form without removing the original.
**Not confirmed** — each needs its function body read before anything is dropped. Dropping a
freeze guard that turns out to be load-bearing re-opens a safety hole.

---

## 6. EDGE FUNCTIONS — 3

| Function | Purpose | Notes |
|---|---|---|
| `send-push-notification` | Delivers FCM push, fired by `trg_push_on_notification_insert` | Fetches the push-trigger shared secret via a `service_role`-only RPC, once per warm instance. Fetching it per request caused a 401 (fixed in `09ca8fe`) |
| `broadcast-notification` | Bulk/broadcast notification send | Handles a service-account private key |
| `detect-country` | IP → country for onboarding | `ip_country_detection_service.dart:34` carries `// TODO: Disable JWT verification in Supabase dashboard for this function` — a config change never made |

`service_role` inside `supabase/functions/**` is **server-side and correct.** It appears
nowhere in `lib/`.

---

## 7. EXTENSIONS

| Schema | Extensions |
|---|---|
| `public` | `postgis`, `citext`, `pg_trgm`, `btree_gin`, `btree_gist`, `cube`, `earthdistance`, `unaccent` |
| `extensions` | `pg_net`, `pg_stat_statements`, `pgcrypto`, `pgtap`, `uuid-ossp` |
| `pg_catalog` | `pg_cron`, `plpgsql` |
| `vault` | `supabase_vault` |

The 8 in `public` are flagged `extension_in_public` by the Supabase advisor. **Not
actionable** — Supabase installs them there by default and relocating `postgis` would break
every geo query. Ignore the warning.

`pgtap` is installed, so database-level tests are possible. Nothing uses it.

---

## 8. KNOWN MISMATCHES — where the app expects what the database does not have

> **Mismatch 7 below is the single authoritative statement of the migration situation.**
> Every other document points here rather than restating it — `CONTRACT.md`,
> `ARCHITECTURE.md`, `WORKFLOWS.md` W2, `MANIFESTO.md` §6. That rule exists because this
> fact was wrong in up to eight documents simultaneously, twice, each copy re-derived
> instead of read. If you need to state it somewhere new, link here instead.

| # | The app expects | The database has | Impact |
|---|---|---|---|
| 1 | `venue-images` bucket (`supabase_config.dart:4`) | Bucket named `venue` | Dormant — constant unused. Trap |
| 2 | `avatars` bucket (`supabase_profile_datasource.dart:16`) | Bucket named `Avatar` | Dormant — dead path. Live uploads use `ImageUploadService` correctly |
| 3 | Readable `games` table — 20 `.from(gamesTable)` calls | RLS on, **zero policies** → 0 rows | The whole `games` clean-arch datasource returns nothing |
| 4 | `dabbler-news` readable after upload | INSERT policy, no SELECT | Read-back fails |
| 5 | `venue` bucket writable | No policies at all | Uploads impossible |
| 6 | Working analytics (`rpc_track_event` exists) | RPC exists; **the client never calls it** — `analytics_service.dart` is 18 empty `// TODO` bodies | The database is ready; the app sends nothing |
| 7 | A reproducible schema from the repo | **`supabase_migrations.schema_migrations` holds 237 applied migrations** (`20251113222001` → `20260720192127`). Separately, 38 `.sql` files are tracked at `supabase/schema/`, of which **exactly 1 contains `CREATE TABLE`** | Schema **history exists** — in the ledger. What does not exist is a repo-authored way to *rebuild* the schema. KAN-33 |
| 8 | One `nearby` implementation | Five generations, all callable | Wrong-generation calls are easy and silent |

**Mismatch 6 is worth a second look.** `rpc_track_event(_event_name, _properties)` exists
server-side and `analytics_events` has policies. The gap is entirely client-side — every
`AnalyticsService` method is an empty body. Whoever picks up analytics does not need to build
the backend; it is already there.

---

**A dated, concrete instance of this class — 2026-08-29.** `kan27a_venue_dabbler_news_storage_policies.sql`
had a `DROP` statement **added to the file after the migration was applied**, so the tracked
file described a state production had never been in. Caught by `cto`, stripped by `team-lead`;
verified here — the only remaining occurrence of the word is inside a comment referencing a
separate out-of-scope fix (`T-030`/KAN-75), and no executable `DROP` remains.

**Why it belongs in §8 rather than in a ticket:** the divergence this section describes is
usually framed as *history that was never captured*. This is the other direction — **a file
edited after the fact, drifting away from a live state that did not change.** Both produce the
same end condition (the repo is not a reconstruction of the live schema) and only one of them
leaves a trace in the ledger. **Reading a migration file tells you what someone wrote, not what
the database ran.**

### 8a. Filenames and ledger versions do not match, and that is by design — not a defect

**`apply_migration` stamps its own version at apply time. It does not use the filename.** So
`supabase_migrations.schema_migrations` and `supabase/migrations/` disagree on the version of
every migration applied through the MCP tool, permanently and correctly.

Two measured instances, both 2026-09-07:

| Migration | Filename version | Recorded in the ledger as |
|---|---|---|
| `KAN-141` drop `list_active_usernames` + view | `20260906210000` | **`20260907052826`** |
| `KAN-145` `payment_intents` booking FK | `20260907100000` | today's apply-time stamp |

**Two consequences, and both have already caused a wrong conclusion here:**

1. **Filename order is not apply order, so it is not load-bearing.** A file whose timestamp
   sorts *before* an unapplied migration has not "jumped the queue" — it will record under the
   moment it actually ran. `backend-4` correctly declined to infer a sequencing hazard from
   `KAN-145`'s file sorting ahead of `KAN-128`'s (`20260907100000` vs `20260909090000`); the
   real sequencing question was about function-body replacement and is settled in `T-052`.
   Filenames order a *fresh replay from empty*, nothing else.

2. **Reconciling the two lists by name will show mismatches that are not missing migrations.**
   Anyone diffing `list_migrations` against the directory will find names that do not line up
   and can reasonably read that as a failed, skipped or lost migration. It is not. **The ledger
   is authoritative for what ran; the directory is authoritative for what a replay would do.**
   Neither is a check on the other, and a name-based diff between them proves nothing.

This is the same lesson as the paragraph above it, from the opposite end: there, a file was
edited after the fact and drifted from a live state that never changed. Here, nothing drifts at
all — the two records simply answer different questions, and only one of them is a record of
events. Raised by `backend-4` after applying `KAN-141` and `KAN-145`; recorded here rather than
left in ticket comments, per §8's single-location rule.

**And the corollary, which decides a question this project had not faced until 2026-09-07:
`supabase db push` is never the apply mechanism here.**

`KAN-155`'s migration — reserved to the CEO under `019` because it mutates 82 live
`user_subscriptions` rows — is committed and on `Canary` while deliberately unapplied. That is
the **correct** state: the file belongs in the repo, and being authored-but-unapplied is what
awaiting a hand-applied action looks like. `backend-4` checked and confirmed no CI path can
execute it: neither `ci.yml` nor `anon-allowlist-check.yml` references Supabase, and
`scripts/cloudflare-build.sh` does not touch migrations.

The residual risk is a person or agent running `supabase db push`, which applies **everything**
in `supabase/migrations/` not already in the ledger — including a migration whose first twenty
lines say only the CEO may apply it, because a bulk push does not open the file. That is not a
reason to move the file out of `supabase/migrations/`: it belongs there for replay correctness,
and a directory whose contract is "apply everything here" is exactly where a replay must find it.

**The rule instead — and it is total.** Migrations in this project are applied **one at a time,
deliberately, by the seat authorised for that specific migration**, via `apply_migration` with
that migration's own SQL. **Never `supabase db push`, never a bulk apply, at any time, on any
branch.** A bulk apply cannot distinguish a routine schema change from one carrying a reserved
authority, and the authority boundaries in `019`, `G-002` and `G-028` are stated in the files
rather than in the tooling. This rule is what makes an unapplied migration safe to commit; it is
not a preference about ergonomics. Raised by `backend-4`, ruled by `cto` 2026-09-07.

## 9. HOW TO VERIFY ANY CLAIM IN THIS FILE

Do not trust this document over the database. It is a snapshot dated 2026-08-26.

```sql
-- RLS position for one table
select relrowsecurity from pg_class where relname = 'your_table';
select * from pg_policies where tablename = 'your_table';

-- What a role can actually see  (the only question that settles it)
set local role anon;             -- or authenticated
select count(*) from public.your_table;
```

**Always pair a probe with a control** — a query that *should* return 0. If the control
returns rows, the probe is not testing what you think it is.


---

## 10. WHAT THIS FILE HAS BEEN WRONG ABOUT

Kept deliberately. A schema document that silently self-corrects earns unearned trust.

| Date | Error | Correction |
|---|---|---|
| 2026-08-26 → corrected 2026-08-27 | "49 views, 25 `SECURITY DEFINER`, 8 anon-exposed" | **71 views, 49 definer, 19 anon-exposed.** Two conflations in one line: the reported *total* (49) was actually the definer count, and the reported *definer* count (25) was the number of `security_definer_view` rows the Supabase advisor returned |
| 2026-08-26 → corrected 2026-08-27 | "No schema history exists" | **237 rows in `supabase_migrations.schema_migrations`.** One location was checked — the filesystem — and "nowhere" concluded |

**How the view miscount happened, because it generalises.** The advisor was asked for
security findings and returned 25 `security_definer_view` advisories. That number was then
used as *the number of definer views in the database*. **An advisor reports what it flags,
not what exists** — it may cap results, skip system objects, or apply its own relevance
filter. The population must be counted with a query against the catalogue, and the advisory
count treated only as "at least this many are worth looking at".

The practical consequence was that **11 anon-exposed views were never examined**, because
the audit believed it had already covered the whole set.

### §10 errata — added 2026-08-28

**"8 definer views, safe by `auth.uid()` predicate" was wrong.** I assigned that position by
reading each view's definition for the string `auth.uid()` and never queried one. Probing all
eight as `anon` on 2026-08-28: six return zero rows, **`v_game_card` returns 216 and
`v_meetup_list` returns 1**. Their filter is `listing_visibility = 'public'` — the right
outcome for the row set, reached by a mechanism this file misnamed, and two views recorded as
safe are in fact readable.

The general rule this file should have followed, and now does: **a view's position is
established by querying it as `anon` with a control query in the same transaction, never by
reading its definition.** §2b now carries a per-view row count. Regenerate with §2e.

## 11. THE DEFINER-VIEW PROBLEM IS ALSO A WRITE PROBLEM

*Added 2026-08-28. Raised by `cto`, every link re-verified here. See `PROJECT_STATE.md` SEC-16.*

§2 of this file censused all 71 views for **read** exposure and stopped there. That framing
was incomplete, and the gap was not small: **a `SECURITY DEFINER` view can be writable, and
when it is, the base table's RLS is not evaluated.**

### The mechanism, in the order it has to be checked

1. **Is the view auto-updatable?** `information_schema.views.is_insertable_into`. Simple
   single-table views are; **aggregates are not** — which is why only
   `v_notifications_feed` is writable and `v_mod_queue_open` / `v_safety_overview` are not,
   despite carrying the same wide grants.
2. **Does an untrusted role hold the DML grant?** `has_table_privilege('anon', v, 'INSERT')`.
   A `SELECT`-only census will never see this.
3. **Are the NOT NULL, no-default columns exposed in the view?** If not, no row can be
   constructed. For `notifications` these are `to_user_id`, `kind_key`, `title` — all three
   are in the view.
4. **Does the base table's RLS actually run?** This is the one that catches people, and
   there are **two independent ways for the answer to be no**. Test both.
   - **Owner path.** If the view and the table share an owner and the view is not
     `security_invoker`, the base table is accessed **as its own owner**, and Postgres skips
     RLS for a table's owner unless `relforcerowsecurity` is set. A perfectly correct
     `WITH CHECK (false)` policy is simply never evaluated.
   - **`rolbypassrls` path — and on this project it subsumes the owner path entirely.**
     The executing role may carry `rolbypassrls`, which skips RLS regardless of ownership
     **and defeats `FORCE ROW LEVEL SECURITY` too.** `postgres` has it
     (`pg_roles.rolbypassrls = true`); `anon` does not.

     **CORRECTED 2026-08-28 (`cto`).** An earlier version of this section used the
     `rolbypassrls` path only to explain `v_needs_organiser` over `auth.users`, and
     attributed the other six views to the owner path. That was wrong. **All seven app
     views are owned by `postgres`**, so BYPASSRLS — checked ahead of the owner/FORCE
     logic — applies to every one of them. The owner path is a real Postgres mechanism
     and it is not what is happening here.

     **Consequence: `FORCE ROW LEVEL SECURITY` remediates nothing on any of the seven.**
     Demonstrated on a table that already has it set — `public.sport_profiles`,
     `relforcerowsecurity = true`, owner `postgres`: **138 rows visible, 131 admitted by
     its policies.** Only the revoked grant closes these.

     **When you check this, enumerate every policy on the table.** `cto` reported a
     near-miss: a first pass tested only the `p.user_id = auth.uid()` policy and read
     138 vs 0, missing the permissive `p.is_active = true` policy that admits 131. **The
     real margin is 7, and an overstated margin is a correction waiting to happen.**

   ```sql
   SELECT rolname, rolbypassrls FROM pg_roles WHERE rolname IN ('postgres','anon','authenticated');
   ```

   A check that tests only `relforcerowsecurity` passes the `rolbypassrls` case silently.
5. **Does an INSERT trigger reach outside the database?** `notifications` has
   `trg_push_on_notification_insert`, which posts attacker-controlled `title`/`body` to an
   edge function over the trusted `x-trigger-secret` path.

### The rule

**`security_invoker` governs reads. It says nothing about a DML grant, and nothing about
owner-equals-owner.** Any catalogue check that asserts only on anon-reachability and invoker
status **passes with this hole wide open** — `cto` flagged that its own `T-002` test spec
had exactly that gap, and the corrected spec must also assert on grants and on
`relforcerowsecurity`.

### Reproduction (read-only; do not attempt the insert)

```sql
SELECT v.table_name,
       v.is_insertable_into,
       has_table_privilege('anon', 'public.'||v.table_name, 'INSERT') AS anon_insert,
       c.relforcerowsecurity
FROM information_schema.views v
JOIN pg_class c ON c.relname = v.table_name
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
WHERE v.table_schema = 'public';
```

**Verifying preconditions is the whole job here. Neither `cto` nor `master-analyst`
attempted the insert, and nobody should** — this is production, and `DECISIONS.md` 019 bars
every agent from writing it. The catalogue establishes the vulnerability; a write would only
establish it a second time, destructively.

## 12. BASE-TABLE WRITE GRANTS — KAN-86 (successor to KAN-67)

*Added 2026-09-01 by `backend-owner`. Migration:
`supabase/migrations/20260901170000_kan86_revoke_and_scope_anon_authenticated_table_grants.sql`
— authored and posted to KAN-86 for `cto` to apply under `G-002`; not yet live as of this
write.*

KAN-67 (2026-08-28) closed the wide `anon`/`authenticated` write grant on all 70
postgres-owned **views**. It explicitly did not touch base tables. KAN-86 closes the base
table half.

**Measured live 2026-09-01**, re-verified rather than trusted from the ticket's 2026-08-29
baseline (which had drifted — two tables were added since): 187 `relkind='r'` tables in
`public`; 186 owned by `postgres`, one (`spatial_ref_sys`) owned by `supabase_admin` and
untouchable (`T-025` — no role membership to `ALTER`/`REVOKE` it; PostGIS catalogue, not
Dabbler data). Of the 186, 183 held `anon` INSERT+UPDATE+DELETE=true; the other 3
(`data_export_requests`, `export_download_logs`, `gdpr_compliance_log`) were already scoped
down same-day by KAN-52's follow-ups.

**RLS already denies `anon` on all 186** — every permissive policy reaching `anon` was
enumerated in KAN-86's own ticket text and falls into a gated shape (literal `false`,
definer-funnel, definer-owner, or an owner/admin predicate that resolves `auth.uid()` to
`NULL` for `anon`). This migration closes redundant grant surface, not an open leak.

### The expected re-grant set (`T-002`'s CI gate should assert against this)

Derived from every `.from('<table>').insert/update/upsert/delete` call site in `lib/` and
`supabase/functions/`, resolved through `supabase_config.dart` constants (and the handful of
non-`SupabaseConfig` local `_table` string constants, resolved to their literal value — never
trusted from an inline grep). `anon` gets nothing re-granted anywhere: no call site writes to
a base table as `anon`. Edge-function writes (`send-push-notification`, `detect-country`) use
`SUPABASE_SERVICE_ROLE_KEY` and bypass grants entirely, so they need none.

| Table | `authenticated` verbs |
| --- | --- |
| `profiles`, `sport_profiles`, `organiser`, `circle_members`, `posts`, `likes`, `profile_locations`, `squads`, `games`, `reactions`, `moderation_ban_terms`, `fcm_tokens` | INSERT, UPDATE, DELETE |
| `user_settings`, `moderation_tickets`, `post_hashtags`, `post_views`, `venue_spaces`, `venue_price_rules`, `venue_submissions`, `game_join_requests`, `user_preferences`, `privacy_settings`, `data_export_requests`, `notification_settings`, `comments` | INSERT, UPDATE |
| `space_slot_holds`, `game_roster` | INSERT, DELETE |
| `player`, `host`, `profile_tiers`, `moderation_actions`, `post_squads`, `hashtags`, `geo_locations`, `squad_invites`, `export_download_logs`, `gdpr_compliance_log`, `profile_follows` | INSERT |
| `post_reposts` | DELETE |
| `notifications` | UPDATE |

Every other postgres-owned base table (146 of the 186) is revoke-only: no direct client
write reaches it. Writes the app performs on those tables go through a `SECURITY DEFINER`
RPC (e.g. `game_waitlist`, `wallets`), which runs as its owner and is unaffected by these
grants — that is the mechanism that makes the revoke safe.

### Dead-code table references found during the sweep (not fixed here)

Several `SupabaseConfig` constants and one hardcoded local table name point at tables that
**do not exist live** — grep found real call sites writing to them, but a live check
(`information_schema.tables`) came back empty for all of:

`bookings` (`bookings_datasource.dart`, 11 call sites — `venue_bookings` is likely the
intended table), `game_ratings`, `venue_reviews`, `payment_methods`
(`payment_methods_datasource.dart`, 5 call sites — only `payment_intents`/`payment_records`
exist), `organiser_benefits`, `profile_views`, `venue_opening_hours` (renamed to
`opening_hours` by a prior migration), and the entire GDPR/account-deletion surface in
`data_retention_service.dart` — `user_retention_policies`, `scheduled_cleanup_tasks`,
`data_cleanup_audit`, `grace_period_requests`, `messages`, `login_history`, `user_media`,
`location_data`, `user_analytics`, `audit_logs`. None of these ten exist either. No grant is
possible or needed on a table that doesn't exist; this migration cannot regress them further.
Flagging for `master-analyst`/`cto` — this is a much bigger dead-code surface than this
ticket's scope, not something to silently fold into a grants migration.

## 13. `games` AND `events` — the shared columns live on `events` (KAN-866, 2026-11-14)

Since migration `20261114123000_kan866_drop_games_shared_columns.sql`, `public.games` holds only the columns no other event
type shares. Every game has exactly one `public.events` parent (`event_type = 'game'`, `events.id = games.event_id = games.id`),
and the shared facts are read and written there.

**`public.games` (14 columns):** `id`, `game_type`, `venue_space_id`, `allow_spectators`, `rules`, `squad_id`,
`sport_specific_data`, `allows_waitlist`, `sport_variant_id`, `bench_slots`, `price_aed`, `series_id`, `event_id`,
`event_changed_at`.

**Moved to `public.events` (dropped from `games`, 22):** `creator_profile_id`, `creator_user_id`, `title`, `start_at`,
`end_at`, `capacity`, `listing_visibility`, `join_policy`, `is_cancelled`, `cancelled_at`, `cancelled_reason`, `sport_id`,
`area_id`, `geo_location_id`, `venue_id`, `min_skill`, `max_skill` (smallint on events), `joining_rule`, `cost_cover`,
`request_id`, `created_at`, `updated_at`.

* **Writers** (KAN-947) insert or update `events` first and touch `games` only for its own columns. The location and
  joining facts come from `kan947_game_derive(events, venue_space_id, sport_variant_id, old events, old space)`.
* **Readers** (KAN-948) join `games g JOIN events e ON e.id = g.event_id AND e.event_type = 'game'`. The views
  `v_game_card`, `v_my_games`, `kan714_games_read` and `kan718_games_compat` expose the old column names from `events`.
* **Side effects of a game** fire from `events` triggers with `WHEN (NEW.event_type = 'game')`: the activity row
  (`tr_kan947_events_game_activity_sync`), the cancel notification (`trg_kan947_events_game_updated_notify`) and the
  chat system line (`msg_kan947_events_game_cancelled`).
* **Uniqueness that moved:**
  * request_id: `events_type_creator_request_id_key`;
  * series occurrence: `kan718_series_occurrence_guard`, a trigger on `events.start_at` and `games.series_id`.
* **Realtime:** `games` is published with `(id, event_changed_at)`. `trg_kan949_events_nudge_subtype` bumps
  `games.event_changed_at` whenever a listing field changes on the parent.
* **Rollback data:** `public._kan866_games_backup` holds the 22 values per game as they stood at the drop. RLS is on,
  there is no policy, and only postgres can read it. The restore script is
  `supabase/schema/rollback/kan866_ROLLBACK_restore_games_shared_columns.sql`.
* **Mobile builds older than 181** read these columns from `games` directly and break. The CEO accepted that on
  2026-11-14 (Jira KAN-866 16314).

### 13a. Event change signal: `schedule_revision`, `event_changes`, `event_timezone` (KAN-976, 2026-11-17)

Migration `20261117045201_kan976_event_change_signal`. It is the one signal that an event changed. The change
notifications (W1-B3), the reminder scheduler (KAN-983) and the producers (KAN-981) read it. **No other ticket in Epic
KAN-973 adds a trigger on `events`.**

**`events.schedule_revision`** (`integer NOT NULL DEFAULT 0`, check `>= 0`)
* Goes up by 1 on an UPDATE that changes the time (`start_at`, `end_at`) or the place (`venue_id`, `area_id`,
  `geo_location_id`).
* Nothing else moves it.
* The trigger owns the column: a direct write is replaced by the computed value and writes no row.

**`public.event_changes`** (outbox) has one row per changed field per UPDATE.

| Column | Type | Meaning |
|---|---|---|
| `id` | `bigint` identity PK | Cursor for consumers |
| `event_id` | `uuid` FK `events(id)` ON DELETE CASCADE | The event that changed |
| `event_type` | `text` (`game`, `meetup`) | The event's type |
| `revision` | `integer` | `schedule_revision` after this UPDATE |
| `field` | `text` | One of `start_at`, `end_at`, `venue_id`, `area_id`, `geo_location_id`, `capacity`, `join_policy`, `joining_rule`, `cost_cover`, `min_skill`, `max_skill`, `is_cancelled` |
| `old_value`, `new_value` | `jsonb` | `to_jsonb` of the column, NULL when the column was NULL |
| `schedule_change` | `boolean` | true for the five time and place fields |
| `actor_user_id` | `uuid` | `auth.uid()`; NULL for service or system writes |
| `change_group` | `uuid` | The same value for every row of one UPDATE of one event |
| `occurred_at` | `timestamptz` | `now()`, the transaction time |
| `consumed_by` | `jsonb` object, default `{}` | Per-consumer marker, for example `{"w1_b3": "<timestamptz>"}` |

* Not recorded:
  * `title`, `listing_visibility` and `sport_id`;
  * `cancelled_at` and `cancelled_reason`. A meetup cannot store these (`events_meetup_cancel_null`; KAN-982 owns
    that). A cancel is the `is_cancelled` row.
* A venue move writes three rows in one `change_group` with one bump: `venue_id`, plus the `area_id` and
  `geo_location_id` that `kan713_events_location` derives.
* Access is server only:
  * RLS is on, with no policy.
  * `anon` and `authenticated` have nothing (42501).
  * `service_role` has SELECT and UPDATE.
  * The identity sequence `event_changes_id_seq` is closed too: PUBLIC, `anon` and `authenticated` were revoked by
    `20261117053118_kan976b_event_changes_seq_acl_tz_names`. It had been created with `rwU` for them from the project
    default ACL, so a client could `setval` it and break every tracked `events` UPDATE. The ACL is now postgres and
    service_role only. **A new identity or serial column in `public` inherits this default; revoke it explicitly.**
* Indexes: `(event_id, id)` and `(occurred_at)`.

**Trigger `trg_kan976_events_change_signal`**
* Definition: BEFORE UPDATE FOR EACH ROW, function `kan976_events_change_signal()`. The function is SECURITY DEFINER
  with `search_path = ''`, and EXECUTE is revoked from PUBLIC, `anon` and `authenticated`.
* Its WHEN clause lists the 12 recorded fields plus `schedule_revision`.
* Its name sorts after every other BEFORE trigger on `events`, so it sees the location that `trg_kan713_*` derives.
* No double firing:
  * It does not write to `games` or `meetups`.
  * `schedule_revision` is not in the WHEN clause of `trg_kan949_events_nudge_subtype`.
  * So it adds no kan949 or kan950 nudge.
* It sends no notification. The cancel notification (`trg_kan947_events_game_updated_notify`) is unchanged: a game
  cancel with a roster of 1 gives +1 notification both before and after this migration.

**`public.event_timezone(p_event_id uuid) RETURNS text`**
* STABLE, SECURITY DEFINER, `search_path = ''`. EXECUTE is granted to `service_role` only.
* Lookup order:
  1. `venues.timezone` (trimmed), if it is accepted. A zone is accepted when both checks pass:
     * it has the shape `^(UTC|[A-Z][A-Za-z_]+(/[A-Z][A-Za-z_-]*)+)$`
       (`20261117055656_kan976d_timezone_shape_tighten`, which replaced the looser kan976c shape);
     * `now() AT TIME ZONE` accepts it, run inside a BEGIN/EXCEPTION `invalid_parameter_value` block.

     Everything else falls through: POSIX `UTC+4`, `+04`, `Asia/Dubai+4`, `Etc/GMT±N`, `GST`, lowercase, empty,
     unknown names such as `Mars/Olympus`, and legacy `EST5EDT`. Losing `EST5EDT` was accepted in PEER review.
     Names that pass include `America/Port-au-Prince` and `America/North_Dakota/New_Salem`.

     **`venues.timezone` carries the same shape as `CHECK venues_timezone_shape_chk`** (from kan976d; it was
     validated against all 384 live rows, all `Asia/Dubai`). A bad zone cannot be stored, so the function's own
     check only matters for data that bypasses the CHECK.
     **Do not use `pg_timezone_names` here.** `20261117053118` did, and it cost 54 ms per call (16.8 s for 315
     events). The current check takes 79 ms for 315 calls;
  2. the country of the event's area (`events.area_id`, else the area of its `geo_location_id`) through the map AE
     `Asia/Dubai`, SA `Asia/Riyadh`, QA `Asia/Qatar`, KW `Asia/Kuwait`, BH `Asia/Bahrain`, OM `Asia/Muscat`;
  3. `Asia/Dubai`.
* Returns NULL when the event does not exist.
* Today every venue is `Asia/Dubai` (`venues.timezone` is NOT NULL with that default) and every area is `AE`.

Live test: `supabase/tests/notifications_v2/kan976_event_change_signal.sql`. Rollback:
`supabase/schema/rollback/kan976_ROLLBACK_event_change_signal.sql`.

### 13b. Event change and cancel notices (KAN-981, 2026-11-17)

Migration `20261117102109_kan981_event_change_notices`. These notices tell people when an event they take part in
changes or is cancelled. **This is the only consumer of `event_changes` that sends notices.** Its consumer key is
`w1_b3`; the reminders of KAN-983 use `w1_b5`.

**Who is told** (`kan981_recipients(event_id)`)
* For a game, players whose `game_roster.status` is `active`.
* For a meetup, RSVPs whose status is `going` or `interested`.
* Never the creator, and never the person who made the change.
* Not told: roster rows that are `left` or `kicked`, and RSVPs that are `cancelled` or `pending`. The old meetup cancel
  path also reached `pending`; that was dropped on purpose.

**Cancel: sent at once by a trigger**
* The trigger is `trg_kan947_events_game_updated_notify` (AFTER UPDATE, `WHEN old.is_cancelled IS DISTINCT FROM
  new.is_cancelled`). It now covers meetups too, keeps its old name, and still calls `trg_game_updated_notify()`.
  No trigger was added to `events`.
* On a false → true change it sends `game.cancelled` or `meetup.cancelled` through `notify_v2`, with
  dedupe key `w1_b3:cancel:<event_changes.id>`, and marks that outbox row as consumed.
* A game that is a series occurrence is skipped here. The consumer below sends it, so it can group a whole-series
  cancel.

**Old senders, removed in the same migration**
* The `game.updated` loop. `game.updated` is now `is_active = false`, so nothing sends it.
* The `process_notification_event('meetup.cancelled')` loop inside `rpc_meetup_cancel_kan712_inner`.

**Changes: sent by a cron consumer**
* `kan981_consume_event_changes(p_now, p_settle = 60 s, p_max_wait = 5 min)`, run by pg_cron job
  `kan981_event_changes_every_minute`.
* **Why cron and not a deferred trigger:**
  * the debounce has to wait for edits to stop, and a deferred trigger fires at the writer's commit;
  * a failure here never rolls back the organiser's save;
  * one run can group the occurrences of a series.
* **The cost:** a change notice arrives 1–2 minutes after the last edit.

**How the consumer batches**
* **Per event:** it takes all the event's unconsumed rows once the event has been quiet for 60 s, or once its oldest
  unconsumed row is 5 minutes old.
* **Collapse:** for each field it keeps the first old value and the last new value. A field that ends where it started
  is dropped, and if nothing is left no notice is sent.
* **One notice per batch, listing every changed field.** The kind is `*.time_changed`, else `*.venue_changed`, else
  `*.details_changed` (places, who can join, joining rule and cost cover, skill range).
* **Series:** if one transaction changed two or more occurrences of a game series, each person gets one notice
  across those occurrences:
  * `game.series_cancelled` when every occurrence in that batch was cancelled in the transaction
    (`rpc_cancel_game_series`) **and** the series is over: `game_series.status = 'ended'`, or no future occurrence
    that is not cancelled remains (`20261117165950_kan1015b_series_cancel_only_when_over`). A shortened edit-future
    that cancels the later dates while earlier ones go on is `game.series_changed`. EN "All upcoming {title} games were cancelled", AR "أُلغيت جميع مباريات {title}
    القادمة". The title is `game_series.title`, else `kan981_event_title` without its own noun ("Football",
    "كرة القدم"). Added by `20261117163934_kan1015_series_cancelled`;
  * `game.series_changed` for any other series batch: an edit, including an edit that also cancels some dates.

  A single occurrence cancelled on its own sends `game.occurrence_cancelled` to that occurrence's players only.
* **No notice:** an event that is now cancelled, or already in the past, is consumed silently.
* **Dedupe keys:** `w1_b3:change:<event>:<max id>`, `w1_b3:series:<series>:<max id>` and
  `w1_b3:series_cancel:<series>:<max id>`. A replayed batch therefore
  writes nothing new.

**What a notice carries (`args`)**
* `title_*`, `field_*`, `old_*`, `new_*` and `when_*`, each in `en` and `ar`. `notify_v2_render` picks
  `<key>_<lang>`.
* `changes[]`, one entry per field.
* `schedule_revision`.
* Times are written as `Fri 20 Nov, 14:00–16:00` or `الجمعة 20 نوفمبر، 14:00–16:00`, in `event_timezone(event)`.

**Kinds**
* Active, all with `breaks_quiet = true`:
  * `game.cancelled`, `game.time_changed`, `game.venue_changed`, `game.details_changed`,
    `game.occurrence_cancelled`, `game.series_changed`, `game.series_cancelled` (KAN-1015, category `games`);
  * `meetup.cancelled`, `meetup.time_changed`, `meetup.venue_changed`, `meetup.details_changed`.
* Inactive: `meetup.occurrence_cancelled` and `meetup.series_changed`, because meetups have no series.

**Helpers:** `kan981_fmt_span`, `kan981_value_label`, `kan981_place_name` and `kan981_event_title`.

**Grants:** all helpers are revoked from PUBLIC, `anon` and `authenticated`. Only the consumer has EXECUTE for
`service_role`.

**Not covered (known gaps)**
* `meetups.location_name` is not an `events` field, so a meetup's free-text location change produces no notice.
* `rpc_edit_game_series_future` never rewrites an occurrence that has players. So a series edit only notifies players
  through `rpc_cancel_game_series`, or through the occurrences that edit does change.

Live test: `supabase/tests/notifications_v2/kan981_event_change_notices.sql`. Rollback:
`supabase/schema/rollback/kan981_ROLLBACK_event_change_notices.sql`.

---

## 14. Profile discoverability — visible by default (KAN-958, 2026-11-16)

CEO decision 2026-11-16: profiles are discoverable unless the owner opts out. Migration
`20261115214329_kan958_profiles_visible_by_default`.

* **The rule** lives in `public.is_profile_publicly_visible(p_profile_id uuid)`: the profile is
  active, `NOT is_benched(user_id)`, and `user_status.hide_in_search IS NOT TRUE`. **No `user_status`
  row means visible.** Only `hide_in_search = true` hides. Before KAN-958 a missing row meant hidden
  (`coalesce(hide_in_search, true) = false`), which hid every profile.
* **Blocks are not in the helper.** Each caller applies them; `active_stream` filters
  `NOT is_blocked(viewer, p.user_id)` on `player_joined`.
* **SECURITY DEFINER, owner postgres, `search_path = public, pg_temp`, EXECUTE for `authenticated` and
  `service_role` only.** `user_status` RLS is select-own, so an invoker helper could not see another
  user's opt-out and would report them visible. Do not change it back to invoker.
* **`user_status.hide_in_search` defaults to `false`** (was `true`), so a row created without the
  column (`rpc_get_my_status`) does not opt the user out.
* **Callers:** `active_stream` only (as of 2026-11-16). People search (`rpc_profile_search`,
  `rpc_autocomplete_people`, `rpc_unified_search_sectioned`, `rpc_username_suggest`) does not read
  `hide_in_search` or this helper.
* **The opt-out is a bench setting and ends with the bench.** The only writer of `hide_in_search = true`
  is `rpc_toggle_bench` (the bench form's "Hide me in search", default on). `rpc_end_bench` sets
  `hide_in_search = false` along with `is_benched = false` (migration
  `20261115215007_kan958_end_bench_clears_hide_in_search`, which also cleared the 2 unbenched rows that
  still had `hide_in_search = true`).
* **`is_benched(uuid)` is a known dead helper:** it reads `user_benches` / `benches`, neither of which
  exists, so it always returns false. The real benched state is `user_status.is_benched`. Left as is.

## 15. Push devices: `fcm_tokens` is one row per installation (KAN-977, 2026-11-17)

Migration `20261117045109_kan977_fcm_tokens_installations`. Probes:
`supabase/tests/notifications_v2/kan977_devices_probes.sql`.

* **Key:** unique `(user_id, installation_id)` (`fcm_tokens_user_installation_key`). One user can have any
  number of devices, on any platform. **`token` is globally unique** (`fcm_tokens_token_key`), so a token
  never receives two sends.
* **Columns added:** `installation_id` (NOT NULL, 1..128 chars), `device_platform` (NOT NULL, the OS, on
  every row, same value set as `platform`), `app_version` (≤ 64), `locale` (≤ 35), `os_permission`
  (`granted` | `denied` | `provisional` | NULL = not asked or unknown), `last_seen_at` (set on every write).
* **`platform` is now the legacy slot, and is NULL on installation rows.** Old builds upsert with
  `onConflict: 'user_id,platform'`. Postgres needs a non-partial unique index on exactly
  `(user_id, platform)` to plan that, and a partial index fails with 42P10. So `unique_user_platform` stays as
  the arbiter for old builds only:
  * legacy rows (old builds, and all 56 rows that existed on 2026-11-17): `platform` = the OS,
    `installation_id = 'legacy:' || platform`, at most one per user and platform, as before;
  * installation rows (`rpc_register_push_token`): `platform IS NULL`, so the unique index ignores them.
  `fcm_tokens_legacy_slot_check` enforces that split. **Read `device_platform` for the OS, not `platform`.**
  Once no old build is left, `platform` and `unique_user_platform` can go.
* **Trigger `fcm_tokens_normalize`** (BEFORE INSERT OR UPDATE, SECURITY DEFINER, `search_path = ''`, no
  EXECUTE for client roles) derives the legacy ids from `platform`, stamps `last_seen_at`, and **deletes
  every other row that holds the same token**, whatever user owns it. That makes a token move to the new user
  after an account switch on a shared device, and retire a device's legacy row when it upgrades and
  registers through the RPC. It is definer because the other holder is usually another user's row, which
  RLS hides.
* **RPCs** (SECURITY INVOKER, `search_path = ''`, EXECUTE for `authenticated` only):
  * `rpc_register_push_token(p_installation_id, p_token, p_platform, p_app_version, p_locale,
    p_os_permission) → uuid` upserts this installation's row and returns its id. It refuses a NULL uid
    (42501), and a blank or `legacy:` id, blank token, unknown platform or unknown permission (22023).
  * `rpc_unregister_push_token(p_installation_id) → boolean` deletes the caller's row for that installation
    only. It returns false when there was none.
* **RLS:** four owner policies `TO authenticated`, `(select auth.uid()) = user_id`. `anon` has no grant.
  `authenticated` keeps direct INSERT/UPDATE/DELETE because old builds write the table directly.
* **Readers:** `send-push-notification` selects `token, platform` and prunes by token. It still delivers
  to every row. Its `platforms` filter matches only legacy rows, and nothing passes it today. KAN-979 owns
  moving it to `device_platform`.

## 16. Notification envelope v2: `notify_v2`, envelope columns, kind templates (KAN-974, 2026-11-17)

Migration `20261117045242_kan974_notification_envelope_v2.sql`. Live test
`supabase/tests/notifications_v2/kan974_envelope_v2_test.sql` (39 checks, rolled back).

* **`notify_v2(p_to_user_id uuid, p_kind_key text, p_args jsonb = '{}', p_entity_type text = NULL,
  p_entity_id uuid = NULL, p_actor_user_id uuid = NULL, p_source_event_id text = NULL, p_dedupe_key text = NULL,
  p_group_key text = NULL, p_action_route text = NULL) → uuid`**. SECURITY DEFINER, `search_path = public, pg_temp`,
  EXECUTE for `service_role` only (proacl `{postgres=X/postgres,service_role=X/postgres}`). It is the sender every
  later notification ticket writes to; `process_notification_event` stays unchanged for kinds that have not moved,
  and a kind has one sender at a time.
  * `p_dedupe_key` is required (22004). The call is idempotent on `(to_user_id, dedupe_key)`: a repeat returns the
    existing row's id and writes nothing.
  * Writes nothing (returns NULL) when the kind is inactive, or when the actor and recipient block each other in
    either direction (`user_blocks`). **A muted kind still writes the inbox row** (KAN-974c `20261117101144`, design
    PUSH-12); the push trigger skips its push (§18).
  * Priority is the kind's `default_priority`.
  * Language: the recipient's profile `language` (active profile first), then `user_settings.locale`, then `en`.
    `ar` picks the `_ar` templates. `title`/`body` are rendered and stored so old app versions still show them;
    `action_route` is `p_action_route` or the same game/meetup deep link `process_notification_event` builds.
  * Templates use `{name}` placeholders filled from `args`; `{name}_ar` / `{name}_en` in `args` override `{name}` for
    that language; `{actor}` defaults to the actor's display name ("Someone" / «شخص ما», also in
    `context.actor_display_name`). Values are inserted literally in one pass (a value containing `{title}` is not
    expanded); unfilled placeholders render empty (`notify_v2_render(text, jsonb, text)`, service_role only).
  * A kind with an enabled `notification_aggregation_rules` row is handed to `process_notification_event` unchanged
    (returns NULL, no dedupe on that path). Aggregation belongs to KAN-980.
* **`notifications` new columns:** `template_key text`, `args jsonb` (object), `source_event_id text` (opaque, e.g.
  an `event_changes.id`), `dedupe_key text` (partial unique index `notifications_to_user_dedupe_key_uidx` on
  `(to_user_id, dedupe_key) WHERE dedupe_key IS NOT NULL`), `group_key text` (index), `schema_version smallint NOT NULL
  DEFAULT 1` (1 = legacy row, 2 = `notify_v2`). The 1,337 rows that existed before read 1 with the other columns NULL.
* **`notification_kinds` new columns:** `title_template_en/ar`, `body_template_en/ar` (all NOT NULL), `breaks_quiet
  boolean` (default false), `can_mute boolean` (default true), `category text NOT NULL` in `social, messages, games,
  meetups, activities, system, security, booking`. Readable by clients like the rest of the table.
  * `breaks_quiet = true` only for I-3 kinds (cancellations, changes to an upcoming event, removal, waitlist
    promotion, reminders) and security notices: 22 kinds. `can_mute = false` only for `security.*`.
  * 87 kinds: the 35 existing (active, templates and flags added, sender unchanged) and 52 new, all **inactive**:
    membership (`game.join_declined`, `game.invite_accepted/declined/withdrawn/expired`, `game.player_left`,
    `game.full`, `game.waitlist_joined`, `game.waitlist_position_changed`, `meetup.removed`, `meetup.player_left`,
    `meetup.rsvp_interested`), event changes (`game./meetup.` `time_changed`, `venue_changed`, `details_changed`,
    `occurrence_cancelled`, `series_changed`, plus `game.cancelled`), reminders (`meetup.reminder`,
    `meetup.confirm_attendance`), attendance, lifecycle, results and ratings (`activity.*`, 22 kinds), security
    (`security.new_signin`, `security.password_changed`, `security.email_changed`) and social
    (`social.comment_replied`, `social.post_reposted`). `activity.starting_soon` is deliberately absent (it is the
    30m reminder rung). Each producer ticket activates its own kinds.
* **Client writes (KAN-974b, `20261117053400`):** `authenticated` no longer has table-level UPDATE on
  `notifications` (it could rewrite its own `dedupe_key` or `kind_key` and make `notify_v2` treat a notice as already
  sent). It has column UPDATE on `is_read`, `read_at`, `clicked_at`, `interaction_count` only: markAsRead / markAllRead
  (direct PostgREST update) and `increment_notification_interaction` (invoker) keep working. Table ACL now
  `{postgres=arwdDxtm/postgres,anon=rm/postgres,authenticated=rm/postgres,service_role=arwdDxtm/postgres}`. A
  client update of any other column fails with 42501.

## 17. Notification settings: one store, `notification_settings` (KAN-975, 2026-11-17)

Migrations `20261117045159_kan975_notification_settings_contract`,
`20261117053604_kan975b_category_keys_follow_registry` and `20261117054010_kan975c_quiet_hours_default_off`. Live test
`supabase/tests/notifications_v2/kan975_settings_contract.sql`.

`public.notification_settings` (PK `user_id`) is the only store for notification preferences. `user_settings` is
no longer read for quiet hours or timezone by any function; it is still read for `locale` by
`render_notification` and `notify_v2`, which is not a notification setting.

| Column | Type / default | Meaning |
|---|---|---|
| `tz` | text, `'Asia/Dubai'` | IANA name from the device. Validated against `pg_timezone_names` by trigger `trg_notification_settings_guard`. |
| `quiet_start_min`, `quiet_end_min` | int, default 0 / 480 since KAN-979 (§18; NULL before) | Quiet window in local minutes, end exclusive, may cross midnight. Both NULL = quiet hours off. Checks: both or neither, 0..1439, start <> end. Switching on through the RPC with no window gives 00:00-08:00 (0 / 480). |
| `quiet_hours_enabled` | bool, generated | `quiet_start_min IS NOT NULL AND quiet_end_min IS NOT NULL`. |
| `message_preview` | text, `'sender_and_message'` | or `'sender_only'` (F-2). |
| `reminder_rungs` | jsonb | `{"going"|"interested": {"24h","09:00","2h","30m": bool}}`, all true. Exact shape enforced by `notification_reminder_rungs_valid`. |
| `category_prefs` | jsonb | `{<category>: {"in_app": bool, "push": bool}}`, all true. Keys: `social`, `messages`, `games`, `meetups`, `system` (UI: "Rewards & announcements"), `booking` (hidden in UI). Enforced by `notification_category_prefs_valid`. |
| `muted_kinds` | text[] | Muted `notification_kinds.key`s. A security kind is rejected (22023). |
| `push_enabled` | bool | Master push switch. Does not apply to security kinds. |
| `email_enabled`, `sms_enabled` | bool | Legacy (F-15). Kept, read by no function, not settable through the RPC. |
| `allow_high_priority_override`, `allow_all_override` | bool | Legacy, read only by `trg_push_on_notification_insert`. |

**Category rules (delivery, KAN-979 must apply them).** Keys follow `notification_kinds.category`.
- `security` has no key: always on, never mutable, never silenced by `push_enabled` (CEO answer from planning).
- `activities` has no key: an activity kind (check-in, lifecycle, results, ratings) follows `games` when its entity
  is a game and `meetups` when its entity is a meetup. `notification_channel_enabled` has no entity argument, so for
  an `activities` kind it applies only `push_enabled` and `muted_kinds`; the caller that knows the entity checks
  `category_prefs -> 'games' | 'meetups' -> <channel>` as well.

**Functions.**
| Function | Security | EXECUTE | Does |
|---|---|---|---|
| `rpc_get_my_notification_settings()` | invoker (RLS) | authenticated | Creates the caller's row with defaults on first read; returns it. |
| `rpc_update_my_notification_settings(jsonb)` | invoker (RLS) | authenticated | Partial update. Keys: `tz`, `quiet_hours_enabled`, `quiet_start_min`, `quiet_end_min`, `message_preview`, `reminder_rungs`, `category_prefs` (both merged per key), `muted_kinds` (replaced), `push_enabled`. Unknown key = 22023. Quiet on with no window = 00:00-08:00; start = end = 22023. |
| `rpc_set_my_notification_timezone(text)` | invoker | authenticated | Device timezone. |
| `is_quiet_hour(uuid, timestamptz)` | definer | service_role | Quiet-hours rule; no row = 00:00-08:00 Asia/Dubai since KAN-979 (§18; was off). anon/authenticated revoked. |
| `is_in_quiet_hours(uuid)` | invoker | service_role | `is_quiet_hour(user, now())`. |
| `notification_channel_enabled(uuid, text, text)` | definer | service_role | Delivery reader for `in_app` / `push`: security kinds true; else push master, mutes, category flag. |
| `notification_kind_is_unmutable(text)` | definer | authenticated, service_role | `security.%` key, `category = 'security'` or `can_mute = false`. |

RLS: policies `ns_self_ins`, `ns_self_rw`, `ns_self_upd` (`auth.uid() = user_id`); `anon` has no table grant.
The existing client (`notification_settings_repository_impl.dart`) still reads and upserts the table directly.
**Superseded by KAN-979 (§18):** `trg_push_on_notification_insert` no longer drops the push; the text that follows
describes the state before it. It used to read `quiet_start_min`/`quiet_end_min` itself and drop the push in the
window; I-2 (silent, not dropped) is the delivery ticket's change.

**Quiet-hours default: OFF until KAN-979 (kan975c).** The CEO default is 00:00-08:00 (F-14), but
`trg_push_on_notification_insert` still drops a push inside the window, and the current client upserts this table
directly, so a 0/480 default would cost every new row its overnight pushes. Until silent delivery (I-2) lands the
column defaults are NULL and `is_quiet_hour` treats a missing row as off. **KAN-979 owns switching the default to
00:00-08:00** (column defaults `quiet_start_min` 0 / `quiet_end_min` 480 and the no-row branch of `is_quiet_hour`)
**in the same migration where silent delivery lands.** Rows reset by kan975c: 0 (none had 0/480 since 20261117045159).

## 18. Push delivery: silent quiet hours, payload v14, `notification_deliveries` (KAN-979, 2026-11-17)

Migration `20261117055738_kan979_delivery_silent_quiet_hours`, edge function `send-push-notification` v14. Live test
`supabase/tests/notifications_v2/kan979_delivery_test.sql` (database half; rolled back).

* **`trg_push_on_notification_insert`** (AFTER INSERT on `notifications`, SECURITY DEFINER, service_role only) decides
  whether a row becomes a push and how the device presents it. It never changes the row.
  * **Gate:** the kind's `default_channels` must include `push`, and `notification_push_enabled(user, kind,
    entity_type)` must be true. That function is `notification_channel_enabled(…, 'push')` (master switch, muted
    kinds, category flags; security kinds always on), plus the activities rule: an `activities` kind follows
    `category_prefs.games.push` for a game entity and `meetups.push` for a meetup entity.
  * **Quiet hours deliver silently (I-2), they no longer drop the push.** Mode `silent`: Android channel
    `dabbler_quiet`, `PRIORITY_LOW`, no sound, message priority normal; iOS `interruption-level: passive`, no sound,
    `apns-priority: 5`; web `silent: true`.
  * **Breakthrough (I-3):** a kind with `breaks_quiet` or a security kind (`notification_kind_is_unmutable`) always
    alerts and is iOS `time-sensitive`. Everything else outside quiet hours alerts with `interruption-level: active`.
  * The legacy `allow_all_override` / `allow_high_priority_override` flags are no longer read (no row had either on).
  * **Payload to the edge function:** `user_id`, `notification_id`, `title`, `body` (the row's text; `notify_v2`
    already rendered it in the recipient's language), `data` (all strings: `kind_key`, `action_route`, `entity_type`,
    `entity_id` = the real entity, `notification_id`, `dedupe_key`, `group_key`, and `meetup_id` for a meetup, kept for
    `meetupPushRoute` in current builds), and `delivery` (`mode`, `time_sensitive`, `android_channel_id`,
    `ios_category`, `thread_id` = `group_key`, `collapse_id` = `group_key` or its md5 when over 64 bytes, `badge` =
    the recipient's unread count after this row). Before v14, `data.entity_id` carried the notification id.
  * **Message snippet hook (for KAN-984):** for a `messages` kind the push body is the transaction-local setting
    `dabbler.push_body` when the producer sets it (`set_config('dabbler.push_body', snippet, true)` right before the
    insert). It is consumed once and never stored in `notifications`.
* **Android channel ids** (created on the device by KAN-992): `dabbler_social`, `dabbler_messages`, `dabbler_games`,
  `dabbler_meetups`, `dabbler_activities`, `dabbler_system`, `dabbler_security`, `dabbler_booking` (one per
  `notification_kinds.category`), `dabbler_quiet` (every quiet-hours push: low importance, no sound) and
  `dabbler_default` (direct calls to the edge function).
* **iOS categories** (`notification_push_category(kind)`, also sent as `data.category` so Android can build the same
  actions): `DABBLER_MESSAGE` (`message.received`: Reply, Mark as read), `DABBLER_RSVP` (`meetup.confirm_attendance`:
  Going, Not going), `DABBLER_WAITLIST` (`game.waitlist_promoted`: Cancel my place), `DABBLER_SECURITY`
  (`security.*`: no actions, hidden-preview lock screen), `DABBLER_DEFAULT` (everything else: Mark as read).
* **`send-push-notification` v14** (`verify_jwt` off, as before): the trusted lane (header `x-trigger-secret`
  matches `get_push_trigger_secret()`) and the direct lane (user JWT, rate limit, block check, `callerMayNotify`) are
  unchanged. Only the trusted lane honours `delivery` and `notification_id`, so a direct caller cannot ask for
  time-sensitive delivery or write delivery rows. Tokens are read by `device_platform` (KAN-977); `platforms` filters
  on `device_platform`. A token is pruned (by `fcm_tokens.id`) only on `unregistered` or `invalid_token`; a bare
  `INVALID_ARGUMENT` about the payload (`invalid_payload`) no longer deletes tokens.
* **`notification_deliveries`**: one row per device per push, written by v14 on the trusted lane: `notification_id`,
  `channel = 'push'`, `status` (`accepted` | `failed`; the 8 older rows stay `queued`), `provider_id` (the FCM message
  name), `error_class` (`unregistered`, `invalid_token`, `invalid_payload`, `sender_mismatch`, `apns_auth`, `quota`,
  `auth`, `unavailable`, `unknown`), `token_id` (FK `fcm_tokens`, SET NULL when the token is pruned),
  `device_platform`, `delivery_mode` (`alert` | `silent`), `time_sensitive`, `attempted_at`. **No token and no text.**
  `error` is legacy and not written. RLS: `nd_self_read` (the recipient reads their own rows), `nd_block_dml`.
  `anon` has no grant. The sequence `notification_deliveries_id_seq` is postgres and service_role only (it was `rwU`
  for anon and authenticated from the project default ACL).
* **Quiet-hours default 00:00-08:00 (F-14):** `notification_settings.quiet_start_min` / `quiet_end_min` default to
  0 / 480, and `is_quiet_hour` treats a user with no row as Asia/Dubai 00:00-08:00. Existing rows with NULL stay off.
* **Dispatch and re-push (KAN-979b, `20261117101852`).** `notification_push_dispatch(notification_id, repush)` holds the
  gate and payload described above; `trg_push_on_notification_insert` only calls it. `notification_repush(uuid)
  RETURNS void` (SECURITY DEFINER, service_role only) is the hook KAN-980's `flush_notification_aggregates` calls for a
  grouped row that grew: it re-sends the row's current title and body with collapse/thread id = `group_key`, so it
  replaces the group's earlier push, always silent (`dabbler_quiet`, iOS passive, never time-sensitive), under the same
  gate as the first push. A blocked push, a row without `group_key` or a missing id sends nothing and never raises.
  `data.repush` is `"true"` on a re-push and `"false"` otherwise. One `notification_deliveries` row per device, as for
  any push.
* **Grouped-kind templates read for one or many** (KAN-979b): `meetup.rsvp_interested` is "{actor} showed interest in
  {title}" / «اهتمام بـ {title} من {actor}»; the Arabic titles of `social.post_liked`, `post_reacted`, `comment_liked`,
  `followed` and `circle_joined` are noun phrases ("… من {actor}") so they agree with «سارة وشخصان آخران».


## 18. Notification aggregation: one growing row per group (KAN-980, 2026-11-17)

Migration `20261117100750_kan980_aggregation`. Live test `supabase/tests/notifications_v2/kan980_aggregation.sql`.
Decisions F-6, I-1, design G-01.

**Grouped kinds** (`notification_aggregation_rules`, all `aggregation_window_seconds = 3600`, `push_cap_seconds = 900`):

| kind | group_family | push on growth |
|---|---|---|
| `social.post_liked`, `social.post_reacted` | `post` (shared; a mixed group uses the `post_reacted` template) | yes |
| `social.comment_liked` | `comment` | yes |
| `social.followed` | `follow` | yes |
| `social.circle_joined` | `circle` | no push channel on the kind |
| `meetup.rsvp_interested` | `meetup_interested` | no (`push_enabled = false`, kind is in-app only; I-1) |

Comments and mentions have no rule (the `social.post_commented` rule is gone): they insert at once and are never
grouped. `min_actors_to_aggregate` is no longer read.

**Flow.** A grouped kind reaches `notify_v2`, which (after its active, block and mute checks) returns
`notification_aggregate_add(...)`.
- First actor: a real `notifications` row is inserted at once (`dedupe_key = 'agg:<aggregate id>'`,
  `group_key = '<family>:<entity_type>:<entity_id>'`), so `trg_push_on_notification_insert` sends the t0 push.
- Further actors within 1 hour of the first: the same row is updated in place: title from the kind template with
  `{actor}` = "<newest> and N others" (AR: "و N آخرين"), `args`, `context.actor_user_ids` / `total_count`,
  `is_read = false`, `read_at = NULL`, `created_at` = the event time (moves to the top). No insert, so no push.
- The same person again (including a like and a reaction on the same post) counts once.
- After the hour, the next actor starts a new row.

`notification_aggregates` (new columns): `group_key`, `kinds`, `args`, `lang`, `notification_id` (FK, on delete set
null), `push_enabled`, `push_pending`, `push_cap_seconds`, `last_push_at`, `push_count`, `repush_hook_calls`. Rows with
`notification_id IS NULL` are the pre-KAN-980 buffer (all flushed).

**15-minute cap.** `flush_notification_aggregates(p_now timestamptz DEFAULT now())`, cron
`flush_notification_aggregates_every_minute` (`* * * * *`). For each open group with `push_pending` and
`last_push_at <= p_now - push_cap_seconds` it calls **`public.notification_repush(p_notification_id uuid)`** (owned and
built by KAN-979: replace the group's push, collapse id = `group_key`, no sound) if that function exists, then sets
`last_push_at`. A group closes (`is_flushed`) when its window has ended and nothing is pending. Until KAN-979 creates
the hook, rows still grow in place but growth is not re-pushed.

**Senders (one per kind).** `fn_likes_notify`, `trg_post_reaction_notify`, `trg_profile_follow_notify`,
`trg_circle_join_notify` call `notify_v2`; new trigger `trg_meetup_rsvp_interested_notify` on `meetup_rsvps` sends
`meetup.rsvp_interested` to the organiser when a member marks Interested (not when the host approves a request into
Interested). `meetup.rsvp_interested` is active.

**Grants.** `flush_notification_aggregates`, `notification_aggregate_add`: postgres and service_role only. Tables:
anon has nothing; authenticated keeps SELECT (RLS: own groups; rules readable). No sequences (uuid keys).

## 19. Security notices: sign-in ledger, password and email change (KAN-985, 2026-11-17)

Migrations `20261117100746_kan985_security_notices` and `20261117102449_kan985b_security_notices_review_fixes` (PEER fixes). Live test `supabase/tests/notifications_v2/kan985_security_notices.sql`
(one DO block, rolled back; 39 checks, each positive paired with a negative control). Decisions F-16, CEO planning
answer "security notices: always on, cannot be muted, break through quiet hours", G-08, I conflict 2 ("Not me" signs
out that device only, no Face ID).

**Tables.**
- `security_sign_ins`: the sign-in ledger, one row per `auth.sessions` row (`session_id` unique, no FK so the row
  outlives a revoked session). Columns: `user_id`, `installation_id`, `platform`, `device_label`, `device_key`
  (version-free user-agent family, e.g. `web:chrome:macos`, `app:dabbler`; every other client is one family,
  `other:client` since KAN-985b; seeded rows keep their older `other:curl` style keys), `place_city`,
  `place_country` (always NULL: no IP-to-place source exists on this project), `signed_in_at`, `is_new_device`,
  `state` (`known` no notice, `new` notice sent, `confirmed` "This was me", `secured` "Not me"), `notification_id`,
  `confirmed_at`, `secured_at`. RLS: `authenticated` SELECT own rows only; no client writes; anon nothing.
  Seeded with the 776 sessions that existed at apply time, all `known`.
- `security_known_devices` (`user_id`, `kind` = `installation` | `agent`, `device_key`): control data (T-020).
  RLS on, no policy, no grant to anon or authenticated. Seeded with each user's user-agent families from
  `auth.sessions` (238 rows); no installation was seeded because every `fcm_tokens` row was still `legacy:*`.
- No IP is copied anywhere. No sequences (uuid keys).

**Detection.**
- `security_on_session_created` AFTER INSERT ON `auth.sessions`: a session row is created once per sign-in and never
  on a token refresh. It writes the ledger row and, when the user has history and the user-agent family is new,
  sends `security.new_signin`.
- `rpc_security_register_sign_in` (called by the app): binds the installation to the current session
  (`auth.jwt() ->> 'session_id'`); a first-seen installation of a user who already has one sends the notice.
- Baselines (KAN-985b): only an account created after ship (2026-11-17 10:07:46 UTC) is a silent first sign-in;
  an older account with no session history notifies. The first installation a user binds is silent only from a
  pre-ship (seeded) session row or a brand-new account; a fresh post-ship sign-in of an existing user notifies once.
- Cap: at most 3 `security.new_signin` notices per user per rolling hour; beyond that the ledger row is still
  `new` with `notification_id` NULL.
- `security_on_auth_user_updated` AFTER UPDATE OF `encrypted_password, email` ON `auth.users`: password change
  (except the first password of an account created in the last 24 h) and confirmed email change.
- All three send through `notify_v2`. Dedupe keys: `security.new_signin:<session_id>`,
  `security.password_changed:<user_id>:<txid>`, `security.email_changed:<user_id>:<txid>`. Both trigger bodies swallow
  errors (RAISE WARNING) so a failure can never block a sign-in or an auth update.
- Lock-screen text is the generic kind template (no device, no city); `args` carry `sign_in_id`, `device`,
  `platform`, `city`, `country`, `signed_in_at`, `state` for the inbox row. Entity: `security_sign_in` / ledger id.

**Client RPCs** (`authenticated`, SECURITY DEFINER, `search_path ''`):
- `rpc_security_register_sign_in(p_installation_id text, p_platform text = NULL, p_device_label text = NULL) → jsonb`
  `{sign_in_id, state, is_new_device}`; idempotent.
- `rpc_security_sign_ins(p_limit int = 50) → table` own rows newest first, with `is_current` and `is_active`.
- `rpc_security_confirm_sign_in(p_sign_in_id uuid) → jsonb {sign_in_id, state}`; refused (42501) from the session the
  row describes; marks the inbox row `args.state = 'confirmed'`, read.
- `rpc_security_not_me(p_sign_in_id uuid) → jsonb {sign_in_id, state, revoked_sessions, signed_out_installation,
  route_to_password_change: true}`; deletes the `auth.sessions` of that installation (or that one session for an
  unbound client), its `fcm_tokens` row and its known-device entry; never the caller's own session (22023).
  KAN-985b: when the target row is on the caller's own installation (ledger row of the current session), only that
  one old session is revoked; the token and the known entry stay, and the response has `kept_current_device: true`
  and `signed_out_installation: null`.
  Another user's row: P0002.

**Kinds.** `security.new_signin`, `security.password_changed`, `security.email_changed` active (`can_mute` false,
`breaks_quiet` true, priority high). Muting one is refused by `notification_settings_guard` (KAN-975).

## 20. Reminders: `notification_jobs`, the 24h / 09:00 / 2h / 30m ladder (KAN-983, 2026-11-17)

Migrations `20261117102448_kan983_reminders` and `20261117103719_kan983b_answer_attendance_eligibility` (PEER fix; applied 2026-11-17).
Probes: `supabase/tests/notifications_v2/kan983_reminders_probes.sql`. Rollback:
`supabase/schema/rollback/kan983_ROLLBACK_reminders.sql`. Replaces `schedule_game_reminders_for_user`, which is
dropped (it had no callers and wrote to a table that did not exist).

* **Ladder** (`reminder_rung_times(start, tz)`): 24h before; **09:00 on the event's local date** (`event_timezone`) only
  if that is earlier than 2h before; 2h before; 30m before. `expires_at` is the next rung's due time (the start for
  30m); a job not sent by then is skipped `expired`, never sent late. The 30m rung is never skipped and there is no
  `activity.starting_soon` kind.
* **Who** (`reminder_audience`): Going = an active `game_roster` row (any role) or `meetup_rsvps.status = 'going'`;
  Interested = `meetup_rsvps.status = 'interested'` (meetups only; games have no Interested). Kinds
  (`reminder_kind`): `game.reminder`; `meetup.reminder`; `meetup.confirm_attendance` for the Interested 09:00 rung.
* **`notification_jobs`**: one row per (user, event, `schedule_revision`, rung). `dedupe_key =
  'reminder:<user>:<event>:<rev>:<rung>'` is unique here and is the `notify_v2` dedupe key, so a replayed job writes
  no second notification. `status` pending → claimed (lease 2 min, `FOR UPDATE SKIP LOCKED`) → sent | skipped |
  failed (5 attempts, back-off `retry_at`). `skip_reason`: event_missing, event_cancelled, revision_changed, expired,
  started, not_participant, rung_disabled, not_written (kind inactive, muted or blocked), max_attempts. RLS on, no
  policy; table and sequence granted to `service_role` only.
* **Planning.** New AFTER triggers `trg_kan983_roster_reminders` (`game_roster`) and `trg_kan983_rsvp_reminders`
  (`meetup_rsvps`) call `reminder_plan_member(event, user)`: delete that person's pending jobs, plan the rungs still
  ahead for the current revision. So a late joiner gets no passed rungs; leave, removal (`left`, `kicked`, delete),
  `declined`, `cancelled` and "Not going" delete the pending jobs. A planner error is a WARNING, never a failed join.
  Re-plan on change: `reminder_sync_event_changes()` reads `event_changes` rows not yet stamped
  `consumed_by.w1_b5`, stamps them, and re-plans every event with a schedule change or an `is_cancelled` flip
  (`reminder_plan_event`). No trigger on `events`.
* **Sending.** Cron `kan983_reminders_worker` (`* * * * *`) runs `reminder_worker_run()`: sync, `reminder_jobs_claim`,
  then `reminder_job_process` per job. At send time it re-checks: event exists, not cancelled, same
  `schedule_revision`, not expired, not started, still Going/Interested, rung on in
  `notification_settings.reminder_rungs -> audience -> rung` (no row = on). It renders `{title}`, `{when}`, `{time}` in
  EN and AR and calls `notify_v2`. Reminders break quiet hours (`breaks_quiet`; delivery is KAN-979). Every worker and
  planner function takes `p_now` (default `now()`) so probes can walk the clock; all are `service_role` only.
* **The 09:00 card's answer.** `rpc_answer_meetup_attendance(p_meetup_id uuid, p_answer text) → text` (authenticated;
  definer on the caller's own row). `'going'`: refused like `rpc_meetup_rsvp` via `can_current_user_rsvp_meetup` (frozen `not_allowed`; not visible or blocked either way with the host `not_visible`; `cancelled`; `started`); otherwise Interested becomes Going if the meetup
  has a slot (else stays `'interested'`); later rungs stay. `'not_going'`: `rpc_meetup_rsvp(..., 'cancel')` →
  `'cancelled'`; pending jobs are deleted. Errors: 42501 no user, 22023 bad answer, P0001 `not_attending`,
  `not_found`, `cancelled`, `started`. The notification's `args.actions` is `["going","not_going"]`.
* **Kinds.** `game.reminder` title becomes `{title} starts {when}` / `تبدأ {title} {when}`; `meetup.reminder` and
  `meetup.confirm_attendance` are activated. `timing` records the rungs and the sender.

## 21. Membership notices: removal with reason, waitlist promotion, invites (KAN-982, 2026-11-17)

Migrations `20261117101222_kan982_membership_notices.sql` and `20261117102454_kan982b_removal_reason_optional.sql`.
Live test `supabase/tests/notifications_v2/kan982_membership_probes.sql` (33 checks, rolled back). Follow-up
`20261117162054_kan982c_untitled_event_titles.sql`: `kan982_notify` adds `title_en` / `title_ar` from
`kan981_event_title(event_id, lang)` (title, else "<Sport> game" / "مباراة <رياضة>", else "Your game" / "مباراتك") to
every game and meetup notice, so an untitled game (24 live on 2026-11-17) never renders "You were removed from".

* **Every membership notice is sent through `notify_v2`** via `kan982_notify` (definer, service_role only), which
  swallows a notice failure as a WARNING so a notice never rolls back the membership change. Dedupe keys are stable
  per domain transition: `game.removed:<roster id>:<left_at>`, `game.player_joined:<roster id>:first|rejoin:<previous
  left_at>`, `game.player_left:<roster id>:<left_at>`, `game.full:<game>:<join key>`,
  `game.waitlist_joined|waitlist_promoted:<game>:<profile>:<waitlist joined_at>`, `game.join_accepted|join_declined:
  <request id>`, `game.invite_<status>:<invite id>`, `meetup.removed|player_left:<rsvp id>:<updated_at>`.
* **One sender per kind.** Moved to notify_v2 with the old path removed in the same migration: `game.removed`
  (was `process_notification_event` in `rpc_remove_player`), `game.join_accepted` (was in `rpc_decide_join_request`),
  `game.waitlist_promoted` (trigger `trg_game_waitlist_promoted_notify` dropped; it fired on every waitlist delete),
  `game.player_joined` (the `game_join` branch of `fn_public_activities_notify` removed; `meetup_join` stays there).
  Activated here: `game.join_declined`, `game.invite_accepted/declined/withdrawn/expired`, `game.player_left`,
  `game.full`, `game.waitlist_joined`, `meetup.removed`, `meetup.player_left`. `breaks_quiet`: `game.removed`,
  `meetup.removed`, `game.waitlist_promoted`.
* **Removal reason (F-13), optional for now.** `rpc_remove_player(p_game_id, p_profile_id, p_reason text DEFAULT
  NULL)` and `rpc_meetup_remove_attendee(p_meetup_id, p_user_id, p_reason text DEFAULT NULL)`. The two-argument
  call shape the live app uses resolves to these functions. KAN-982 refused a missing reason (`reason_required`), which
  broke removal in the live app; `20261117102454_kan982b_removal_reason_optional` accepts a NULL or blank reason
  again. Over 500 chars is still refused (`reason_too_long`). The notice `args` carry `title`, `organiser` (the
  remover's display name, or `organiser_en/_ar` "The organiser" / «المنظّم») and, only when a reason was given,
  `reason` and `reason_line` (`': ' || reason`). Templates: "You were removed from {title}" /
  "{organiser} removed you{reason_line}" (AR "أزالك {organiser}{reason_line}"), so no reason means no reason line.
  * **TODO (KAN-982 follow-up):** the frontend ticket adds the required reason field to both removal flows and sends
    `p_reason`. After that build ships, a later migration restores `reason_required` for a NULL or blank reason in
    both functions. Until then a reasonless removal is allowed.
* **Meetup removal has its own status:** `meetup_rsvps.status = 'removed'` (added to `meetup_rsvps_status_check`);
  leaving stays `cancelled`. `rpc_meetup_remove_attendee` returns `'removed'` (was `'cancelled'`). A removed user can
  still RSVP again through `rpc_meetup_rsvp` (unchanged; as before with `cancelled`).
* **One promoter.** `trg_kan982_roster_after` (AFTER INSERT OR UPDATE OF status on `game_roster`) calls
  `kan982_promote_waitlist(game)` whenever an active non-host row becomes `left` or `kicked`, by any path. It promotes
  the first waitlisted person by `position` while the game has room, skips anyone who cannot be added (frozen,
  blocked), and does nothing once the game has started or is cancelled. `rpc_leave_game` and `rpc_remove_player`
  no longer promote inline; their return values (`left_promoted_waitlist`, `removed_promoted_waitlist`) are kept.
  Policy `roster_update_self_leave` was dropped: it was dead (`authenticated` has no UPDATE grant on `game_roster`),
  so leaving goes through the RPCs, and a promotion follows any leave that reaches the table.
* **The same trigger** notifies the host on every transition into `active` (first join and **re-join**; not when the
  host approved it himself), sends `game.full` to the host when the last place is taken, sends `game.player_left` to
  the host on `left` (not on `kicked`), and marks a pending invite for that player and game `accepted`.
* **`rpc_cancel_waitlist_place(p_game_id) → text`** (G-14, authenticated): an active non-host player gives up the
  place (`place_released`; the next person is promoted), or a waitlisted player leaves the waitlist
  (`waitlist_left`). Refused `started` once `start_at <= now()`, `cancelled`, `not_on_waitlist`. Nothing is recorded
  against the player. The host still gets `game.player_left`.
* **Invites:** `game_invites.status` gains `withdrawn`. `trg_kan982_game_invite_after_status` (pending → other):
  accepted / declined notify the inviter (`invited_by_profile_id`'s user, else the host); withdrawn / expired notify
  the invitee. New RPCs (authenticated): `rpc_decline_game_invite(p_invite_id)` (the invitee) and
  `rpc_withdraw_game_invite(p_invite_id)` (host, inviter or admin), both returning the new status or
  `already_<status>`. `expire_game_invites()` (service_role) expires pending invites to games that started or were
  cancelled; pg_cron job `kan982_expire_game_invites` runs it every 5 minutes. Accepting happens by joining.
* **Waitlist joined:** `trg_kan982_waitlist_after_insert` tells the player (`args.position`). An approved request on
  a full game now gets this notice instead of a "you're in" `game.join_accepted`.
* **Meetup participant left:** `trg_kan982_meetup_rsvp_left` (going → cancelled by the attendee) tells the host.

## 22. Meetup: "wants to come, but it's full" (KAN-1013, 2026-11-17)

Migration `20261117163717_kan1013_meetup_wants_to_join_full.sql`. Live test
`supabase/tests/notifications_v2/kan1013_wants_to_join_full_probes.sql`.

* A "Going" (or accept-invite) tap on a full meetup is still stored as `interested` by `rpc_meetup_rsvp`. Around that one
  write the RPC sets the transaction-local marker `dabbler.rsvp_full_downgrade` = meetup id and clears it right after.
* `trg_meetup_rsvp_interested_notify` (the one sender) sends **`meetup.wants_to_join_full`** to the organiser when the
  marker matches ("{actor} asked to come to {title}, but it's full" / "طلب حضور {title} من {actor}، لكنه مكتمل"; plural-safe
  for a grouped card, `20261117164151_kan1013b_wants_full_plural_safe`), and
  `meetup.rsvp_interested` otherwise (a real Interested, unchanged). Dedupe `meetup_rsvps:<rsvp id>:wants_full`.
* New kind: category `meetups`, in-app, priority low, mutable. Aggregation rule like Interested (3600 s window, push cap
  900 s, push off) but its own `group_family = 'meetup_wants_full'`, so the two cases never share a card.

## 23. Message notifications: sender, snippet, preview setting (KAN-984, 2026-11-17)

Migration `20261117164003_kan984_messaging_push_preview`. Live test `supabase/tests/notifications_v2/kan984_messaging_test.sql`.
Worker change (not deployed by the migration): `workers/messaging/src/notify.ts`.

* **One sender of `message.received`: `msg_notify_core(uid, conversation_id, seq, access_mode, snippet)`** (SECURITY
  DEFINER, service_role only). It writes through `notify_v2` (dedupe `message.received:<conversation>:<seq>`, group
  `conv:<conversation>`). The old direct INSERT is gone.
* **Entry points** (both SECURITY DEFINER): `msg_notify(uuid, bigint, text)` (EXECUTE for authenticated and
  service_role; what the deployed Worker calls; sender-only push) and the overload `msg_notify(uuid, bigint, text, text)`
  with `p_snippet`. KAN-984b (`20261117170659`) made it service_role only (a member could push text that is no
  message); **KAN-984c (`20261118052921`) grants it back to authenticated behind a MAC**: the snippet is kept only when
  the request header `x-msg-snippet-mac` equals lowercase-hex HMAC-SHA256(key, `<conversation uuid>:<seq>:<snippet>`),
  key = Vault secret `msg_snippet_hmac_key` = Worker secret `MSG_SNIPPET_HMAC_KEY` (values never in the repo). The check
  is `msg_snippet_verified(uuid, bigint, text)` (SECURITY DEFINER, postgres only, compares digests of both MACs, never
  raises). No header, a malformed MAC, no Vault key, or a MAC for another conversation, seq, text or key: the snippet is
  dropped and the push is sender-only; the notice is still sent. The Worker signs in `src/snippet_mac.ts` and sends
  the user's token unchanged. Live test `supabase/tests/notifications_v2/kan984c_snippet_mac.sql`. The overload has
  no defaults, so a 3-argument call resolves to the first.
* **Recipients:** a game chat's active roster (host, player, sub); a DM's two members; a meetup chat's organiser and
  every `meetup_rsvps` row with status `going`. Never the sender. Skipped: a member with `muted_at` on the
  conversation, a block in either direction, and (unchanged) a recipient who already has an unread `message.received`
  for the conversation from the last 2 minutes.
* **Text (F-2):** title `{actor}{in_group}`: the sender's name, or "Sender in Group" / «المرسل في المجموعة» for a game
  or meetup chat (the group name is the event title, not translated). The push body is the snippet when the
  recipient's `message_preview` is `sender_and_message` (default) and the kind's generic body under `sender_only`. The
  snippet is one line, at most 140 characters, and dropped when it hits `safety_blocklist_terms`.
* **The snippet is in no table row.** It reaches the push only through `dabbler.push_body` (set per recipient, cleared
  after), and sits transiently in the pg_net request row (`net.http_request_queue`) until pg_net sends it. `notification_push_dispatch` consumes that setting before any gate, so it cannot carry over to another row.
* **Push data** adds `conversation_id` and `game_id` or `meetup_id` (from the row's args) so the app can skip the
  alert for the open chat; the iOS category is `DABBLER_MESSAGE`. Message pushes are never time-sensitive and are
  silent in quiet hours.

## 19. Housekeeping and grants hygiene (KAN-986 W1-B8, KAN-1011, 2026-11-17)

Migration `20261117164404_kan986_housekeeping_grants`. Live test `supabase/tests/notifications_v2/kan986_housekeeping.sql`.

**Inbox retention (F-13, 90 days).**
- `notifications_retention_candidates(p_days = 90, p_now = now())` lists what would be deleted.
- `notifications_retention_run(p_days = 90, p_batch = 1000, p_max_batches = 50, p_now = now())` deletes it in
  batches. It refuses a period under 90 days.
- Both are SECURITY DEFINER; service_role only.
- **Kept whatever their age:**
  - an unread security notice;
  - `game.join_request` while its `game_join_requests` row is pending;
  - `game.invited`, `meetup.invited` and `squad.invited` while the invite is pending;
  - `meetup.request_received` while the requester's RSVP is pending.
- Friend-request kinds have no backing table (F-17) and are never kept.
- **Side effects of a delete:**
  - it cascades to `notification_deliveries`;
  - it sets `notification_aggregates.notification_id` and `security_sign_ins.notification_id` to NULL.
- **Cron:** `kan986_notifications_retention_daily` (`41 2 * * *`) was created INACTIVE. The first run is counted and
  approved on KAN-986 before it is switched on (`cron.alter_job(jobid, active := true)`).

**Cron run history.**
- `cron_job_run_details_prune(p_keep = '7 days', p_batch = 100000, p_max_batches = 10)` keeps 7 days. It refuses less
  than 1 day.
- Cron `kan986_prune_cron_run_details_hourly` (`23 * * * *`), command `SET statement_timeout = '15min'; SELECT public.cron_job_run_details_prune()`.
- Since `20261118052516_kan986c_prune_by_runid_ranges` (PEER 16482): the cutoff `runid` is found once by a binary search on the primary key, then rows are deleted in `runid` ranges of 10 000 (p_batch), at most 1000 ranges or 90 s per run. The first version's `IN (SELECT ... LIMIT)` scans timed out on the 2.3M-row backlog.

**Grants (KAN-1011).**
- **Sequences:** no public sequence grants anything to PUBLIC, anon or authenticated. Default privileges of `postgres`
  in `public`: new sequences give nothing to anon or authenticated, and new tables give them no MAINTAIN.
  `supabase_admin`'s default privileges (anon/authenticated `arwdDxtm` on tables, `rwU` on sequences, `X` on functions)
  cannot be changed by `postgres`.
- **RPCs:** every volatile `public.rpc_*` function lost EXECUTE for anon and PUBLIC. authenticated and service_role
  keep exactly what they had. There is one exception: 15 read-only RPCs stay executable by anon. They are
  `rpc_admin_submission_action_state`, `rpc_autocomplete_people`, `rpc_feed_ranked`, `rpc_get_activity_feed`,
  `rpc_meetup_card`, `rpc_my_venue_permissions`, `rpc_nearby_users`, `rpc_potential_vibes`, `rpc_profile_search`,
  `rpc_submission_approval_state`, `rpc_submission_audit_timeline`, `rpc_test_ping`, `rpc_unified_search_sectioned`,
  `rpc_username_availability` (called before sign-in) and `rpc_username_suggest`. `rpc_track_event(text,jsonb)` also keeps anon
  (KAN-109: `flags_snapshot` before sign-in; the function refuses any other event for anon). It was restored by
  `20261117165842_kan986b_track_event_anon` after PEER 16467.
- **MAINTAIN:** anon and authenticated have no MAINTAIN on any public relation, with these exceptions:
  - `notification_deliveries`: authenticated still has it. This table is out of bounds here and was reported on
    KAN-979.
  - PostGIS `spatial_ref_sys`, `geometry_columns` and `geography_columns`: granted by `supabase_admin`, so `postgres`
    cannot revoke them.
- **Notification objects:** anon has no grant on `notifications`, `notification_kinds`, `notification_scores`,
  `notification_user_preferences` or `notification_hourly_caps`. anon also has no EXECUTE on
  `mark_notification_read`, `render_notification`, `calculate_notification_rank`, `calculate_notification_score`,
  `can_send_notification_now`, `should_bypass_quiet_hours` or `allow_social_notifications`.
- **Kept for anon:** `next_quiet_exit` and `is_in_quiet_hours(timestamptz,text,integer,integer)`. Both are pure
  arithmetic with no user data.

## 23. Game invite notice (KAN-1017, 2026-11-17)

Migration `20261117171717_kan1017_game_invite_notify.sql`. Live test
`supabase/tests/notifications_v2/kan1017_game_invite_probes.sql`.

* `rpc_invite_user` stores the caller's profile in `game_invites.invited_by_profile_id`: the organiser profile, else
  the game's `creator_profile_id` when the caller created it, else the caller's oldest active profile. Before, only an
  organiser profile was stored, so most invites had NULL.
* `trg_game_invite_notify` (AFTER INSERT) sends `game.invited` through `notify_v2` only (via `kan982_notify`, so
  `title_en/_ar` come from `kan981_event_title`); actor = the inviter (profile's user, else the caller); a self-invite
  sends nothing; dedupe `game.invited:<invite id>`. The old `process_notification_event` call is gone.
* `game.invited` titles: "{actor} invited you to {title}" / "{actor} دعاك إلى {title}".
* No backfill: on 2026-11-17 the only invite was the QA device-test invite, left untouched.

## 24. One organiser notice per event: game.full per fill episode, invite accept (KAN-1018, 2026-11-17)

Migration `20261117174309_kan1018_full_once_invite_single.sql`. Live test
`supabase/tests/notifications_v2/kan1018_full_once_invite_single_probes.sql`.

* **`public.game_fill_episodes`** (`game_id` PK → games, `full_since`, `episode`, `updated_at`): server state written
  only by `kan982_roster_after`. RLS on, no policies, no `anon`/`authenticated` grant.
* `game.full` is sent when a join leaves the game with no slot **and no episode is open** (`full_since IS NULL`); the
  episode number goes up and the dedupe key is `game.full:<game>:episode:<n>`. A leave closes the episode only if a
  place is still open after the waitlist promotion step, so a leave refilled from the waitlist is the same episode.
  Edge: a capacity edit with no roster change does not move the episode (next roster change corrects it).
* A join that accepts a pending invite sends only `game.invite_accepted` (invite trigger); `game.player_joined` is
  skipped for that join.

---

## 25. Event lifecycle: optional Start, end confirmation, auto-close, "did not happen" (KAN-995, 2026-11-18)

Migration `20261118053016_kan995_event_lifecycle` (F-9; plan W2-B2). It is the KAN-994 attendance read contract.

**Tables (server only: RLS on, no policy, no client grant; the audit sequence is closed too)**
* `event_lifecycle`, one row per event, created on first use:
  * `state`: `scheduled` → `started` → `ended` | `auto_closed` | `did_not_happen`. The last three are closed and
    final; a closed event is not reopened.
  * `actual_started_at` / `started_by`, `actual_ended_at`, `closed_at` / `closed_by`;
  * `closed_reason`: `played`, `did_not_happen`, `time_ended`, or `pre_lifecycle` (seeded, see below);
  * `confirm_requested_at`, `reminder_sent_at`, and `end_revision`, the `events.schedule_revision` those two belong to;
  * `revision`, the transition counter.
* `event_lifecycle_transitions`: every transition with `from_state`, `to_state`, `actor_user_id`, `reason` and time.
* Cancellation stays on `events.is_cancelled`. A cancelled event gets no lifecycle step.

**Scheduled end:** `coalesce(end_at, start_at + 2h)`, so a meetup with no `end_at` ends 2h after its start.

**Organiser RPCs** (`authenticated`; the organiser is `events.creator_user_id`, or an admin):
* `rpc_event_start(p_event_id)`:
  * refused before the scheduled start, on a cancelled event, for anyone else, and on a closed event;
  * a repeat returns `already_started` with the same `actual_started_at`.
* `rpc_event_confirm_end(p_event_id, p_outcome)`, outcome `played` or `did_not_happen`:
  * the same refusals apply;
  * a repeat with the same outcome is idempotent; a different outcome on a closed event is `already_closed`;
  * `played` sends `activity.ended` to the participants (game: active roster; meetup: going), never to the organiser;
  * `did_not_happen` notifies nobody.

**Worker:** `kan995_lifecycle_worker(p_now)`, run by pg_cron job `kan995_lifecycle_every_minute`. It is not the
KAN-983 queue, whose checks only allow reminders.
* It looks at events that are not cancelled and not closed, whose scheduled end passed within the last day.
* At the end: `activity.confirm_end` to the organiser.
* At `max(end + 2h, request + 2h)`: `activity.confirm_end_reminder`.
* At `max(end + 4h, reminder + 2h)`: the state becomes `auto_closed` (`time_ended`), and the organiser gets
  `activity.auto_closed`. The `max()` spaces the steps out after an outage.
* **Reschedule:** a new `schedule_revision` resets the request and reminder, so all three steps follow the new end.
* **Dedupe keys:** `lifecycle:<step>:<event>:<revision>`.
* The 4 kinds are in category `activities`, with `breaks_quiet = false`.

**Read contract:** `event_lifecycle_state(p_event_id)` → `state`, `effective_end_at`, `scheduled_end_at`,
`actual_started_at`, `actual_ended_at`, `closed_at`, `closed_reason`.
* It is `service_role` only, and it returns `scheduled` when there is no row.
* `effective_end_at` = `actual_ended_at`, else the scheduled end.
* KAN-994's `attendance_lifecycle()` reads it, and only it: auto-finalize runs 24h after `effective_end_at`, and a
  `did_not_happen` event is finalized with no outcomes.

**Seed:** the 2 non-cancelled events whose scheduled end had passed within the last day of the migration got a quiet
closed row (`auto_closed` / `pre_lifecycle`, no notice).

**Not here:** attendance and no-show (KAN-994), the UI (W2-F5 / KAN-1002), and a client read of the lifecycle. The
app has no lifecycle read yet; W2-F5 needs one.

Live test: `supabase/tests/notifications_v2/kan995_event_lifecycle.sql`. Rollback:
`supabase/schema/rollback/kan995_ROLLBACK_event_lifecycle.sql`.
