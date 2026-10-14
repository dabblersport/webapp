-- KAN-527 probe pack: PUBLIC and anon EXECUTE on trigger functions
--
-- Covers: supabase/migrations/20261013135000_revoke_public_anon_trigger_functions.sql
--
-- STATUS: AUTHORED, NOT RUN. Nothing in this file was executed against any
-- database while writing it and this ticket does not claim it was. Memphis runs
-- it on the CEO-approved database (execute_sql, test data only, project
-- wtncuzcskpigqpmnxwws, stop on real user data) and records the real PASS/FAIL.
--
-- HOW TO RUN. Run each numbered block as ONE batch. Every block starts with
-- BEGIN and ends with ROLLBACK, so nothing persists, including the READ-ONLY
-- blocks (BEGIN READ ONLY). Section A before the apply, B after. B1 is expected
-- to FAIL before the apply (the proof it can fail).
--
-- Block markers:
--   [READ-ONLY]                      catalogue reads only
--   [WRITE-IN-TRANSACTION-ROLLBACK]  writes inside BEGIN ... ROLLBACK
-- ROLE CAVEAT: the trigger probes write as `authenticated` via
-- request.jwt.claims; as postgres they prove nothing about privileges.
-- If any B2..B5 trigger probe fails after the apply: STOP, do not grant anything.
-- Fixture notes: B2..B5 pick existing test users; they raise SETUP FAIL when the
-- database lacks the rows they need. They never touch rows they did not create
-- in the transaction, except reading ids of existing geo_locations/public_activities.

-- A. PRE-APPLY ------------------------------------------------------------

-- A1 [READ-ONLY] re-derive the live list (the catalog query from the ticket,
--    narrowed to 173: it must also list notify_admins_of_block, KAN-523, and nothing
--    else). Save the output; compare with TRIGGER_FUNCTIONS.md.
begin read only;
select p.oid::regprocedure as signature, p.proacl
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
   and (has_function_privilege('anon', p.oid, 'EXECUTE')
        or exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                    where a.grantee = 0 and a.privilege_type = 'EXECUTE'))
 order by 1;
rollback;

