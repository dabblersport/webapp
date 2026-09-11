-- KAN-86 — successor to KAN-67 (which closed only the 70 postgres-owned
-- view write grants). This closes the base-table half: revoke the six
-- write verbs (INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER) from
-- `anon` and `authenticated` on every postgres-owned public base table,
-- then re-grant exactly the {table, verb} set the app's real write paths
-- need for `authenticated`. `anon` gets nothing re-granted: no call site in
-- lib/ or supabase/functions/ writes to a base table as `anon` (all direct
-- table writes run under an authenticated session; the two edge functions
-- that write — send-push-notification, detect-country — use
-- SUPABASE_SERVICE_ROLE_KEY, which bypasses grants entirely).
--
-- Verified live 2026-09-01 (wtncuzcskpigqpmnxwws), read-only, before writing
-- this file:
--   - 187 relkind='r' tables in public; 186 owned by postgres, 1
--     (spatial_ref_sys) owned by supabase_admin (T-025: no membership,
--     cannot ALTER/REVOKE it — excluded by platform constraint, not choice,
--     per KAN-86's own text; do not let a verification query fail on it).
--   - Of the 186, 183 currently hold anon INSERT+UPDATE+DELETE=true; the
--     other 3 (data_export_requests, export_download_logs,
--     gdpr_compliance_log) were already scoped down today by KAN-52's
--     follow-up migrations (20260829073752, 20260901160000) — this
--     migration's revoke/re-grant is idempotent for those three and
--     reproduces their current live state exactly, not a regression.
--   - The 2026-08-29 ticket baseline (184/185) is stale: two tables were
--     added since (kan52's export_download_logs, gdpr_compliance_log — see
--     20260901140000). Re-verified live rather than trusting the ticket
--     text's count, per T-020/020.
--
-- The re-grant set below was derived from the code, not guessed: every
-- `.from('<table>').insert/update/upsert/delete` call site across lib/ and
-- supabase/functions/ was enumerated, resolved through
-- lib/core/config/supabase_config.dart's constants (including
-- non-SupabaseConfig local `_table`/`table` string constants, which are
-- themselves grep'd back to their literal value — nothing here is inlined
-- from a literal-string grep), and mapped to {table, verb}. Dart's local
-- `List.insert(...)` (profile_cache_service.dart, Overlay widgets) and
-- `File.delete()` (content_sharing_helper.dart, data_export_service.dart)
-- calls are not Supabase writes and are excluded. Two edge-function inserts
-- (audit_events, via service_role) are excluded for the same reason as
-- above.
--
-- IMPORTANT — dead-code table references found during this sweep, NOT
-- fixed here (out of this ticket's scope; these tables plain don't exist
-- live, so no grant is possible on them and this migration cannot regress
-- them further):
--   bookings (bookings_datasource.dart — 11 call sites; the real table is
--     venue_bookings), game_ratings (should likely be a game_rating_*
--     table), venue_reviews, payment_methods (payment_methods_datasource.dart
--     — 5 call sites; only payment_intents/payment_records exist),
--     organiser_benefits, profile_views, venue_opening_hours (renamed to
--     opening_hours per prior migration — see agent memory
--     opening-hours-renamed-and-reshaped), and the entire GDPR-cleanup
--     surface in data_retention_service.dart (user_retention_policies,
--     scheduled_cleanup_tasks, data_cleanup_audit, grace_period_requests,
--     messages, login_history, user_media, location_data, user_analytics,
--     audit_logs — NONE of these ten tables exist live). Flagging for
--     master-analyst / cto rather than silently absorbing into this grant
--     migration.
--
-- Does NOT use `REVOKE ... ON ALL TABLES IN SCHEMA public` (would hit
-- spatial_ref_sys and either halt or silently no-op per T-015). Targets are
-- enumerated explicitly below.

BEGIN;

