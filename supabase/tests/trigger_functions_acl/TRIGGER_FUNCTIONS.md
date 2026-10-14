# KAN-527: trigger functions in schema public that PUBLIC or anon can execute

Status: AUTHORED from the KAN-498 sweep and the repo. Nothing was measured live by this team and nothing was run against any database.

## Source and count

* **Source: the KAN-498 sweep**, `ANON_GRANT_SWEEP.md` (live catalog of project wtncuzcskpigqpmnxwws, measured 2026-10-13 10:46-10:50 UTC; Table A rows whose recommendation reads "trigger function: not usable as an RPC"). The sweep says 174 of the 594 anon-executable non-extension functions return `trigger`. **173 are listed here; the 174th is `public.notify_admins_of_block()`, owned by KAN-523 (migration `20261013140000`) and deliberately left out.** 173 + 1 = 174.
* The sweep file was readable, so the catalog fallback query was not needed. If Memphis's live count differs, record it; the migration is exactly the table below. Probe A1 re-derives the live list read-only and A1 raises if a function the migration names does not return `trigger`.
* Every listed function takes no arguments: `public.<name>()`. The one name the sweep prints with a bracket (a word that would trip a secrets grep) is written here in full as `strip_signup_password`; it is a trigger on `auth.users` and is `public.strip_signup_password()` in the baseline (`supabase/migrations/20260829080500_baseline_schema.sql:17218`).
* Each name was checked against the repo: every one is defined as `RETURNS "trigger"` in `supabase/migrations`.

## Evidence for the stop conditions

| Check | Result |
|---|---|
| `git grep -n -w <name> -- lib supabase/functions workers scripts tests integration_test` for each of the 173 names | 3 hits, all comments: `lib/data/models/profile_location.dart:38` (`fn_sync_geo_fields` in a doc comment), `lib/features/notifications/data/models/notification_settings.dart:14` and `supabase/functions/send-push-notification/index.ts:63` (`trg_push_on_notification_insert`, the trigger name, not a call), `lib/features/profile/presentation/screens/profile_edit_screen.dart:899` (`trgfn_set_sport_profile_sport_id` in a comment). **No `.rpc(` or function-invoke call.** |
| `workers/` | does not exist on Alpha |
| any `msg_*` function, any KAN-499 or KAN-505..518 function in the list | none |
| `notify_admins_of_block` in the list | no (KAN-523) |
| non-trigger function in the list | none: all 173 are `RETURNS trigger` in the repo; probe A1 re-checks live |

## Current ACL

**Live read recorded.** Memphis read the live `proacl` of all 173 functions, read-only, on 2026-10-14 against project `wtncuzcskpigqpmnxwws` (every statement `begin read only; select ...; rollback;`; nothing written, migration not applied). Evidence file beside this one: `LIVE_PROACL_EVIDENCE.md` (a verbatim copy of `/Users/moataz/Desktop/Dabbler-Alpha-Plan/kan-grant-sweep/KAN-527_live_proacl.md`, which also holds the 173 live rows). Result:

* **173 of 173 listed functions exist live**; none missing; none is not `RETURNS trigger`; no same-name function with another arity.
* **0 differences** between the live `proacl` and the "Expected current proacl" column below. Owner `postgres` for all 173; 49 SECURITY DEFINER (matches the Type column: 49 DEFINER, 124 INVOKER).
* Live groups: 172 PUBLIC only, 1 (`trg_welcome_notify`) PUBLIC plus explicit anon, authenticated, service_role; `anon_exec`, `authenticated_exec`, `service_exec` true for all 173 through the PUBLIC grant.
* **Known exclusions, not revoked, out of scope:** `public.checkauthtrigger()` and `public.postgis_cache_bbox()` (PostGIS extension functions owned by `supabase_admin`, which `postgres` may not revoke), `realtime.subscription_check_filters()` (Supabase-managed), and the `storage` trigger functions (`enforce_bucket_lifecycle_service_role`, `enforce_bucket_name_length`, `protect_bucket_control_columns`, `protect_delete`, `update_updated_at_column`; Supabase-managed). Live `public` has 180 trigger functions = 173 listed + 2 PostGIS + 5 already closed to anon (`notify_admins_of_block()`, applied by KAN-523, `fn_activity_favorites_sync_legacy_v1`, `trg_meetup_rsvps_notify`, `trg_meetups_cancel_notify`, `trgfn_charges_immutable`).