-- A2 [READ-ONLY] ACL BEFORE for the listed functions (save: rollback.sql restores
--    PUBLIC, plus anon where explicit). Expect anon and PUBLIC can execute on all.
begin read only;
select p.oid::regprocedure as signature, p.prorettype::regtype as returns,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE')  as service_exec,
       p.proacl
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.pronargs = 0 and p.proname = any (array[
    '_set_updated_at',
    '_set_updated_at_simple',
    '_touch_updated_at',
    '_wallet_after_ledger',
    'audit_venue_submission_change',
    'challenges_search_tsv_trigger',
    'create_default_privacy_settings',
    'enforce_single_level_reply',
    'enforce_single_visibility_scope',
    'fn_activity_log_sync',
    'fn_feed_items_fanout',
    'fn_game_roster_activity_sync',
    'fn_games_activity_sync',
    'fn_games_inherit_geo',
    'fn_games_sync_joining_rule',
    'fn_likes_notify',
    'fn_likes_sync',
    'fn_meetup_rsvps_activity_sync',
    'fn_meetups_activity_sync',
    'fn_meetups_enforce_solo_sport',
    'fn_meetups_inherit_geo',
    'fn_meetups_sync_joining_rule',
    'fn_news_activity_sync',
    'fn_normalize_area_location',
    'fn_post_activity_sync',
    'fn_post_comments_activity_sync',
    'fn_post_reactions_activity_sync',
    'fn_post_reposts_activity_sync',
    'fn_profile_follows_activity_sync',
    'fn_public_activities_notify',
    'fn_set_updated_at',
    'fn_sync_geo_fields',
    'fn_user_badges_activity_sync',
    'handle_game_created',
    'handle_player_joined_game',
    'handle_post_created',
    'handle_user_created',
    'hashtags_search_tsv_trigger',
    'increment_post_view',
    'increment_repost_count',
    'meetups_search_tsv_trigger',
    'notify_admins_of_report',
    'post_comments_search_tsv_trigger',
    'posts_primary_vibe_check',
    'set_current_timestamp_updated_at',
    'set_default_avatar',
    'set_geohash_before_insert',
    'set_post_author',
    'set_updated_at',
    'strip_signup_password',
    'sync_game_geo',
    'sync_reaction_breakdown',
    'touch_updated_at',
    'trg_after_game_rating_event',
    'trg_after_reputation_event',
    'trg_after_venue_rating_event',
    'trg_arenas_set_search_tsv',
    'trg_assign_sport_profile_tier',
    'trg_badge_awarded_notify',
    'trg_booking_payment_notify',
    'trg_circle_join_notify',
    'trg_comment_mention_notify',
    'trg_fn_games_inherit_sport_from_space',
    'trg_fn_games_inherit_venue_geo',
    'trg_fn_games_require_challenge_sport',
    'trg_fn_venues_set_geo',
    'trg_friend_request_notify',
    'trg_game_invite_notify',
    'trg_game_join_request_notify',
    'trg_game_updated_notify',
    'trg_game_waitlist_promoted_notify',
    'trg_games_set_search_tsv',
    'trg_hashtag_increment',
    'trg_meetup_invite_notify',
    'trg_news_comment_count',
    'trg_news_like_count',
    'trg_post_comment_notify',
    'trg_post_mention_notify',
    'trg_post_reaction_breakdown',
    'trg_post_reaction_notify',
    'trg_post_search_refresh',
    'trg_post_search_refresh_from_vibes',
    'trg_post_vibes_check',
    'trg_posts_primary_vibe_check',
    'trg_profile_follow_notify',
    'trg_profiles_search_tsv',
    'trg_push_on_notification_insert',
    'trg_scan_post',
    'trg_set_updated_at',
    'trg_spaces_legacy_name_sync',
    'trg_sport_profiles_form',
    'trg_sport_profiles_level_event',
    'trg_sport_profiles_overall_level',
    'trg_sport_profiles_reliability',
    'trg_sport_profiles_verification_event',
    'trg_sport_profiles_xp',
    'trg_squad_invite_notify',
    'trg_squads_owner_default',
    'trg_squads_owner_defaults',
    'trg_squads_set_search_tsv',
    'trg_ticket_from_comment_report',
    'trg_touch_updated_at',
    'trg_validate_circle_member',
    'trg_venues_set_search_tsv',
    'trg_welcome_notify',
    'trgfn_block_follow_if_blocked',
    'trgfn_block_hoster_social',
    'trgfn_block_legacy_persona_updates',
    'trgfn_block_profile_skill_level_updates',
    'trgfn_block_profile_type_updates',
    'trgfn_block_profile_verified_updates',
    'trgfn_block_variant_as_sport',
    'trgfn_challenges_outbox',
    'trgfn_games_block_frozen',
    'trgfn_games_set_host_user',
    'trgfn_host_profile_persona_guard',
    'trgfn_invite_block_frozen',
    'trgfn_invite_block_frozen_guard',
    'trgfn_invite_recipient_not_frozen',
    'trgfn_joinreq_block_frozen',
    'trgfn_joinreq_block_frozen_guard',
    'trgfn_joinreq_set_user',
    'trgfn_limit_active_profiles',
    'trgfn_meetups_outbox',
    'trgfn_norm_game_scores',
    'trgfn_norm_venue_scores',
    'trgfn_organiser_profile_persona_guard',
    'trgfn_payment_to_ledger',
    'trgfn_player_profile_persona_guard',
    'trgfn_posts_enforce_author_refs',
    'trgfn_posts_fill_author_display_name',
    'trgfn_posts_set_geo',
    'trgfn_posts_sync_author_display_name',
    'trgfn_posts_sync_author_user',
    'trgfn_prevent_inactive_sport_usage',
    'trgfn_profiles_propagate_display_name',
    'trgfn_profiles_username_hist',
    'trgfn_rewards_from_outbox',
    'trgfn_roster_block_frozen',
    'trgfn_roster_block_frozen_guard',
    'trgfn_roster_set_user',
    'trgfn_roster_set_user_and_guard',
    'trgfn_set_badge_sport_id',
    'trgfn_set_challenge_sport_id',
    'trgfn_set_point_ledger_sport_id',
    'trgfn_set_post_sport_id',
    'trgfn_set_sport_profile_sport_id',
    'trgfn_set_sppb_sport_id',
    'trgfn_set_squad_sport_id',
    'trgfn_set_user_badge_sport_id',
    'trgfn_set_venue_space_capacity',
    'trgfn_set_venue_space_sport_id',
    'trgfn_sport_profiles_sync',
    'trgfn_squad_members_outbox',
    'trgfn_sync_age_gender_across_profiles',
    'trgfn_touch_updated_at',
    'trgfn_validate_persona_compatibility',
    'trgfn_validate_setup_variant',
    'trgfn_validate_sports_ref_arrays_v2',
    'trgfn_waitlist_block_frozen',
    'trgfn_waitlist_block_frozen_guard',
    'trgfn_waitlist_set_user',
    'update_fcm_tokens_updated_at',
    'update_hashtag_searchability',
    'update_last_seen',
    'update_post_comment_count',
    'update_post_like_count',
    'update_privacy_settings_timestamp',
    'update_repost_count',
    'update_updated_at_column',
    'validate_hoster_persona',
    'validate_post_scope',
    'validate_venue_submission_status'
  ])
 order by 1;
rollback;