-- ---------------------------------------------------------------------------
-- Step 1: revoke the six write verbs from anon and authenticated on every
-- postgres-owned public base table (186 tables, spatial_ref_sys excluded).
-- ---------------------------------------------------------------------------

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE
  public.activity_events, public.activity_log, public.admins, public.amenities_catalog,
  public.analytics_events, public.app_admins, public.areas, public.audit_events,
  public.badge_rules, public.badges, public.blackouts, public.briefs,
  public.challenge_fixtures, public.challenge_invites, public.challenge_squads,
  public.challenge_stages, public.challenge_types, public.challenges, public.check_in_logs,
  public.circle_members, public.circles, public.comment_mentions, public.comments,
  public.commission_rules, public.consent_records, public.content_draft_events,
  public.content_drafts, public.context_rating_config, public.data_export_requests,
  public.demo_content, public.display_name_banned, public.export_download_logs,
  public.fcm_tokens, public.feed_items, public.feed_rank_config, public.financial_ledger,
  public.friend_requests_audit, public.game_invites, public.game_join_requests,
  public.game_link_tokens, public.game_rating_aggregate, public.game_rating_dimensions,
  public.game_rating_events, public.game_roster, public.game_settlements,
  public.game_waitlist, public.games, public.gdpr_compliance_log, public.geo_locations,
  public.hashtags, public.host, public.levels, public.likes, public.location_tags,
  public.meetup_attendees, public.meetup_invites, public.meetup_link_tokens,
  public.meetup_rsvps, public.meetups, public.moderation_actions,
  public.moderation_ban_terms, public.moderation_flags, public.moderation_reports,
  public.moderation_tickets, public.news, public.notification_aggregates,
  public.notification_aggregation_rules, public.notification_deliveries,
  public.notification_hourly_caps, public.notification_kinds, public.notification_scores,
  public.notification_settings, public.notification_user_preferences, public.notifications,
  public.opening_hours, public.organiser, public.organiser_channels,
  public.organiser_venues, public.payment_intents, public.payout_beneficiaries,
  public.payouts, public.player, public.point_ledger, public.post_circles,
  public.post_hashtags, public.post_hides, public.post_media, public.post_mentions,
  public.post_reposts, public.post_squads, public.post_themes, public.post_views,
  public.posts, public.privacy_settings, public.profile_circle_members,
  public.profile_circles, public.profile_follows, public.profile_locations,
  public.profile_tiers, public.profile_verifications, public.profiles,
  public.public_activities, public.rating_reports, public.ratings, public.reactions,
  public.ref_cities, public.ref_countries, public.ref_regions, public.reputation_config,
  public.reputation_dimensions, public.restrictions, public.reuse_fingerprints,
  public.reuse_global_stats, public.reuse_user_stats, public.reward_rules,
  public.role_grants, public.roles, public.safety_blocklist_terms, public.safety_cooldowns,
  public.safety_takedowns, public.space_prices, public.space_slot_grid,
  public.space_slot_holds, public.sport_aliases, public.sport_governing_bodies,
  public.sport_governing_body_links, public.sport_popularity_countries,
  public.sport_popularity_regions, public.sport_primary_sport_countries,
  public.sport_profile_badges, public.sport_profile_events,
  public.sport_profile_profile_badges, public.sport_profile_tiers, public.sport_profiles,
  public.sport_skill_levels, public.sport_variants, public.sports, public.sportskilllevels,
  public.squad_invites, public.squad_join_requests, public.squad_link_tokens,
  public.squad_members, public.squads, public.subscription_features,
  public.subscription_plans, public.surface_catalog, public.tiers, public.user_actor_pref,
  public.user_badges, public.user_blocks, public.user_check_ins, public.user_freezes,
  public.user_hashtag_preferences, public.user_hidden_modes, public.user_preferences,
  public.user_reputation_aggregate, public.user_reputation_events, public.user_settings,
  public.user_status, public.user_subscriptions, public.username_attempts,
  public.username_banned, public.username_changes, public.username_registry,
  public.username_reserved, public.venue_blackouts, public.venue_bookings,
  public.venue_favorites, public.venue_members, public.venue_payouts, public.venue_photos,
  public.venue_price_rules, public.venue_rating_aggregate, public.venue_rating_dimensions,
  public.venue_rating_events, public.venue_spaces, public.venue_submission_sports,
  public.venue_submissions, public.venues, public.vibe_collection_items,
  public.vibe_collections, public.vibes, public.vibes_reco_config,
  public.visibility_scopes, public.wallet_ledger, public.wallets
FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- Step 2: re-grant exactly the {table, verb} set derived from real write
-- call sites in lib/ and supabase/functions/. `anon` receives nothing.
-- `authenticated` receives only the verbs actually exercised.
-- ---------------------------------------------------------------------------

GRANT INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.sport_profiles TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.organiser TO authenticated;
GRANT INSERT ON public.player TO authenticated;
GRANT INSERT ON public.host TO authenticated;
GRANT INSERT ON public.profile_tiers TO authenticated;
GRANT INSERT, UPDATE ON public.user_settings TO authenticated;
GRANT INSERT, DELETE ON public.space_slot_holds TO authenticated;
GRANT INSERT, UPDATE ON public.moderation_tickets TO authenticated;
GRANT INSERT ON public.moderation_actions TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.moderation_ban_terms TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.circle_members TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.posts TO authenticated;
GRANT INSERT ON public.post_squads TO authenticated;
GRANT INSERT ON public.hashtags TO authenticated;
GRANT INSERT, UPDATE ON public.post_hashtags TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.likes TO authenticated;
GRANT INSERT, UPDATE ON public.comments TO authenticated;
GRANT DELETE ON public.post_reposts TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.reactions TO authenticated;
GRANT INSERT, UPDATE ON public.post_views TO authenticated;
GRANT INSERT ON public.geo_locations TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.profile_locations TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.squads TO authenticated;
GRANT INSERT ON public.squad_invites TO authenticated;
GRANT INSERT, UPDATE ON public.venue_spaces TO authenticated;
GRANT INSERT, UPDATE ON public.venue_price_rules TO authenticated;
GRANT INSERT, UPDATE ON public.venue_submissions TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.games TO authenticated;
GRANT INSERT, DELETE ON public.game_roster TO authenticated;
GRANT INSERT, UPDATE ON public.game_join_requests TO authenticated;
GRANT INSERT, UPDATE ON public.user_preferences TO authenticated;
GRANT INSERT, UPDATE ON public.privacy_settings TO authenticated;
GRANT INSERT, UPDATE ON public.data_export_requests TO authenticated;
GRANT INSERT ON public.export_download_logs TO authenticated;
GRANT INSERT ON public.gdpr_compliance_log TO authenticated;
GRANT INSERT ON public.profile_follows TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.fcm_tokens TO authenticated;
GRANT INSERT, UPDATE ON public.notification_settings TO authenticated;
GRANT UPDATE ON public.notifications TO authenticated;

COMMIT;

-- ---------------------------------------------------------------------------
-- Post-apply verification (run after apply, per AC4 — role switch must be a
-- single DO block; an autocommitted SET ROLE / RESET ROLE pair silently
-- runs as postgres, per KAN-67's harness lesson).
-- ---------------------------------------------------------------------------
-- DO $$
-- DECLARE
--   leaked int;
-- BEGIN
--   SELECT count(*) INTO leaked
--   FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
--   WHERE n.nspname = 'public' AND c.relkind = 'r'
--     AND c.relowner::regrole::text = 'postgres'
--     AND (has_table_privilege('anon', c.oid, 'INSERT')
--       OR has_table_privilege('anon', c.oid, 'UPDATE')
--       OR has_table_privilege('anon', c.oid, 'DELETE')
--       OR has_table_privilege('anon', c.oid, 'TRUNCATE')
--       OR has_table_privilege('anon', c.oid, 'REFERENCES')
--       OR has_table_privilege('anon', c.oid, 'TRIGGER'));
--   IF leaked > 0 THEN
--     RAISE EXCEPTION 'KAN-86 verification failed: % postgres-owned public tables still grant anon a write verb', leaked;
--   END IF;
--   RAISE NOTICE 'KAN-86 verified: anon holds no write verb on any postgres-owned public base table.';
-- END $$;
