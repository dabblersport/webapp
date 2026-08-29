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

**`games` is the consequential one.** It is the core domain table, it has no policies, and
`lib/features/games/data/datasources/supabase_games_datasource.dart` issues 20 direct
`.from(gamesTable)` queries against it. Every one returns nothing. The live game path
avoids this by reading the `v_game_card` view and calling RPCs instead.

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
| definer + anon-granted, returns rows | **2** | **CORRECTED 2026-08-28 — `v_game_card` (216 rows) and `v_meetup_list` (1 row) are readable by `anon`.** Not an RLS bypass of private data — both return only `listing_visibility = 'public'` rows — but both expose `creator_user_id`, `creator_username`, `creator_display_name`, `creator_avatar_url`, start time and venue to an unauthenticated caller. See SEC-15 |
| definer + anon-granted, returns 0 | 6 | Empty for `anon`, **verified by query, not by reading the definition** |
| anon-revoked | 23 | `anon` has no SELECT grant — safe by grant |
| invoker | 21 | `security_invoker = true` — the underlying table's RLS applies |
| **Total** | **71** | |

**Every view has a stated position. That is the point of this section** — the previous
version gave counts without a per-view verdict, and that gap is exactly why two live leaks
went unnoticed.

### 2a. EXPOSED — 19 views readable by `anon` with no uid predicate

**Confirmed leaking real user data — CRITICAL:**

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
| `v_mod_queue_open` | **9** | `reporter_username`, `target_username`, `reason`, `details`, `target_user_id` — 7 reports on posts, 2 on users, all `status = 'open'` | **CRITICAL, OPEN.** **This deanonymises reporters to the people they reported.** Worse in kind than a data leak: it is a safety risk to the reporter, and the moderation screen is correctly gated (`moderation_queue_screen.dart:22`) while the data behind it is not. `SEC-03` |
| `v_circle_feed` | **6** | `author_user_id` (auth UUID), `author_display_name`, `body`, `circle_name` — **all 6 rows are `visibility = 'circle'` inside `circle_type = 'private'`** | **CRITICAL, OPEN.** Private circle posts readable with no account. **Not the `v_game_card` public-listing class** — nothing here was marked public by anyone |
| `v_safety_overview` | **1** | `reports_open`, `active_enforcements`, `takedowns_active`, `audits_24h` | **HIGH, OPEN.** Aggregate only, no per-user rows — the moderation posture of the platform, readable by anyone. Lower than the other two because it names nobody. `SEC-02` |

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
| `v_potential_vibes_default` | granted | no | **0** | **Intentionally public — `T-027`.** Function-backed: `security_invoker` is a **no-op** when the `FROM` is a set-returning function; access control lives inside the function. Probed, not assumed |
| `v_recreate_quickpicks` | granted | no | **0** | **Intentionally public — `T-027`.** Same mechanism |
| `username_registry_public` | granted | no | **0** unfiltered | **Intentionally public — `T-027`.** Backs signup username availability and **must answer before a session exists**; it is a lookup queried with a predicate |
| `v_space_slots_today` | granted | no | **errors** | **Not a security finding — `BUG-05`.** `find_slots()` references the dropped `public.venue_opening_hours` and raises 42P01 for **every** role including `postgres`. Needs its own ticket |

**Where the earlier guesses landed.** The old note guessed `v_comments`, `v_game_rating` and
`v_user_badges_summary` were "probably public". **One of three.** `v_comments` is public and
was also leaking one row; the other two had their `anon` grant revoked outright. That is the
case for the rule the note stated and did not follow — a guess about intent is not a verdict,
and two of these three would have been left open on a plausible-sounding hunch.

See `DECISIONS.md` `T-027` for the five views confirmed intentionally public, and §2d for the
reconciled aggregate counts.

**Not a finding — PostGIS extension metadata:** `geography_columns`, `geometry_columns`.
They describe geometry columns, hold no application data, and are owned by the extension.
They are in the 19 by measurement and excluded from the work.

**Arithmetic, reconciled 2026-08-29: 19 exposed → 2 PostGIS → 17 app views needing a verdict.**
**14 are closed or accounted for. 3 remain open and leaking** (`v_mod_queue_open`,
`v_circle_feed`, `v_safety_overview`) — see the top of this section. The earlier claim that all
17 were resolved was wrong by exactly those three.
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
anon-exposed at all, though §2a above still describes them as CRITICAL/OPEN, written earlier
the same day; that discrepancy is master-analyst's/cto's to reconcile in prose, not
version-control's, and is flagged in the KAN-61 handoff rather than silently fixed here).
Every name below was independently confirmed `anon`-readable with no
`security_invoker` at generation time:

* `geography_columns`, `geometry_columns` — PostGIS system views, allowlisted from the start
  per the KAN-61 ticket text, never a finding.
* `username_registry_public` — intentionally public, `T-027` (signup username availability,
  must answer pre-session).
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

**Adding a name here without one of these justifications is exactly the review conversation
`T-002` exists to force — don't add one to make the gate pass without checking why it is
newly anon-readable.**

<!-- ANON_ALLOWLIST_START -->
geography_columns
geometry_columns
username_registry_public
v_challenge_card
v_game_card
v_meetup_list
v_my_games
v_potential_vibes_default
v_rateable_after_game
v_recreate_candidates
v_recreate_quickpicks
v_space_slots_today
<!-- ANON_ALLOWLIST_END -->

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
`rpc_meetup_rsvp` ×2 · `rpc_potential_vibes` ×2 (one takes `p_me`) ·
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
`rpc_meetup_visible`, `rpc_meetup_invite_user`, `rpc_meetup_set_attendee`, `rpc_meetup_unrsvp`
**Social:** `rpc_create_post`, `rpc_delete_post`, `rpc_add_comment`, `rpc_toggle_like`,
`rpc_repost_post`, `rpc_hide_post`, `rpc_report_post`, `rpc_feed_ranked`,
`rpc_trending_posts`, `rpc_search_posts`, `rpc_toggle_post_vibe`, `rpc_set_post_primary_vibe`
**Friends:** `rpc_friend_request_send/accept/reject`, `rpc_friend_remove`, `rpc_friend_unfriend`,
`rpc_friend_requests_inbox/outbox`, `rpc_get_friends`, `rpc_get_friend_suggestions`,
`rpc_get_friendship_status`
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
`rpc_username_suggest`, `rpc_ban_username`, `rpc_ban_display_name`, `list_active_usernames`
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
**Search:** `rpc_search_entities`, `rpc_search_users`, `rpc_unified_search_sectioned`,
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