-- A3 [READ-ONLY] BEFORE counts (anon and PUBLIC can execute every listed function).
begin read only;
do $$
declare names text[] := array[
    '_set_updated_at',
    '_set_updated_at_simple',
    '_touch_updated_at',
    '_wallet_after_ledger',
    'audit_venue_submission_change',
    'challenges_search_tsv_trigger',
    'create_default_privacy_settings',
    'enforce_single_level_reply',
    'enforce_single_visibility_scope',
    'fn_activity_log_sync',
    'fn_feed_items_fanout',
    'fn_game_roster_activity_sync',
    'fn_games_activity_sync',
    'fn_games_inherit_geo',
    'fn_games_sync_joining_rule',
    'fn_likes_notify',
    'fn_likes_sync',
    'fn_meetup_rsvps_activity_sync',
    'fn_meetups_activity_sync',
    'fn_meetups_enforce_solo_sport',
    'fn_meetups_inherit_geo',
    'fn_meetups_sync_joining_rule',
    'fn_news_activity_sync',
    'fn_normalize_area_location',
    'fn_post_activity_sync',
    'fn_post_comments_activity_sync',
    'fn_post_reactions_activity_sync',
    'fn_post_reposts_activity_sync',
    'fn_profile_follows_activity_sync',
    'fn_public_activities_notify',
    'fn_set_updated_at',
    'fn_sync_geo_fields',
    'fn_user_badges_activity_sync',
    'handle_game_created',
    'handle_player_joined_game',
    'handle_post_created',
    'handle_user_created',
    'hashtags_search_tsv_trigger',
    'increment_post_view',
    'increment_repost_count',
    'meetups_search_tsv_trigger',
    'notify_admins_of_report',
    'post_comments_search_tsv_trigger',
    'posts_primary_vibe_check',
    'set_current_timestamp_updated_at',
    'set_default_avatar',
    'set_geohash_before_insert',
    'set_post_author',
    'set_updated_at',
    'strip_signup_password',
    'sync_game_geo',
    'sync_reaction_breakdown',
    'touch_updated_at',
    'trg_after_game_rating_event',
    'trg_after_reputation_event',
    'trg_after_venue_rating_event',
    'trg_arenas_set_search_tsv',
    'trg_assign_sport_profile_tier',
    'trg_badge_awarded_notify',
    'trg_booking_payment_notify',
    'trg_circle_join_notify',
    'trg_comment_mention_notify',
    'trg_fn_games_inherit_sport_from_space',
    'trg_fn_games_inherit_venue_geo',
    'trg_fn_games_require_challenge_sport',
    'trg_fn_venues_set_geo',
    'trg_friend_request_notify',
    'trg_game_invite_notify',
    'trg_game_join_request_notify',
    'trg_game_updated_notify',
    'trg_game_waitlist_promoted_notify',
    'trg_games_set_search_tsv',
    'trg_hashtag_increment',
    'trg_meetup_invite_notify',
    'trg_news_comment_count',
    'trg_news_like_count',
    'trg_post_comment_notify',
    'trg_post_mention_notify',
    'trg_post_reaction_breakdown',
    'trg_post_reaction_notify',
    'trg_post_search_refresh',
    'trg_post_search_refresh_from_vibes',
    'trg_post_vibes_check',
    'trg_posts_primary_vibe_check',
    'trg_profile_follow_notify',
    'trg_profiles_search_tsv',
    'trg_push_on_notification_insert',
    'trg_scan_post',
    'trg_set_updated_at',
    'trg_spaces_legacy_name_sync',
    'trg_sport_profiles_form',
    'trg_sport_profiles_level_event',
    'trg_sport_profiles_overall_level',
    'trg_sport_profiles_reliability',
    'trg_sport_profiles_verification_event',
    'trg_sport_profiles_xp',
    'trg_squad_invite_notify',
    'trg_squads_owner_default',
    'trg_squads_owner_defaults',
    'trg_squads_set_search_tsv',
    'trg_ticket_from_comment_report',
    'trg_touch_updated_at',
    'trg_validate_circle_member',
    'trg_venues_set_search_tsv',
    'trg_welcome_notify',
    'trgfn_block_follow_if_blocked',
    'trgfn_block_hoster_social',
    'trgfn_block_legacy_persona_updates',
    'trgfn_block_profile_skill_level_updates',
    'trgfn_block_profile_type_updates',
    'trgfn_block_profile_verified_updates',
    'trgfn_block_variant_as_sport',
    'trgfn_challenges_outbox',
    'trgfn_games_block_frozen',
    'trgfn_games_set_host_user',
    'trgfn_host_profile_persona_guard',
    'trgfn_invite_block_frozen',
    'trgfn_invite_block_frozen_guard',
    'trgfn_invite_recipient_not_frozen',
    'trgfn_joinreq_block_frozen',
    'trgfn_joinreq_block_frozen_guard',
    'trgfn_joinreq_set_user',
    'trgfn_limit_active_profiles',
    'trgfn_meetups_outbox',
    'trgfn_norm_game_scores',
    'trgfn_norm_venue_scores',
    'trgfn_organiser_profile_persona_guard',
    'trgfn_payment_to_ledger',
    'trgfn_player_profile_persona_guard',
    'trgfn_posts_enforce_author_refs',
    'trgfn_posts_fill_author_display_name',
    'trgfn_posts_set_geo',
    'trgfn_posts_sync_author_display_name',
    'trgfn_posts_sync_author_user',
    'trgfn_prevent_inactive_sport_usage',
    'trgfn_profiles_propagate_display_name',
    'trgfn_profiles_username_hist',
    'trgfn_rewards_from_outbox',
    'trgfn_roster_block_frozen',
    'trgfn_roster_block_frozen_guard',
    'trgfn_roster_set_user',
    'trgfn_roster_set_user_and_guard',
    'trgfn_set_badge_sport_id',
    'trgfn_set_challenge_sport_id',
    'trgfn_set_point_ledger_sport_id',
    'trgfn_set_post_sport_id',
    'trgfn_set_sport_profile_sport_id',
    'trgfn_set_sppb_sport_id',
    'trgfn_set_squad_sport_id',
    'trgfn_set_user_badge_sport_id',
    'trgfn_set_venue_space_capacity',
    'trgfn_set_venue_space_sport_id',
    'trgfn_sport_profiles_sync',
    'trgfn_squad_members_outbox',
    'trgfn_sync_age_gender_across_profiles',
    'trgfn_touch_updated_at',
    'trgfn_validate_persona_compatibility',
    'trgfn_validate_setup_variant',
    'trgfn_validate_sports_ref_arrays_v2',
    'trgfn_waitlist_block_frozen',
    'trgfn_waitlist_block_frozen_guard',
    'trgfn_waitlist_set_user',
    'update_fcm_tokens_updated_at',
    'update_hashtag_searchability',
    'update_last_seen',
    'update_post_comment_count',
    'update_post_like_count',
    'update_privacy_settings_timestamp',
    'update_repost_count',
    'update_updated_at_column',
    'validate_hoster_persona',
    'validate_post_scope',
    'validate_venue_submission_status'
  ];
        nm text; f oid; anon_x int := 0; pub_x int := 0; missing int := 0;
