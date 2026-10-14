<!-- Copied verbatim from the Memphis read-only evidence file
     /Users/moataz/Desktop/Dabbler-Alpha-Plan/kan-grant-sweep/KAN-527_live_proacl.md (2026-10-14, project wtncuzcskpigqpmnxwws).
     Recorded here for KAN-527 check C6; nothing in this file was produced by the authoring team. -->

# KAN-527: live proacl of the trigger functions the ticket will revoke (reviewer's C6)

Read: 2026-10-14, project `wtncuzcskpigqpmnxwws` only. **READ-ONLY.** Every statement was `begin read only; select ...; rollback;` (catalog rows only: `pg_proc`, `pg_namespace`, `pg_depend`, `pg_extension`). **Nothing was written to or applied on the database.** The KAN-527 migration was NOT applied.

Source read with `git show` (nothing checked out into the CEO folder): `origin/alpha-deir-el-bahari` at **`5ba25c34`** (latest KAN-527 commit; before it `b4900ceb`, `02ef0f17`):
`supabase/tests/trigger_functions_acl/probes.sql` block A2 and `TRIGGER_FUNCTIONS.md` (173 expected values); migration `supabase/migrations/20261013135000_revoke_public_anon_trigger_functions.sql`.

Method: the A2 query's exact function list (`public`, `pronargs = 0`, `proname = any(array[...173 names...])`) with signature, `proacl`, `anon_exec`, `public_grants` (plus authenticated/service flags and owner), compared inside the database against the expected `proacl` of `TRIGGER_FUNCTIONS.md`. Before running, I checked locally that the A2 list, the `TRIGGER_FUNCTIONS.md` table and the migration name the **same 173 functions** (173 unique in each; sets equal) and that the expected column has exactly two values (172 x PUBLIC-only, 1 x `trg_welcome_notify`).

## Result: live matches expected for all 173

| Check | Result |
|---|---|
| Functions in the list that exist live (`public.<name>()`, 0 args) | **173 of 173** |
| Listed functions that do NOT exist live | **none** |
| Listed functions whose live `proacl` differs from `TRIGGER_FUNCTIONS.md` | **none (0 differences)** |
| Listed functions that are not `RETURNS trigger` live | **none** |
| Same name with other arity in `public` | **none** |
| Owner | `postgres` for all 173 |
| Security definer | 49 of 173 (48 in the PUBLIC-only group + `trg_welcome_notify`); matches the `.md` (49 DEFINER, 124 INVOKER) |
| `anon_exec` / `authenticated_exec` / `service_exec` | true / true / true for all 173 (PUBLIC grant) |
| `public_grants` (grantee 0 in `proacl`) | 1 for all 173 |

### Live `proacl` groups (lossless: every function is in exactly one group)

| Group | n | Live proacl | anon | auth | service | public_grants |
|---|---|---|---|---|---|---|
| PUBLIC only | 172 | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | true | true | 1 |
| PUBLIC + explicit anon/authenticated/service_role | 1 (`trg_welcome_notify`) | `{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` | true | true | true | 1 |

### Live rows, one per function (generated from the group result above; the group query returned the 173 names, each in one of the two groups)