The per-function column below keeps the expected ACL (sweep grant source plus baseline grants); the live read confirmed every row. The sweep's 174th, `notify_admins_of_block()`, is closed live by KAN-523.

* PUBLIC only: `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` (172)
* PUBLIC and explicit anon, authenticated, service_role: `{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` (1: `public.trg_welcome_notify()`)

## Functions (173)

| # | Function | Type | Granted via (sweep) | Expected current proacl | Trigger on / note (sweep) |
|---|---|---|---|---|---|
| 1 | `public._set_updated_at()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on posts; migr: 1 file(s) |
| 2 | `public._set_updated_at_simple()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 3 | `public._touch_updated_at()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on moderation_tickets, notification_deliveries (+4); migr: 1 file(s) |
| 4 | `public._wallet_after_ledger()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on wallet_ledger; migr: 2 file(s) |
| 5 | `public.audit_venue_submission_change()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on venue_submissions; migr: 1 file(s) |
| 6 | `public.challenges_search_tsv_trigger()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on challenges; migr: 1 file(s) |
| 7 | `public.create_default_privacy_settings()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on auth.users; migr: 1 file(s) |
| 8 | `public.enforce_single_level_reply()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on comments; migr: 1 file(s) |
| 9 | `public.enforce_single_visibility_scope()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on post_circles, post_squads; migr: 1 file(s) |
| 10 | `public.fn_activity_log_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on public_activities; migr: 1 file(s) |
| 11 | `public.fn_feed_items_fanout()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on public_activities; migr: 1 file(s) |
| 12 | `public.fn_game_roster_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_roster; migr: 1 file(s) |
| 13 | `public.fn_games_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 1 file(s) |
| 14 | `public.fn_games_inherit_geo()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 1 file(s) |
| 15 | `public.fn_games_sync_joining_rule()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 1 file(s) |
| 16 | `public.fn_likes_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on likes; migr: 1 file(s) |
| 17 | `public.fn_likes_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on likes; migr: 1 file(s) |
| 18 | `public.fn_meetup_rsvps_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on meetup_rsvps; migr: 3 file(s) |
| 19 | `public.fn_meetups_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on meetups; migr: 1 file(s) |
| 20 | `public.fn_meetups_enforce_solo_sport()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on meetups; migr: 1 file(s) |
| 21 | `public.fn_meetups_inherit_geo()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on meetups; migr: 1 file(s) |
| 22 | `public.fn_meetups_sync_joining_rule()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on meetups; migr: 2 file(s) |
| 23 | `public.fn_news_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on news; migr: 1 file(s) |
| 24 | `public.fn_normalize_area_location()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on areas; migr: 1 file(s) |
| 25 | `public.fn_post_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on posts; migr: 1 file(s) |
| 26 | `public.fn_post_comments_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on comments; migr: 1 file(s) |
| 27 | `public.fn_post_reactions_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on reactions; migr: 1 file(s) |
| 28 | `public.fn_post_reposts_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on post_reposts; migr: 1 file(s) |
| 29 | `public.fn_profile_follows_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profile_follows; migr: 1 file(s) |
| 30 | `public.fn_public_activities_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on public_activities; migr: 2 file(s) |
| 31 | `public.fn_set_updated_at()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profile_locations; migr: 1 file(s) |
| 32 | `public.fn_sync_geo_fields()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games, meetups (+2); migr: 1 file(s) |
| 33 | `public.fn_user_badges_activity_sync()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on user_badges; migr: 1 file(s) |
| 34 | `public.handle_game_created()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 1 file(s) |
| 35 | `public.handle_player_joined_game()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_roster; migr: 1 file(s) |
| 36 | `public.handle_post_created()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on posts; migr: 1 file(s) |
| 37 | `public.handle_user_created()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 38 | `public.hashtags_search_tsv_trigger()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on hashtags; migr: 1 file(s) |
| 39 | `public.increment_post_view()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on post_views; migr: 1 file(s) |
| 40 | `public.increment_repost_count()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 41 | `public.meetups_search_tsv_trigger()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on meetups; migr: 1 file(s) |
| 42 | `public.notify_admins_of_report()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on moderation_reports; migr: 1 file(s) |
| 43 | `public.post_comments_search_tsv_trigger()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on comments; migr: 1 file(s) |
| 44 | `public.posts_primary_vibe_check()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 45 | `public.set_current_timestamp_updated_at()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on hashtags; migr: 1 file(s) |
| 46 | `public.set_default_avatar()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 47 | `public.set_geohash_before_insert()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on geo_locations; migr: 1 file(s) |
| 48 | `public.set_post_author()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on posts; migr: 1 file(s) |
| 49 | `public.set_updated_at()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 50 | `public.strip_signup_password()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on auth.users; migr: 1 file(s) |
| 51 | `public.sync_game_geo()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 52 | `public.sync_reaction_breakdown()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on reactions; migr: 1 file(s) |
| 53 | `public.touch_updated_at()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games, meetup_attendees (+3); migr: 1 file(s) |
| 54 | `public.trg_after_game_rating_event()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_rating_events; migr: 1 file(s) |
| 55 | `public.trg_after_reputation_event()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on user_reputation_events; migr: 1 file(s) |
| 56 | `public.trg_after_venue_rating_event()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on venue_rating_events; migr: 1 file(s) |
| 57 | `public.trg_arenas_set_search_tsv()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 58 | `public.trg_assign_sport_profile_tier()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sport_profiles; migr: 1 file(s) |
| 59 | `public.trg_badge_awarded_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | fn: fn_public_activities_notify; trigger on user_badges; migr: 1 file(s) |
| 60 | `public.trg_booking_payment_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 61 | `public.trg_circle_join_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on circle_members; migr: 2 file(s); revoke seen in 20260911105434_kan182_process_notification_event_contain_and_definer_trg_circle_join_notify.sql |
| 62 | `public.trg_comment_mention_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on comment_mentions; migr: 1 file(s) |
| 63 | `public.trg_fn_games_inherit_sport_from_space()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 1 file(s) |
| 64 | `public.trg_fn_games_inherit_venue_geo()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 1 file(s) |
| 65 | `public.trg_fn_games_require_challenge_sport()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 2 file(s) |
| 66 | `public.trg_fn_venues_set_geo()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 67 | `public.trg_friend_request_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on friend_requests_audit; migr: 1 file(s) |
| 68 | `public.trg_game_invite_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_invites; migr: 1 file(s) |
| 69 | `public.trg_game_join_request_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_join_requests; migr: 2 file(s) |
| 70 | `public.trg_game_updated_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 2 file(s) |
| 71 | `public.trg_game_waitlist_promoted_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_waitlist; migr: 1 file(s) |
| 72 | `public.trg_games_set_search_tsv()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 1 file(s) |
| 73 | `public.trg_hashtag_increment()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on post_hashtags; migr: 1 file(s) |
| 74 | `public.trg_meetup_invite_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on meetup_invites; migr: 2 file(s) |
| 75 | `public.trg_news_comment_count()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 76 | `public.trg_news_like_count()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 77 | `public.trg_post_comment_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | fn: fn_public_activities_notify; trigger on comments; migr: 1 file(s) |
| 78 | `public.trg_post_mention_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on post_mentions; migr: 1 file(s) |
| 79 | `public.trg_post_reaction_breakdown()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on reactions; migr: 1 file(s) |
| 80 | `public.trg_post_reaction_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | fn: fn_public_activities_notify; trigger on reactions; migr: 1 file(s) |
| 81 | `public.trg_post_search_refresh()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on posts; migr: 1 file(s) |
| 82 | `public.trg_post_search_refresh_from_vibes()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 83 | `public.trg_post_vibes_check()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 84 | `public.trg_posts_primary_vibe_check()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 85 | `public.trg_profile_follow_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | fn: fn_public_activities_notify; trigger on profile_follows; migr: 1 file(s) |
| 86 | `public.trg_profiles_search_tsv()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 87 | `public.trg_push_on_notification_insert()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | edge: supabase/functions/send-push-notification/index.ts:63; trigger on notifications; migr: 3 file(s) |
| 88 | `public.trg_scan_post()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 89 | `public.trg_set_updated_at()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on news; migr: 1 file(s) |
| 90 | `public.trg_spaces_legacy_name_sync()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on venue_spaces; migr: 1 file(s) |
| 91 | `public.trg_sport_profiles_form()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sport_profiles; migr: 1 file(s) |
| 92 | `public.trg_sport_profiles_level_event()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sport_profiles; migr: 1 file(s) |
| 93 | `public.trg_sport_profiles_overall_level()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sport_profiles; migr: 1 file(s) |
| 94 | `public.trg_sport_profiles_reliability()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sport_profiles; migr: 1 file(s) |
| 95 | `public.trg_sport_profiles_verification_event()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sport_profiles; migr: 1 file(s) |
| 96 | `public.trg_sport_profiles_xp()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sport_profiles; migr: 1 file(s) |
| 97 | `public.trg_squad_invite_notify()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on squad_invites; migr: 1 file(s) |
| 98 | `public.trg_squads_owner_default()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on squads; migr: 1 file(s) |
| 99 | `public.trg_squads_owner_defaults()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on squads; migr: 1 file(s) |
| 100 | `public.trg_squads_set_search_tsv()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on squads; migr: 1 file(s) |
| 101 | `public.trg_ticket_from_comment_report()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 102 | `public.trg_touch_updated_at()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on badges, challenge_fixtures (+12); migr: 1 file(s) |
| 103 | `public.trg_validate_circle_member()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on circle_members; migr: 1 file(s) |
| 104 | `public.trg_venues_set_search_tsv()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on venues; migr: 1 file(s) |
| 105 | `public.trg_welcome_notify()` | DEFINER | both | `{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 106 | `public.trgfn_block_follow_if_blocked()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profile_follows; migr: 1 file(s) |
| 107 | `public.trgfn_block_hoster_social()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profile_follows; migr: 1 file(s) |
| 108 | `public.trgfn_block_legacy_persona_updates()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 109 | `public.trgfn_block_profile_skill_level_updates()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 110 | `public.trgfn_block_profile_type_updates()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 111 | `public.trgfn_block_profile_verified_updates()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 112 | `public.trgfn_block_variant_as_sport()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sports; migr: 1 file(s) |
| 113 | `public.trgfn_challenges_outbox()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on challenges; migr: 1 file(s) |
| 114 | `public.trgfn_games_block_frozen()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 1 file(s) |
| 115 | `public.trgfn_games_set_host_user()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on games; migr: 3 file(s) |
| 116 | `public.trgfn_host_profile_persona_guard()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on host; migr: 1 file(s) |
| 117 | `public.trgfn_invite_block_frozen()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_invites; migr: 1 file(s) |
| 118 | `public.trgfn_invite_block_frozen_guard()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_invites; migr: 1 file(s) |
| 119 | `public.trgfn_invite_recipient_not_frozen()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_invites; migr: 1 file(s) |
| 120 | `public.trgfn_joinreq_block_frozen()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_join_requests; migr: 1 file(s) |
| 121 | `public.trgfn_joinreq_block_frozen_guard()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_join_requests; migr: 1 file(s) |
| 122 | `public.trgfn_joinreq_set_user()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_join_requests; migr: 1 file(s) |
| 123 | `public.trgfn_limit_active_profiles()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 124 | `public.trgfn_meetups_outbox()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on meetups; migr: 2 file(s) |
| 125 | `public.trgfn_norm_game_scores()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_rating_events; migr: 1 file(s) |
| 126 | `public.trgfn_norm_venue_scores()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on venue_rating_events; migr: 1 file(s) |
| 127 | `public.trgfn_organiser_profile_persona_guard()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on organiser; migr: 2 file(s) |
| 128 | `public.trgfn_payment_to_ledger()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on payment_intents; migr: 6 file(s) |
| 129 | `public.trgfn_player_profile_persona_guard()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on player; migr: 1 file(s) |
| 130 | `public.trgfn_posts_enforce_author_refs()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on posts; migr: 1 file(s) |
| 131 | `public.trgfn_posts_fill_author_display_name()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on posts; migr: 1 file(s) |
| 132 | `public.trgfn_posts_set_geo()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on posts; migr: 1 file(s) |
| 133 | `public.trgfn_posts_sync_author_display_name()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on posts; migr: 1 file(s) |
| 134 | `public.trgfn_posts_sync_author_user()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 135 | `public.trgfn_prevent_inactive_sport_usage()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on venue_spaces; migr: 1 file(s) |
| 136 | `public.trgfn_profiles_propagate_display_name()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 137 | `public.trgfn_profiles_username_hist()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 138 | `public.trgfn_rewards_from_outbox()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 139 | `public.trgfn_roster_block_frozen()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_roster; migr: 1 file(s) |
| 140 | `public.trgfn_roster_block_frozen_guard()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_roster; migr: 1 file(s) |
| 141 | `public.trgfn_roster_set_user()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_roster; migr: 1 file(s) |
| 142 | `public.trgfn_roster_set_user_and_guard()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_roster; migr: 1 file(s) |
| 143 | `public.trgfn_set_badge_sport_id()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on badges; migr: 1 file(s) |
| 144 | `public.trgfn_set_challenge_sport_id()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on challenges; migr: 1 file(s) |
| 145 | `public.trgfn_set_point_ledger_sport_id()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on point_ledger; migr: 1 file(s) |
| 146 | `public.trgfn_set_post_sport_id()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on posts; migr: 1 file(s) |
| 147 | `public.trgfn_set_sport_profile_sport_id()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sport_profiles; migr: 1 file(s) |
| 148 | `public.trgfn_set_sppb_sport_id()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sport_profile_profile_badges; migr: 1 file(s) |
| 149 | `public.trgfn_set_squad_sport_id()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on squads; migr: 1 file(s) |
| 150 | `public.trgfn_set_user_badge_sport_id()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on user_badges; migr: 1 file(s) |
| 151 | `public.trgfn_set_venue_space_capacity()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on venue_spaces; migr: 1 file(s) |
| 152 | `public.trgfn_set_venue_space_sport_id()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on venue_spaces; migr: 1 file(s) |
| 153 | `public.trgfn_sport_profiles_sync()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on sport_profiles; migr: 1 file(s) |
| 154 | `public.trgfn_squad_members_outbox()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on squad_members; migr: 1 file(s) |
| 155 | `public.trgfn_sync_age_gender_across_profiles()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 156 | `public.trgfn_touch_updated_at()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 157 | `public.trgfn_validate_persona_compatibility()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 158 | `public.trgfn_validate_setup_variant()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 159 | `public.trgfn_validate_sports_ref_arrays_v2()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 160 | `public.trgfn_waitlist_block_frozen()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_waitlist; migr: 1 file(s) |
| 161 | `public.trgfn_waitlist_block_frozen_guard()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_waitlist; migr: 1 file(s) |
| 162 | `public.trgfn_waitlist_set_user()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on game_waitlist; migr: 1 file(s) |
| 163 | `public.update_fcm_tokens_updated_at()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on fcm_tokens; migr: 1 file(s) |
| 164 | `public.update_hashtag_searchability()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on hashtags; migr: 1 file(s) |
| 165 | `public.update_last_seen()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on profiles; migr: 1 file(s) |
| 166 | `public.update_post_comment_count()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on comments; migr: 1 file(s) |
| 167 | `public.update_post_like_count()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 168 | `public.update_privacy_settings_timestamp()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on privacy_settings; migr: 1 file(s) |
| 169 | `public.update_repost_count()` | DEFINER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on post_reposts; migr: 1 file(s) |
| 170 | `public.update_updated_at_column()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on user_check_ins; migr: 1 file(s) |
| 171 | `public.validate_hoster_persona()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 172 | `public.validate_post_scope()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | none found in app, edge, catalog; migr: 1 file(s) |
| 173 | `public.validate_venue_submission_status()` | INVOKER | PUBLIC only | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | trigger on venue_submissions; migr: 1 file(s) |