begin
  foreach nm in array names loop
    select p.oid into f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = nm and p.pronargs = 0;
    if f is null then missing := missing + 1; raise notice 'A3: not found live: %', nm; continue; end if;
    if (select prorettype from pg_proc where oid = f) <> 'trigger'::regtype then
      raise exception 'A3 FAIL: % does not return trigger (stop: remove it from the list)', nm; end if;
    if has_function_privilege('anon', f, 'EXECUTE') then anon_x := anon_x + 1; end if;
    if exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                where p.oid = f and a.grantee = 0 and a.privilege_type = 'EXECUTE') then pub_x := pub_x + 1; end if;
  end loop;
  raise notice 'A3: % listed functions, % missing live, anon can execute %, PUBLIC can execute %', array_length(names,1), missing, anon_x, pub_x;

end $$;
rollback;

-- B. POST-APPLY -----------------------------------------------------------

-- B1 [READ-ONLY] AC1: anon and the PUBLIC pseudo-role (grantee 0) can execute none
--    of the listed functions. Each is a trigger function (else STOP).
begin read only;
do $$
declare names text[] := array[
    '_set_updated_at',
    '_set_updated_at_simple',
    '_touch_updated_at',
    '_wallet_after_ledger',
    'audit_venue_submission_change',
    'challenges_search_tsv_trigger',
    'create_default_privacy_settings',
    'enforce_single_level_reply',
    'enforce_single_visibility_scope',
    'fn_activity_log_sync',
    'fn_feed_items_fanout',
    'fn_game_roster_activity_sync',
    'fn_games_activity_sync',
    'fn_games_inherit_geo',
    'fn_games_sync_joining_rule',
    'fn_likes_notify',
    'fn_likes_sync',
    'fn_meetup_rsvps_activity_sync',
    'fn_meetups_activity_sync',
    'fn_meetups_enforce_solo_sport',
    'fn_meetups_inherit_geo',
    'fn_meetups_sync_joining_rule',
    'fn_news_activity_sync',
    'fn_normalize_area_location',
    'fn_post_activity_sync',
    'fn_post_comments_activity_sync',
    'fn_post_reactions_activity_sync',
    'fn_post_reposts_activity_sync',
    'fn_profile_follows_activity_sync',
    'fn_public_activities_notify',
    'fn_set_updated_at',
    'fn_sync_geo_fields',
    'fn_user_badges_activity_sync',
    'handle_game_created',
    'handle_player_joined_game',
    'handle_post_created',
    'handle_user_created',
    'hashtags_search_tsv_trigger',
    'increment_post_view',
    'increment_repost_count',
    'meetups_search_tsv_trigger',
    'notify_admins_of_report',
    'post_comments_search_tsv_trigger',
    'posts_primary_vibe_check',
    'set_current_timestamp_updated_at',
    'set_default_avatar',
    'set_geohash_before_insert',
    'set_post_author',
    'set_updated_at',
    'strip_signup_password',
    'sync_game_geo',
    'sync_reaction_breakdown',
    'touch_updated_at',
    'trg_after_game_rating_event',
    'trg_after_reputation_event',
    'trg_after_venue_rating_event',
    'trg_arenas_set_search_tsv',
    'trg_assign_sport_profile_tier',
    'trg_badge_awarded_notify',
    'trg_booking_payment_notify',
    'trg_circle_join_notify',
    'trg_comment_mention_notify',
    'trg_fn_games_inherit_sport_from_space',
    'trg_fn_games_inherit_venue_geo',
    'trg_fn_games_require_challenge_sport',
    'trg_fn_venues_set_geo',
    'trg_friend_request_notify',
    'trg_game_invite_notify',
    'trg_game_join_request_notify',
    'trg_game_updated_notify',
    'trg_game_waitlist_promoted_notify',
    'trg_games_set_search_tsv',
    'trg_hashtag_increment',
    'trg_meetup_invite_notify',
    'trg_news_comment_count',
    'trg_news_like_count',
    'trg_post_comment_notify',
    'trg_post_mention_notify',
    'trg_post_reaction_breakdown',
    'trg_post_reaction_notify',
    'trg_post_search_refresh',
    'trg_post_search_refresh_from_vibes',
    'trg_post_vibes_check',
    'trg_posts_primary_vibe_check',
    'trg_profile_follow_notify',
    'trg_profiles_search_tsv',
    'trg_push_on_notification_insert',
    'trg_scan_post',
    'trg_set_updated_at',
    'trg_spaces_legacy_name_sync',
    'trg_sport_profiles_form',
    'trg_sport_profiles_level_event',
    'trg_sport_profiles_overall_level',
    'trg_sport_profiles_reliability',
    'trg_sport_profiles_verification_event',
    'trg_sport_profiles_xp',
    'trg_squad_invite_notify',
    'trg_squads_owner_default',
    'trg_squads_owner_defaults',
    'trg_squads_set_search_tsv',
    'trg_ticket_from_comment_report',
    'trg_touch_updated_at',
    'trg_validate_circle_member',
    'trg_venues_set_search_tsv',
    'trg_welcome_notify',
    'trgfn_block_follow_if_blocked',
    'trgfn_block_hoster_social',
    'trgfn_block_legacy_persona_updates',
    'trgfn_block_profile_skill_level_updates',
    'trgfn_block_profile_type_updates',
    'trgfn_block_profile_verified_updates',
    'trgfn_block_variant_as_sport',
    'trgfn_challenges_outbox',
    'trgfn_games_block_frozen',
    'trgfn_games_set_host_user',
    'trgfn_host_profile_persona_guard',
    'trgfn_invite_block_frozen',
    'trgfn_invite_block_frozen_guard',
    'trgfn_invite_recipient_not_frozen',
    'trgfn_joinreq_block_frozen',
    'trgfn_joinreq_block_frozen_guard',
    'trgfn_joinreq_set_user',
    'trgfn_limit_active_profiles',
    'trgfn_meetups_outbox',
    'trgfn_norm_game_scores',
    'trgfn_norm_venue_scores',
    'trgfn_organiser_profile_persona_guard',
    'trgfn_payment_to_ledger',
    'trgfn_player_profile_persona_guard',
    'trgfn_posts_enforce_author_refs',
    'trgfn_posts_fill_author_display_name',
    'trgfn_posts_set_geo',
    'trgfn_posts_sync_author_display_name',
    'trgfn_posts_sync_author_user',
    'trgfn_prevent_inactive_sport_usage',
    'trgfn_profiles_propagate_display_name',
    'trgfn_profiles_username_hist',
    'trgfn_rewards_from_outbox',
    'trgfn_roster_block_frozen',
    'trgfn_roster_block_frozen_guard',
    'trgfn_roster_set_user',
    'trgfn_roster_set_user_and_guard',
    'trgfn_set_badge_sport_id',
    'trgfn_set_challenge_sport_id',
    'trgfn_set_point_ledger_sport_id',
    'trgfn_set_post_sport_id',
    'trgfn_set_sport_profile_sport_id',
    'trgfn_set_sppb_sport_id',
    'trgfn_set_squad_sport_id',
    'trgfn_set_user_badge_sport_id',
    'trgfn_set_venue_space_capacity',
    'trgfn_set_venue_space_sport_id',
    'trgfn_sport_profiles_sync',
    'trgfn_squad_members_outbox',
    'trgfn_sync_age_gender_across_profiles',
    'trgfn_touch_updated_at',
    'trgfn_validate_persona_compatibility',
    'trgfn_validate_setup_variant',
    'trgfn_validate_sports_ref_arrays_v2',
    'trgfn_waitlist_block_frozen',
    'trgfn_waitlist_block_frozen_guard',
    'trgfn_waitlist_set_user',
    'update_fcm_tokens_updated_at',
    'update_hashtag_searchability',
    'update_last_seen',
    'update_post_comment_count',
    'update_post_like_count',
    'update_privacy_settings_timestamp',
    'update_repost_count',
    'update_updated_at_column',
    'validate_hoster_persona',
    'validate_post_scope',
    'validate_venue_submission_status'
  ];
        nm text; f oid; anon_x int := 0; pub_x int := 0; missing int := 0;