| # | Function | Live proacl | anon_exec | public_grants | Owner | Returns |
|---|---|---|---|---|---|---|
| 1 | `public._set_updated_at()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 2 | `public._set_updated_at_simple()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 3 | `public._touch_updated_at()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 4 | `public._wallet_after_ledger()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 5 | `public.audit_venue_submission_change()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 6 | `public.challenges_search_tsv_trigger()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 7 | `public.create_default_privacy_settings()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 8 | `public.enforce_single_level_reply()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 9 | `public.enforce_single_visibility_scope()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 10 | `public.fn_activity_log_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 11 | `public.fn_feed_items_fanout()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 12 | `public.fn_game_roster_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 13 | `public.fn_games_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 14 | `public.fn_games_inherit_geo()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 15 | `public.fn_games_sync_joining_rule()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 16 | `public.fn_likes_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 17 | `public.fn_likes_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 18 | `public.fn_meetup_rsvps_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 19 | `public.fn_meetups_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 20 | `public.fn_meetups_enforce_solo_sport()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 21 | `public.fn_meetups_inherit_geo()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 22 | `public.fn_meetups_sync_joining_rule()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 23 | `public.fn_news_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 24 | `public.fn_normalize_area_location()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 25 | `public.fn_post_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 26 | `public.fn_post_comments_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 27 | `public.fn_post_reactions_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 28 | `public.fn_post_reposts_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 29 | `public.fn_profile_follows_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 30 | `public.fn_public_activities_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 31 | `public.fn_set_updated_at()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 32 | `public.fn_sync_geo_fields()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 33 | `public.fn_user_badges_activity_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 34 | `public.handle_game_created()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 35 | `public.handle_player_joined_game()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 36 | `public.handle_post_created()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 37 | `public.handle_user_created()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 38 | `public.hashtags_search_tsv_trigger()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 39 | `public.increment_post_view()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 40 | `public.increment_repost_count()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 41 | `public.meetups_search_tsv_trigger()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 42 | `public.notify_admins_of_report()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 43 | `public.post_comments_search_tsv_trigger()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 44 | `public.posts_primary_vibe_check()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 45 | `public.set_current_timestamp_updated_at()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 46 | `public.set_default_avatar()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 47 | `public.set_geohash_before_insert()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 48 | `public.set_post_author()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 49 | `public.set_updated_at()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 50 | `public.strip_signup_password()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 51 | `public.sync_game_geo()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 52 | `public.sync_reaction_breakdown()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 53 | `public.touch_updated_at()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 54 | `public.trg_after_game_rating_event()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 55 | `public.trg_after_reputation_event()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 56 | `public.trg_after_venue_rating_event()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 57 | `public.trg_arenas_set_search_tsv()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 58 | `public.trg_assign_sport_profile_tier()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 59 | `public.trg_badge_awarded_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 60 | `public.trg_booking_payment_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 61 | `public.trg_circle_join_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 62 | `public.trg_comment_mention_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 63 | `public.trg_fn_games_inherit_sport_from_space()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 64 | `public.trg_fn_games_inherit_venue_geo()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 65 | `public.trg_fn_games_require_challenge_sport()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 66 | `public.trg_fn_venues_set_geo()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 67 | `public.trg_friend_request_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 68 | `public.trg_game_invite_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 69 | `public.trg_game_join_request_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 70 | `public.trg_game_updated_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 71 | `public.trg_game_waitlist_promoted_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 72 | `public.trg_games_set_search_tsv()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 73 | `public.trg_hashtag_increment()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 74 | `public.trg_meetup_invite_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 75 | `public.trg_news_comment_count()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 76 | `public.trg_news_like_count()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 77 | `public.trg_post_comment_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 78 | `public.trg_post_mention_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 79 | `public.trg_post_reaction_breakdown()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 80 | `public.trg_post_reaction_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 81 | `public.trg_post_search_refresh()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 82 | `public.trg_post_search_refresh_from_vibes()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 83 | `public.trg_post_vibes_check()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 84 | `public.trg_posts_primary_vibe_check()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 85 | `public.trg_profile_follow_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 86 | `public.trg_profiles_search_tsv()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 87 | `public.trg_push_on_notification_insert()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 88 | `public.trg_scan_post()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 89 | `public.trg_set_updated_at()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 90 | `public.trg_spaces_legacy_name_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 91 | `public.trg_sport_profiles_form()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 92 | `public.trg_sport_profiles_level_event()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 93 | `public.trg_sport_profiles_overall_level()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 94 | `public.trg_sport_profiles_reliability()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 95 | `public.trg_sport_profiles_verification_event()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 96 | `public.trg_sport_profiles_xp()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 97 | `public.trg_squad_invite_notify()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 98 | `public.trg_squads_owner_default()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 99 | `public.trg_squads_owner_defaults()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 100 | `public.trg_squads_set_search_tsv()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 101 | `public.trg_ticket_from_comment_report()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 102 | `public.trg_touch_updated_at()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 103 | `public.trg_validate_circle_member()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 104 | `public.trg_venues_set_search_tsv()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 105 | `public.trg_welcome_notify()` | `{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 106 | `public.trgfn_block_follow_if_blocked()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 107 | `public.trgfn_block_hoster_social()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 108 | `public.trgfn_block_legacy_persona_updates()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 109 | `public.trgfn_block_profile_skill_level_updates()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 110 | `public.trgfn_block_profile_type_updates()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 111 | `public.trgfn_block_profile_verified_updates()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 112 | `public.trgfn_block_variant_as_sport()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 113 | `public.trgfn_challenges_outbox()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 114 | `public.trgfn_games_block_frozen()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 115 | `public.trgfn_games_set_host_user()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 116 | `public.trgfn_host_profile_persona_guard()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 117 | `public.trgfn_invite_block_frozen()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 118 | `public.trgfn_invite_block_frozen_guard()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 119 | `public.trgfn_invite_recipient_not_frozen()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 120 | `public.trgfn_joinreq_block_frozen()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 121 | `public.trgfn_joinreq_block_frozen_guard()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 122 | `public.trgfn_joinreq_set_user()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 123 | `public.trgfn_limit_active_profiles()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 124 | `public.trgfn_meetups_outbox()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 125 | `public.trgfn_norm_game_scores()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 126 | `public.trgfn_norm_venue_scores()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 127 | `public.trgfn_organiser_profile_persona_guard()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 128 | `public.trgfn_payment_to_ledger()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 129 | `public.trgfn_player_profile_persona_guard()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 130 | `public.trgfn_posts_enforce_author_refs()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 131 | `public.trgfn_posts_fill_author_display_name()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 132 | `public.trgfn_posts_set_geo()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 133 | `public.trgfn_posts_sync_author_display_name()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 134 | `public.trgfn_posts_sync_author_user()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 135 | `public.trgfn_prevent_inactive_sport_usage()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 136 | `public.trgfn_profiles_propagate_display_name()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 137 | `public.trgfn_profiles_username_hist()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 138 | `public.trgfn_rewards_from_outbox()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 139 | `public.trgfn_roster_block_frozen()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 140 | `public.trgfn_roster_block_frozen_guard()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 141 | `public.trgfn_roster_set_user()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 142 | `public.trgfn_roster_set_user_and_guard()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 143 | `public.trgfn_set_badge_sport_id()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 144 | `public.trgfn_set_challenge_sport_id()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 145 | `public.trgfn_set_point_ledger_sport_id()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 146 | `public.trgfn_set_post_sport_id()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 147 | `public.trgfn_set_sport_profile_sport_id()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 148 | `public.trgfn_set_sppb_sport_id()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 149 | `public.trgfn_set_squad_sport_id()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 150 | `public.trgfn_set_user_badge_sport_id()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 151 | `public.trgfn_set_venue_space_capacity()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 152 | `public.trgfn_set_venue_space_sport_id()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 153 | `public.trgfn_sport_profiles_sync()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 154 | `public.trgfn_squad_members_outbox()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 155 | `public.trgfn_sync_age_gender_across_profiles()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 156 | `public.trgfn_touch_updated_at()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 157 | `public.trgfn_validate_persona_compatibility()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 158 | `public.trgfn_validate_setup_variant()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 159 | `public.trgfn_validate_sports_ref_arrays_v2()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 160 | `public.trgfn_waitlist_block_frozen()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 161 | `public.trgfn_waitlist_block_frozen_guard()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 162 | `public.trgfn_waitlist_set_user()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 163 | `public.update_fcm_tokens_updated_at()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 164 | `public.update_hashtag_searchability()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 165 | `public.update_last_seen()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 166 | `public.update_post_comment_count()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 167 | `public.update_post_like_count()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 168 | `public.update_privacy_settings_timestamp()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 169 | `public.update_repost_count()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 170 | `public.update_updated_at_column()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 171 | `public.validate_hoster_persona()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 172 | `public.validate_post_scope()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |
| 173 | `public.validate_venue_submission_status()` | `{=X/postgres,postgres=X/postgres,service_role=X/postgres}` | true | 1 | postgres | trigger |

