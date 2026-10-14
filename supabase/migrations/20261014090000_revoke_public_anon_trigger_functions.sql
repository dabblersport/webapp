-- KAN-527: revoke PUBLIC and anon EXECUTE from trigger functions in schema public
-- (hygiene from the KAN-498 sweep).   AUTHORED, NOT APPLIED. Team Deir el-Bahari.
--
-- KAN-498's read-only sweep (2026-10-13) found 174 public functions that return
-- `trigger` and are anon-executable through PUBLIC (one also by an explicit anon
-- grant). notify_admins_of_block() is one of the 174 and belongs to KAN-523, so it
-- is NOT here: 173 functions follow. Source and the per-function table:
-- supabase/tests/trigger_functions_acl/TRIGGER_FUNCTIONS.md.
--
-- A trigger function cannot be called as an RPC, and EXECUTE is checked when a
-- trigger is created, not when it fires, so this is hygiene with no anon-page
-- risk. Only statements of the form REVOKE EXECUTE ... FROM PUBLIC, anon; no
-- GRANT, no body change, no DROP, no non-trigger function. Explicit grants to
-- authenticated and service_role are left as they are.
--
-- Note: functions that had only the default PUBLIC grant lose authenticated's
-- EFFECTIVE execute (it came through PUBLIC). Triggers still fire for
-- authenticated writes; if a post-apply probe shows one that does not, STOP, do
-- not grant.

REVOKE EXECUTE ON FUNCTION public._set_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public._set_updated_at_simple() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public._touch_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public._wallet_after_ledger() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.audit_venue_submission_change() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.challenges_search_tsv_trigger() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_default_privacy_settings() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.enforce_single_level_reply() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.enforce_single_visibility_scope() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_activity_log_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_feed_items_fanout() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_game_roster_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_games_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_games_inherit_geo() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_games_sync_joining_rule() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_likes_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_likes_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_meetup_rsvps_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_meetups_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_meetups_enforce_solo_sport() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_meetups_inherit_geo() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_meetups_sync_joining_rule() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_news_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_normalize_area_location() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_post_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_post_comments_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_post_reactions_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_post_reposts_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_profile_follows_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_public_activities_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_set_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_sync_geo_fields() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_user_badges_activity_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.handle_game_created() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.handle_player_joined_game() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.handle_post_created() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.handle_user_created() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.hashtags_search_tsv_trigger() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.increment_post_view() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.increment_repost_count() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.meetups_search_tsv_trigger() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.notify_admins_of_report() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.post_comments_search_tsv_trigger() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.posts_primary_vibe_check() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_current_timestamp_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_default_avatar() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_geohash_before_insert() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_post_author() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.strip_signup_password() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.sync_game_geo() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.sync_reaction_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.touch_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_after_game_rating_event() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_after_reputation_event() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_after_venue_rating_event() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_arenas_set_search_tsv() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_assign_sport_profile_tier() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_badge_awarded_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_booking_payment_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_circle_join_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_comment_mention_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_fn_games_inherit_sport_from_space() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_fn_games_inherit_venue_geo() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_fn_games_require_challenge_sport() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_fn_venues_set_geo() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_friend_request_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_game_invite_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_game_join_request_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_game_updated_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_game_waitlist_promoted_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_games_set_search_tsv() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_hashtag_increment() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_meetup_invite_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_news_comment_count() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_news_like_count() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_post_comment_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_post_mention_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_post_reaction_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_post_reaction_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_post_search_refresh() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_post_search_refresh_from_vibes() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_post_vibes_check() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_posts_primary_vibe_check() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_profile_follow_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_profiles_search_tsv() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_push_on_notification_insert() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_scan_post() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_set_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_spaces_legacy_name_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_sport_profiles_form() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_sport_profiles_level_event() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_sport_profiles_overall_level() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_sport_profiles_reliability() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_sport_profiles_verification_event() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_sport_profiles_xp() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_squad_invite_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_squads_owner_default() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_squads_owner_defaults() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_squads_set_search_tsv() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_ticket_from_comment_report() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_touch_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_validate_circle_member() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_venues_set_search_tsv() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trg_welcome_notify() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_block_follow_if_blocked() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_block_hoster_social() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_block_legacy_persona_updates() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_block_profile_skill_level_updates() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_block_profile_type_updates() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_block_profile_verified_updates() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_block_variant_as_sport() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_challenges_outbox() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_games_block_frozen() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_games_set_host_user() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_host_profile_persona_guard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_invite_block_frozen() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_invite_block_frozen_guard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_invite_recipient_not_frozen() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_joinreq_block_frozen() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_joinreq_block_frozen_guard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_joinreq_set_user() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_limit_active_profiles() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_meetups_outbox() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_norm_game_scores() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_norm_venue_scores() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_organiser_profile_persona_guard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_payment_to_ledger() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_player_profile_persona_guard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_posts_enforce_author_refs() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_posts_fill_author_display_name() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_posts_set_geo() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_posts_sync_author_display_name() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_posts_sync_author_user() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_prevent_inactive_sport_usage() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_profiles_propagate_display_name() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_profiles_username_hist() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_rewards_from_outbox() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_roster_block_frozen() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_roster_block_frozen_guard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_roster_set_user() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_roster_set_user_and_guard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_set_badge_sport_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_set_challenge_sport_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_set_point_ledger_sport_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_set_post_sport_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_set_sport_profile_sport_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_set_sppb_sport_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_set_squad_sport_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_set_user_badge_sport_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_set_venue_space_capacity() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_set_venue_space_sport_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_sport_profiles_sync() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_squad_members_outbox() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_sync_age_gender_across_profiles() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_touch_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_validate_persona_compatibility() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_validate_setup_variant() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_validate_sports_ref_arrays_v2() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_waitlist_block_frozen() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_waitlist_block_frozen_guard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_waitlist_set_user() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_fcm_tokens_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_hashtag_searchability() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_last_seen() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_post_comment_count() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_post_like_count() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_privacy_settings_timestamp() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_repost_count() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.validate_hoster_persona() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.validate_post_scope() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.validate_venue_submission_status() FROM PUBLIC, anon;