begin
  foreach nm in array names loop
    select p.oid into f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = nm and p.pronargs = 0;
    if f is null then missing := missing + 1; raise notice 'B1: not found live: %', nm; continue; end if;
    if (select prorettype from pg_proc where oid = f) <> 'trigger'::regtype then
      raise exception 'B1 FAIL: % does not return trigger (stop: remove it from the list)', nm; end if;
    if has_function_privilege('anon', f, 'EXECUTE') then anon_x := anon_x + 1; end if;
    if exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                where p.oid = f and a.grantee = 0 and a.privilege_type = 'EXECUTE') then pub_x := pub_x + 1; end if;
  end loop;
  raise notice 'B1: % listed functions, % missing live, anon can execute %, PUBLIC can execute %', array_length(names,1), missing, anon_x, pub_x;
  if anon_x <> 0 or pub_x <> 0 then raise exception 'B1 FAIL: anon or PUBLIC can still execute listed trigger functions'; end if;
end $$;
rollback;

-- B1b [READ-ONLY] explicit grants of authenticated and service_role are unchanged:
--    compare this output with A2's proacl (aclitems naming those roles must be
--    identical). Functions that had only the PUBLIC default lose authenticated's
--    effective execute: expected, triggers do not need it.
begin read only;
select p.oid::regprocedure as signature,
       (select array_agg(a::text order by a::text) from unnest(coalesce(p.proacl, '{}'::aclitem[])) a
         where a::text ~ '^(authenticated|service_role)=') as role_items,
       has_function_privilege('service_role', p.oid, 'EXECUTE') as service_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.pronargs = 0 and p.proname = any (array[
    '_set_updated_at',
    '_set_updated_at_simple',
    '_touch_updated_at',
    '_wallet_after_ledger',
    'audit_venue_submission_change',
    'challenges_search_tsv_trigger',
    'create_default_privacy_settings',
    'enforce_single_level_reply',
    'enforce_single_visibility_scope',
    'fn_activity_log_sync',
    'fn_feed_items_fanout',
    'fn_game_roster_activity_sync',
    'fn_games_activity_sync',
    'fn_games_inherit_geo',
    'fn_games_sync_joining_rule',
    'fn_likes_notify',
    'fn_likes_sync',
    'fn_meetup_rsvps_activity_sync',
    'fn_meetups_activity_sync',
    'fn_meetups_enforce_solo_sport',
    'fn_meetups_inherit_geo',
    'fn_meetups_sync_joining_rule',
    'fn_news_activity_sync',
    'fn_normalize_area_location',
    'fn_post_activity_sync',
    'fn_post_comments_activity_sync',
    'fn_post_reactions_activity_sync',
    'fn_post_reposts_activity_sync',
    'fn_profile_follows_activity_sync',
    'fn_public_activities_notify',
    'fn_set_updated_at',
    'fn_sync_geo_fields',
    'fn_user_badges_activity_sync',
    'handle_game_created',
    'handle_player_joined_game',
    'handle_post_created',
    'handle_user_created',
    'hashtags_search_tsv_trigger',
    'increment_post_view',
    'increment_repost_count',
    'meetups_search_tsv_trigger',
    'notify_admins_of_report',
    'post_comments_search_tsv_trigger',
    'posts_primary_vibe_check',
    'set_current_timestamp_updated_at',
    'set_default_avatar',
    'set_geohash_before_insert',
    'set_post_author',
    'set_updated_at',
    'strip_signup_password',
    'sync_game_geo',
    'sync_reaction_breakdown',
    'touch_updated_at',
    'trg_after_game_rating_event',
    'trg_after_reputation_event',
    'trg_after_venue_rating_event',
    'trg_arenas_set_search_tsv',
    'trg_assign_sport_profile_tier',
    'trg_badge_awarded_notify',
    'trg_booking_payment_notify',
    'trg_circle_join_notify',
    'trg_comment_mention_notify',
    'trg_fn_games_inherit_sport_from_space',
    'trg_fn_games_inherit_venue_geo',
    'trg_fn_games_require_challenge_sport',
    'trg_fn_venues_set_geo',
    'trg_friend_request_notify',
    'trg_game_invite_notify',
    'trg_game_join_request_notify',
    'trg_game_updated_notify',
    'trg_game_waitlist_promoted_notify',
    'trg_games_set_search_tsv',
    'trg_hashtag_increment',
    'trg_meetup_invite_notify',
    'trg_news_comment_count',
    'trg_news_like_count',
    'trg_post_comment_notify',
    'trg_post_mention_notify',
    'trg_post_reaction_breakdown',
    'trg_post_reaction_notify',
    'trg_post_search_refresh',
    'trg_post_search_refresh_from_vibes',
    'trg_post_vibes_check',
    'trg_posts_primary_vibe_check',
    'trg_profile_follow_notify',
    'trg_profiles_search_tsv',
    'trg_push_on_notification_insert',
    'trg_scan_post',
    'trg_set_updated_at',
    'trg_spaces_legacy_name_sync',
    'trg_sport_profiles_form',
    'trg_sport_profiles_level_event',
    'trg_sport_profiles_overall_level',
    'trg_sport_profiles_reliability',
    'trg_sport_profiles_verification_event',
    'trg_sport_profiles_xp',
    'trg_squad_invite_notify',
    'trg_squads_owner_default',
    'trg_squads_owner_defaults',
    'trg_squads_set_search_tsv',
    'trg_ticket_from_comment_report',
    'trg_touch_updated_at',
    'trg_validate_circle_member',
    'trg_venues_set_search_tsv',
    'trg_welcome_notify',
    'trgfn_block_follow_if_blocked',
    'trgfn_block_hoster_social',
    'trgfn_block_legacy_persona_updates',
    'trgfn_block_profile_skill_level_updates',
    'trgfn_block_profile_type_updates',
    'trgfn_block_profile_verified_updates',
    'trgfn_block_variant_as_sport',
    'trgfn_challenges_outbox',
    'trgfn_games_block_frozen',
    'trgfn_games_set_host_user',
    'trgfn_host_profile_persona_guard',
    'trgfn_invite_block_frozen',
    'trgfn_invite_block_frozen_guard',
    'trgfn_invite_recipient_not_frozen',
    'trgfn_joinreq_block_frozen',
    'trgfn_joinreq_block_frozen_guard',
    'trgfn_joinreq_set_user',
    'trgfn_limit_active_profiles',
    'trgfn_meetups_outbox',
    'trgfn_norm_game_scores',
    'trgfn_norm_venue_scores',
    'trgfn_organiser_profile_persona_guard',
    'trgfn_payment_to_ledger',
    'trgfn_player_profile_persona_guard',
    'trgfn_posts_enforce_author_refs',
    'trgfn_posts_fill_author_display_name',
    'trgfn_posts_set_geo',
    'trgfn_posts_sync_author_display_name',
    'trgfn_posts_sync_author_user',
    'trgfn_prevent_inactive_sport_usage',
    'trgfn_profiles_propagate_display_name',
    'trgfn_profiles_username_hist',
    'trgfn_rewards_from_outbox',
    'trgfn_roster_block_frozen',
    'trgfn_roster_block_frozen_guard',
    'trgfn_roster_set_user',
    'trgfn_roster_set_user_and_guard',
    'trgfn_set_badge_sport_id',
    'trgfn_set_challenge_sport_id',
    'trgfn_set_point_ledger_sport_id',
    'trgfn_set_post_sport_id',
    'trgfn_set_sport_profile_sport_id',
    'trgfn_set_sppb_sport_id',
    'trgfn_set_squad_sport_id',
    'trgfn_set_user_badge_sport_id',
    'trgfn_set_venue_space_capacity',
    'trgfn_set_venue_space_sport_id',
    'trgfn_sport_profiles_sync',
    'trgfn_squad_members_outbox',
    'trgfn_sync_age_gender_across_profiles',
    'trgfn_touch_updated_at',
    'trgfn_validate_persona_compatibility',
    'trgfn_validate_setup_variant',
    'trgfn_validate_sports_ref_arrays_v2',
    'trgfn_waitlist_block_frozen',
    'trgfn_waitlist_block_frozen_guard',
    'trgfn_waitlist_set_user',
    'update_fcm_tokens_updated_at',
    'update_hashtag_searchability',
    'update_last_seen',
    'update_post_comment_count',
    'update_post_like_count',
    'update_privacy_settings_timestamp',
    'update_repost_count',
    'update_updated_at_column',
    'validate_hoster_persona',
    'validate_post_scope',
    'validate_venue_submission_status'
  ])
 order by 1;