## Trigger functions anon can execute that are NOT in the list

Catalog-wide read (all schemas except `pg_catalog`/`information_schema`; anon `has_function_privilege`):

| Function | Live proacl | Note |
|---|---|---|
| `public.checkauthtrigger()` | `{=X/supabase_admin,supabase_admin=X/supabase_admin,postgres=X/supabase_admin,anon=X/supabase_admin,authenticated=X/supabase_admin,service_role=X/supabase_admin}` | **PostGIS extension function**, owner `supabase_admin`. Not a Dabbler function; not in the KAN-498 sweep's non-extension set |
| `public.postgis_cache_bbox()` | same ACL as above | **PostGIS extension function**, owner `supabase_admin` |
| `realtime.subscription_check_filters()` | `{=X/supabase_realtime_admin,...,anon=...,authenticated=...,service_role=...}` | Supabase-managed (`realtime` schema); non-extension by `pg_depend` but not ours |
| `storage.enforce_bucket_lifecycle_service_role()`, `storage.enforce_bucket_name_length()`, `storage.protect_bucket_control_columns()`, `storage.protect_delete()`, `storage.update_updated_at_column()` | `proacl` NULL (default privileges: PUBLIC holds EXECUTE; `public_grants` counted 0 because `proacl` is NULL) | Supabase-managed (`storage` schema), anon-executable via the default |