rollback;

-- B2 [WRITE-IN-TRANSACTION-ROLLBACK] trigger sample (a): the block trigger
--    trg_notify_admins_of_block still notifies admins on a block through
--    rpc_block_user(uuid), using a TEMPORARY admin fixture (user c, inserted into
--    app_admins inside the transaction). Only NEW notification rows are judged:
--    exactly one per admin, the fixture admin included.
begin;
do $$
declare a uuid; c uuid; pa uuid;
begin
  select user_id, id into a, pa from public.profiles where is_active order by created_at limit 1;
  select p.user_id into c from public.profiles p
   where p.is_active and p.user_id <> a and not exists (select 1 from public.app_admins x where x.user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or c is null then raise exception 'SETUP FAIL: need two active test users, the second not an admin'; end if;
  perform set_config('k527.a', a::text, true);
  perform set_config('k527.pa', pa::text, true);
  perform set_config('k527.c', c::text, true);
end $$;
do $$
declare a uuid := current_setting('k527.a')::uuid; c uuid := current_setting('k527.c')::uuid; b uuid;
        admins int; before_ids text[]; new_rows int; fixture_rows int; bad int;
begin
  select p.user_id into b from public.profiles p
   where p.is_active and p.user_id not in (a, c)
     and not exists (select 1 from public.user_blocks x where (x.blocker_user_id = a and x.blocked_user_id = p.user_id) or (x.blocker_user_id = p.user_id and x.blocked_user_id = a))
   order by p.created_at limit 1;
  if b is null then raise exception 'SETUP FAIL: need a third active test user to be blocked'; end if;
  insert into public.app_admins(user_id) values (c);   -- temporary admin fixture (rolled back)
  select count(*) into admins from public.app_admins;
  select coalesce(array_agg(id::text), '{}') into before_ids from public.notifications
   where kind_key = 'moderation.user_blocked' and context->>'blocker_user_id' = a::text and context->>'blocked_user_id' = b::text;
  raise notice 'B2 fixture: blocker=% blocked=% fixture admin=% admins=%', a, b, c, admins;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k527.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.rpc_block_user(b);
  reset role;
  create temp table k527_new as
    select n.id::text as id, n.to_user_id from public.notifications n
     where n.kind_key = 'moderation.user_blocked' and n.context->>'blocker_user_id' = a::text and n.context->>'blocked_user_id' = b::text
       and not (n.id::text = any (before_ids));
  select count(*) into new_rows from k527_new;
  select count(*) into fixture_rows from k527_new where to_user_id = c;
  select count(*) into bad from public.app_admins ad where (select count(*) from k527_new k where k.to_user_id = ad.user_id) <> 1;
  if new_rows <> admins or fixture_rows <> 1 or bad <> 0 then
    raise exception 'B2 FAIL (STOP, do not grant): % new notifications for % admins, % to the fixture admin, % admins without exactly one', new_rows, admins, fixture_rows, bad; end if;
  raise notice 'B2 PASS (admins=%, exactly one new notification each, fixture admin included)', admins;
end $$;
rollback;

-- B3 [WRITE-IN-TRANSACTION-ROLLBACK] trigger sample (b), geo: an authenticated
--    insert into profile_locations fires fn_sync_geo_fields (trg_profile_locations_sync_geo):
--    lat, lng and area_id are filled from the chosen geo_locations row. (fn_sync_geo_fields
--    is attached to games, meetups, profile_locations and venues; the posts geo
--    trigger is trgfn_posts_set_geo, covered in B4.)
begin;
do $$
declare a uuid; c uuid; pa uuid;
begin
  select user_id, id into a, pa from public.profiles where is_active order by created_at limit 1;
  select p.user_id into c from public.profiles p
   where p.is_active and p.user_id <> a and not exists (select 1 from public.app_admins x where x.user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or c is null then raise exception 'SETUP FAIL: need two active test users, the second not an admin'; end if;
  perform set_config('k527.a', a::text, true);
  perform set_config('k527.pa', pa::text, true);
  perform set_config('k527.c', c::text, true);
end $$;
do $$
declare a uuid := current_setting('k527.a')::uuid; pa uuid := current_setting('k527.pa')::uuid;
        g uuid; glat double precision; glng double precision; garea uuid; r record; pid uuid;
begin
  select id, st_y(location::geometry), st_x(location::geometry), area_id into g, glat, glng, garea
    from public.geo_locations where location is not null order by created_at limit 1;
  if g is null then raise exception 'SETUP FAIL: no geo_locations row to point at'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k527.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  insert into public.profile_locations(profile_id, geo_location_id, label) values (pa, g, 'custom') returning id into pid;
  reset role;
  select lat, lng, area_id into r from public.profile_locations where id = pid;
  if r.lat is distinct from glat or r.lng is distinct from glng or r.area_id is distinct from garea then
    raise exception 'B3 FAIL (STOP, do not grant): geo columns were not populated (lat=%, lng=%, area=%)', r.lat, r.lng, r.area_id; end if;
  raise notice 'B3 PASS (fn_sync_geo_fields filled lat, lng, area_id)';
end $$;
rollback;

-- B4 [WRITE-IN-TRANSACTION-ROLLBACK] trigger sample (c), posts: an authenticated
--    insert of a test post with manual lat/lng fires trg_posts_set_geo
--    (trgfn_posts_set_geo, BEFORE INSERT OR UPDATE on posts): geo_location_id and
--    area_id must be populated; a following update must advance updated_at
--    (trg_posts_updated_at / _set_updated_at). The insert supplies only the
--    columns without defaults known from the baseline; if the live table has more
--    NOT NULL columns the block fails with a not-null error: a fixture problem,
--    not a trigger one.
begin;
do $$
declare a uuid; c uuid; pa uuid;
begin
  select user_id, id into a, pa from public.profiles where is_active order by created_at limit 1;
  select p.user_id into c from public.profiles p
   where p.is_active and p.user_id <> a and not exists (select 1 from public.app_admins x where x.user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or c is null then raise exception 'SETUP FAIL: need two active test users, the second not an admin'; end if;
  perform set_config('k527.a', a::text, true);
  perform set_config('k527.pa', pa::text, true);
  perform set_config('k527.c', c::text, true);
end $$;
do $$
declare a uuid := current_setting('k527.a')::uuid; pa uuid := current_setting('k527.pa')::uuid;
        pid uuid; g uuid; ar uuid; u0 timestamptz; u1 timestamptz; nm text;
begin
  select coalesce(display_name, 'test') into nm from public.profiles where id = pa;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k527.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  insert into public.posts(author_profile_id, author_user_id, kind, visibility, geo_lat, geo_lng, author_display_name)
  values (pa, a, (enum_range(null::public.post_kind))[1], 'private', 25.2, 55.27, nm)
  returning id, geo_location_id, area_id, updated_at into pid, g, ar, u0;
  if g is null or ar is null then
    raise exception 'B4 FAIL (STOP, do not grant): trg_posts_set_geo did not populate geo_location_id / area_id (%, %)', g, ar; end if;
  perform pg_sleep(0.01);
  update public.posts set body = 'kan527 probe' where id = pid returning updated_at into u1;
  reset role;
  if u1 is null or u1 <= u0 then raise exception 'B4 FAIL (STOP, do not grant): trg_posts_updated_at did not advance updated_at (% -> %)', u0, u1; end if;
  raise notice 'B4 PASS (trg_posts_set_geo populated geo_location_id and area_id; updated_at trigger fired)';
end $$;
rollback;

-- B5 [WRITE-IN-TRANSACTION-ROLLBACK] trigger sample (d), likes (a different table
--    class, a SECURITY DEFINER trigger): an authenticated like fires fn_likes_sync,
--    which bumps public_activities.like_count by one.
begin;
do $$
declare a uuid; c uuid; pa uuid;
begin
  select user_id, id into a, pa from public.profiles where is_active order by created_at limit 1;
  select p.user_id into c from public.profiles p
   where p.is_active and p.user_id <> a and not exists (select 1 from public.app_admins x where x.user_id = p.user_id)
   order by p.created_at limit 1;
  if a is null or c is null then raise exception 'SETUP FAIL: need two active test users, the second not an admin'; end if;
  perform set_config('k527.a', a::text, true);
  perform set_config('k527.pa', pa::text, true);
  perform set_config('k527.c', c::text, true);
end $$;
do $$
declare a uuid := current_setting('k527.a')::uuid; pa uuid := current_setting('k527.pa')::uuid;
        act uuid; c0 int; c1 int;
begin
  select pa2.id, pa2.like_count into act, c0 from public.public_activities pa2
   where not exists (select 1 from public.likes l where l.parent_activity_id = pa2.id and l.actor_user_id = a) order by pa2.created_at limit 1;
  if act is null then raise exception 'SETUP FAIL: no public_activities row to like'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', current_setting('k527.a'), 'role', 'authenticated')::text, true); set local role authenticated;
  insert into public.likes(parent_activity_id, profile_id, actor_user_id) values (act, pa, a);
  reset role;
  select like_count into c1 from public.public_activities where id = act;
  if c1 <> c0 + 1 then raise exception 'B5 FAIL (STOP, do not grant): like_count % -> %, expected +1', c0, c1; end if;
  raise notice 'B5 PASS (fn_likes_sync fired: like_count % -> %)', c0, c1;
end $$;
rollback;