So in schema **`public`**, **no non-extension trigger function that anon can execute is missing from the list.** The four non-listed `public` trigger functions that are NOT anon-executable (already closed): `notify_admins_of_block()` (KAN-523 applied, `{postgres=X/postgres,service_role=X/postgres}`), `fn_activity_favorites_sync_legacy_v1()`, `trg_meetup_rsvps_notify()`, `trg_meetups_cancel_notify()`, `trgfn_charges_immutable()` (all `{postgres=X/postgres,service_role=X/postgres}`).

Reconciliation of the totals (live): `public` has **180** trigger functions = 173 listed + 2 PostGIS (anon-executable) + 5 already closed to anon (the five above). `public` trigger functions anon can execute: **175** = 173 listed + 2 PostGIS. The sweep's "174" included `notify_admins_of_block()`, which KAN-523 has since closed, so 173 + 2 PostGIS is the live anon-executable set in `public`.

## For the reviewer
* The migration's `REVOKE ... FROM PUBLIC, anon` on the 173 targets exactly the 172 PUBLIC-only functions plus `trg_welcome_notify` (PUBLIC and explicit anon); the live ACLs equal the documented ones, so the diff-free C6 comparison holds.
* The two PostGIS functions and the `realtime`/`storage` ones are outside the ticket (owned by `supabase_admin`/`supabase_realtime_admin` or an extension); `REVOKE` by `postgres` on `supabase_admin`-owned objects would not be authorised. Reported, not proposed.
* The 173 per-function rows above are reconstructed from the group query (two groups, 173 names) and the `.md` list, which the group names matched one for one (`acl_differs = []`, `missing_live = []`).

VERIFY
branch: alpha-memphis (read-only dispatch; no commit)
sha: n/a
worktree: n/a
C1: PASS: the report gives the live proacl rows for the list, the diff against the expected values (none), the not-in-list anon-executable trigger functions, the file path, and states nothing was written to the database
