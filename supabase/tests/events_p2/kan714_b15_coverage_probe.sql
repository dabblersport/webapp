-- KAN-734 (KAN-714 B15) — read-coverage probe for the events-parent conversion.
--
-- LOCAL DATABASES ONLY. Never run this against a hosted Supabase project.
--
-- Companion to supabase/tests/events_p2/KAN714_READ_MANIFEST.md. The manifest table below is the
-- coverage matrix from that file, verbatim. The probe re-derives what it can from the catalogue of
-- the database it runs on, and fails if the catalogue and the manifest disagree.
--
-- Modes (psql -v mode=...):
--   test      (default)  T0, C1-C13, S1-S5. Ends with NOTICE 'KAN-734 ALL PASS'.
--   snapshot             Records the output shape of every converted object into kan734_fx.preshape.
--                        It runs ON CONFLICT DO NOTHING, so the first capture wins. The clean proof runs
--                        it before each B migration, and C13 compares against it.
--   derive               Prints the derived sets and asserts nothing. Used to (re)build the expected
--                        arrays below.
--   -v corrupt=1         Negative control: one open and one converted row swap status (totals unchanged),
--                        and the catalogue checks must then FAIL.
--
-- No data persists. The scenario runs inside BEGIN ... ROLLBACK, and S5 proves the rollback with md5
-- fingerprints of games, meetups and events. Only mode=snapshot writes, and only to kan734_fx.preshape.
\set ON_ERROR_STOP 1
\if :{?mode}
\else
\set mode test
\endif
\if :{?corrupt}
\else
\set corrupt 0
\endif
SELECT (:'mode' = 'snapshot') AS k734_snap, (:'mode' = 'derive') AS k734_derive \gset
SET client_min_messages = notice;

-- converted object names (functions by name, all overloads; views), from the manifest
CREATE TEMP TABLE k734_conv_names(kind text, name text);
INSERT INTO k734_conv_names VALUES
 ('function', '_can_view_game'),
 ('function', '_can_view_game_for_join'),
 ('function', '_is_game_host'),
 ('function', '_slot_conflicts_game'),
 ('function', 'active_stream'),
 ('function', 'admin_cleanup_user_data'),
 ('function', 'admin_overview_row'),
 ('function', 'can_current_user_join_game'),
 ('function', 'can_current_user_rsvp_meetup'),
 ('function', 'game_slots_left'),
 ('function', 'meetup_slots_left'),
 ('function', 'msg_authorize'),
 ('function', 'msg_evaluate'),
 ('function', 'msg_my_conversations'),
 ('function', 'rpc_booking_hold_for_meetup'),
 ('function', 'rpc_cancel_game_series'),
 ('function', 'rpc_edit_game_series_future'),
 ('function', 'rpc_edit_game_series_occurrence'),
 ('function', 'rpc_games_following_joined'),
 ('function', 'rpc_get_activity_feed'),
 ('function', 'rpc_get_nearby_games'),
 ('function', 'rpc_meetup_attendees'),
 ('function', 'rpc_meetup_card'),
 ('function', 'rpc_rate_game'),
 ('function', 'rpc_rate_user'),
 ('function', 'rpc_rate_venue'),
 ('function', 'rpc_sport_overview'),
 ('function', 'rpc_unified_search_sectioned'),
 ('function', 'settle_game'),
 ('function', 'trg_meetup_rsvps_notify'),
 ('function', 'trg_meetups_cancel_notify'),
 ('view', 'v_game_card'),
 ('view', 'v_host_weekly_metrics'),
 ('view', 'v_meetup_counts'),
 ('view', 'v_meetup_list'),
 ('view', 'v_my_games'),
 ('view', 'v_rateable_after_game')
;

\if :k734_snap
CREATE SCHEMA IF NOT EXISTS kan734_fx;
CREATE TABLE IF NOT EXISTS kan734_fx.preshape(kind text, ident text, shape text, PRIMARY KEY (kind, ident));
INSERT INTO kan734_fx.preshape
SELECT 'function', p.oid::regprocedure::text,
       pg_get_function_result(p.oid) || ' | secdef=' || p.prosecdef || ' | vol=' || p.provolatile::text || ' | cfg=' || coalesce(p.proconfig::text, '')
FROM pg_proc p JOIN k734_conv_names c ON c.kind = 'function' AND p.proname IN (c.name, c.name || '_kan712_inner')
WHERE p.pronamespace = 'public'::regnamespace
UNION ALL
SELECT 'view', c.oid::regclass::text, string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
FROM pg_class c JOIN k734_conv_names n ON n.kind = 'view' AND n.name = c.relname
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
WHERE c.relnamespace = 'public'::regnamespace GROUP BY c.oid
ON CONFLICT DO NOTHING;
SELECT 'KAN-734 snapshot: ' || count(*) || ' shapes recorded' AS snapshot FROM kan734_fx.preshape;
\quit
\endif

-- ---------------------------------------------------------------------------------------------
-- T0: every B01-B14 piece is applied. A marker object must exist and read public.events. For a
-- function that means the comment-stripped body, or its KAN-712 inner; for a view, pg_depend.
-- ---------------------------------------------------------------------------------------------
CREATE TEMP TABLE k734_t0(b text, ticket text, kind text, ident text);
INSERT INTO k734_t0 VALUES
 ('B01','KAN-720','view','v_game_card'),('B01','KAN-720','view','v_my_games'),
 ('B02','KAN-721','view','v_meetup_list'),('B02','KAN-721','view','v_meetup_counts'),
 ('B03','KAN-722','view','v_rateable_after_game'),
 ('B04','KAN-723','function','public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'),
 ('B04','KAN-723','function','public.rpc_games_following_joined(uuid[])'),
 ('B05','KAN-724','function','public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)'),
 ('B06','KAN-725','function','public.rpc_meetup_card(uuid,text)'),
 ('B06','KAN-725','function','public.rpc_meetup_attendees(uuid,text,integer,integer)'),
 ('B07','KAN-726','function','public.rpc_sport_overview(uuid,text)'),('B07','KAN-726','view','v_host_weekly_metrics'),
 ('B08','KAN-727','function','public.game_slots_left(uuid)'),('B08','KAN-727','function','public.meetup_slots_left(uuid)'),
 ('B09','KAN-728','function','public.rpc_booking_hold_for_meetup'),
 ('B09','KAN-728','function','public._slot_conflicts_game'),
 ('B10','KAN-729','function','public.settle_game(uuid,boolean)'),
 ('B11','KAN-730','function','public.msg_evaluate'),('B11','KAN-730','function','public.msg_my_conversations(integer)'),
 ('B12','KAN-731','function','public.rpc_get_activity_feed'),('B12','KAN-731','function','public.active_stream'),
 ('B13','KAN-732','function','public.admin_overview_row()'),('B13','KAN-732','function','public.admin_cleanup_user_data(uuid,boolean)'),
 ('B14','KAN-733','function','public.rpc_cancel_game_series_kan712_inner(uuid,text)'),
 ('B14','KAN-733','function','public.rpc_edit_game_series_occurrence_kan712_inner');

CREATE FUNCTION pg_temp.k734_src(p oid) RETURNS text LANGUAGE sql STABLE AS
$$ SELECT regexp_replace(regexp_replace(prosrc, '/\*([^*]|\*+[^*/])*\*+/', '', 'g'), '--[^\n]*', '', 'g') FROM pg_proc WHERE oid = p $$;

DO $t0$
DECLARE r record; ok boolean; bad text := '';
BEGIN
  FOR r IN SELECT * FROM k734_t0 LOOP
    IF r.kind = 'view' THEN
      SELECT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite w ON w.oid = d.objid
                     WHERE w.ev_class = to_regclass('public.' || r.ident) AND d.refobjid = 'public.events'::regclass) INTO ok;
    ELSIF position('(' IN r.ident) > 0 THEN
      ok := to_regprocedure(r.ident) IS NOT NULL AND pg_temp.k734_src(to_regprocedure(r.ident)) ~ '\m(public\.)?events\M';
    ELSE
      SELECT bool_or(pg_temp.k734_src(p.oid) ~ '\m(public\.)?events\M') INTO ok FROM pg_proc p
       WHERE p.pronamespace = 'public'::regnamespace AND p.proname = split_part(r.ident, '.', 2);
    END IF;
    IF NOT coalesce(ok, false) THEN bad := bad || format(' %s (%s) %s;', r.b, r.ticket, r.ident); END IF;
  END LOOP;
  IF bad <> '' THEN RAISE EXCEPTION 'KAN-734 T0 FAIL: B piece(s) not applied:%', bad; END IF;
  RAISE NOTICE 'KAN-734 T0 PASS: B01-B14 markers present and reading public.events (% markers)', (SELECT count(*) FROM k734_t0);
END $t0$;

-- ---------------------------------------------------------------------------------------------
-- The manifest: the matrix from KAN714_READ_MANIFEST.md.
--   kind: function | view | fk
--   ident: name(args) for functions; name for views; table.constraint for FKs
--   status: converted | unchanged | open;  code: the classifier's sub-reason
-- ---------------------------------------------------------------------------------------------
CREATE TEMP TABLE k734_manifest(kind text, name text, args text, status text, ticket text, code text, PRIMARY KEY (kind, name, args));
INSERT INTO k734_manifest VALUES
 ('fk', 'activity_events.activity_events_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'challenge_fixtures.challenge_fixtures_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'favorites.favorites_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'favorites.favorites_meetup_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:meetups'),
 ('fk', 'game_invites.game_invites_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'game_join_requests.game_join_requests_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'game_link_tokens.game_link_tokens_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'game_rating_aggregate.game_rating_aggregate_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'game_rating_events.game_rating_events_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'game_roster.game_roster_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'game_settlements.game_settlements_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'game_waitlist.game_waitlist_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'meetup_attendees.meetup_attendees_meetup_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:meetups'),
 ('fk', 'meetup_invites.meetup_invites_meetup_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:meetups'),
 ('fk', 'meetup_link_tokens.meetup_link_tokens_meetup_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:meetups'),
 ('fk', 'meetup_rsvps.meetup_rsvps_meetup_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:meetups'),
 ('fk', 'msg_conversations.msg_conversations_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'msg_conversations.msg_conversations_meetup_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:meetups'),
 ('fk', 'posts.posts_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'user_reputation_events.user_reputation_events_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('fk', 'venue_rating_events.venue_rating_events_game_id_fkey', '', 'unchanged', '-', 'fk-subtype-pk:games'),
 ('function', '_can_view_game', 'uuid', 'converted', 'KAN-713', 'K713'),
 ('function', '_can_view_game_for_join', 'uuid', 'converted', 'KAN-713', 'K713'),
 ('function', '_game_belongs_to_venue', 'uuid,uuid', 'unchanged', 'KAN-728 B09 (pinned)', 'pinned'),
 ('function', '_is_game_host', 'uuid', 'converted', 'KAN-713', 'K713'),
 ('function', '_meetup_link_consume', 'uuid,uuid', 'unchanged', '-', 'name-only'),
 ('function', '_meetup_link_valid', 'uuid,uuid', 'unchanged', '-', 'name-only'),
 ('function', '_recent_activity_score', 'uuid,integer', 'open', '-', 'open-read'),
 ('function', '_slot_conflicts_game', 'uuid,timestamp with time zone,timestamp with time zone', 'converted', 'KAN-728 B09', 'B'),
 ('function', '_user_hosted_game', 'uuid,uuid', 'open', '-', 'open-read'),
 ('function', '_user_played_in_game', 'uuid,uuid', 'unchanged', '-', 'name-only'),
 ('function', 'active_stream', 'text[],text,integer,timestamp with time zone,text,uuid', 'converted', 'KAN-731 B12', 'B'),
 ('function', 'actor_capabilities', 'text', 'unchanged', '-', 'noshared'),
 ('function', 'admin_cleanup_user_data', 'uuid,boolean', 'converted', 'KAN-732 B13', 'B'),
 ('function', 'admin_overview_row', '', 'converted', 'KAN-732 B13', 'B'),
 ('function', 'can_create_game', 'uuid,text', 'unchanged', '-', 'name-only'),
 ('function', 'can_create_meetup', 'uuid', 'unchanged', '-', 'name-only'),
 ('function', 'can_current_user_join_game', 'uuid,text,uuid', 'converted', 'KAN-713', 'K713'),
 ('function', 'can_current_user_rsvp_meetup', 'uuid,uuid', 'converted', 'KAN-713', 'K713'),
 ('function', 'can_join_game', 'uuid', 'unchanged', '-', 'name-only'),
 ('function', 'can_view_game', 'uuid,uuid', 'unchanged', '-', 'name-only'),
 ('function', 'compute_game_fingerprint', 'jsonb', 'unchanged', '-', 'name-only'),
 ('function', 'compute_meetup_fingerprint', 'jsonb', 'unchanged', '-', 'name-only'),
 ('function', 'events_check_parent_children', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'events_check_series_occurrence', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'events_check_subtype_link', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'fill_game_with_seed_profiles', 'uuid,uuid,text,integer,uuid[]', 'unchanged', '-', 'name-only'),
 ('function', 'fn_game_roster_activity_sync', '', 'unchanged', '-', 'trigger'),
 ('function', 'fn_games_activity_sync', '', 'unchanged', '-', 'trigger'),
 ('function', 'fn_games_inherit_geo', '', 'unchanged', '-', 'name-only'),
 ('function', 'fn_games_sync_joining_rule', '', 'unchanged', '-', 'name-only'),
 ('function', 'fn_generate_game_series_occurrences', 'uuid', 'unchanged', 'KAN-733 B14 (pinned)', 'pinned'),
 ('function', 'fn_meetup_rsvps_activity_sync', '', 'unchanged', '-', 'trigger'),
 ('function', 'fn_meetups_activity_sync', '', 'unchanged', '-', 'trigger'),
 ('function', 'fn_meetups_enforce_solo_sport', '', 'unchanged', '-', 'trigger'),
 ('function', 'fn_meetups_inherit_geo', '', 'unchanged', '-', 'name-only'),
 ('function', 'fn_meetups_sync_joining_rule', '', 'unchanged', '-', 'name-only'),
 ('function', 'game_is_joinable', 'uuid', 'open', '-', 'open-read'),
 ('function', 'game_rating_rebuild_all', '', 'unchanged', '-', 'noshared'),
 ('function', 'game_rating_recompute', 'uuid', 'unchanged', '-', 'name-only'),
 ('function', 'game_slots_left', 'uuid', 'converted', 'KAN-727 B08', 'B'),
 ('function', 'get_games_needing_players', '', 'open', '-', 'open-read'),
 ('function', 'get_nearby_games', 'double precision,double precision,double precision', 'open', '-', 'open-read'),
 ('function', 'get_nearby_games', 'double precision,double precision,integer', 'open', '-', 'open-read'),
 ('function', 'get_open_games_for_seeding', '', 'open', '-', 'open-read'),
 ('function', 'get_seed_profiles_for_games', '', 'unchanged', '-', 'name-only'),
 ('function', 'getnearbygames', 'double precision,double precision,double precision', 'open', '-', 'open-read'),
 ('function', 'getnearbymeetups', 'double precision,double precision,double precision', 'open', '-', 'open-read'),
 ('function', 'handle_game_created', '', 'unchanged', '-', 'name-only'),
 ('function', 'handle_player_joined_game', '', 'unchanged', '-', 'name-only'),
 ('function', 'kan711_events_backfill_batch', 'text,integer', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan711_events_backfill_run', 'integer,integer', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan711_events_map_game', 'games', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan711_events_map_meetup', 'meetups', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan711_events_validate_links', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan711_games_mirror', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan711_meetups_mirror', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan712_events_compat_mirror', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan712_legacy_after_delete', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan712_legacy_guard', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan712_wrap_rpc', 'regprocedure,text', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan713_events_location', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan713_games_joining', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan713_games_location', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan713_games_venue_geo', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan713_meetup_attendee_visible', 'uuid', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan713_meetup_can_read_row', 'uuid', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan713_meetup_can_write_row', 'uuid', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan713_meetup_visible', 'uuid', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan713_meetups_joining', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan713_meetups_location', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'kan718_series_occurrence_guard', '', 'unchanged', 'KAN-71x infra', 'infra'),
 ('function', 'meetup_counts', 'uuid', 'open', '-', 'open-read'),
 ('function', 'meetup_my_status', 'uuid,uuid', 'unchanged', '-', 'name-only'),
 ('function', 'meetup_slots_left', 'uuid', 'converted', 'KAN-727 B08', 'B'),
 ('function', 'meetups_search_tsv_trigger', '', 'unchanged', '-', 'name-only'),
 ('function', 'msg_authorize', 'uuid,text', 'converted', 'KAN-730 B11', 'B'),
 ('function', 'msg_evaluate', 'uuid,uuid,text', 'converted', 'KAN-730 B11', 'B'),
 ('function', 'msg_game_conversation', 'uuid,text', 'unchanged', 'KAN-730 B11 (pinned)', 'pinned'),
 ('function', 'msg_my_conversations', 'integer', 'converted', 'KAN-730 B11', 'B'),
 ('function', 'msg_my_conversations_v1', 'integer', 'unchanged', '-', 'legacy'),
 ('function', 'msg_system_game_trg', '', 'unchanged', '-', 'name-only'),
 ('function', 'nearby_games', 'double precision,double precision,integer,text,integer,integer', 'open', '-', 'open-read'),
 ('function', 'normalize_game_scores', 'jsonb', 'unchanged', '-', 'name-only'),
 ('function', 'process_notification_event', 'uuid,text,text,uuid,uuid,text,text', 'unchanged', '-', 'fp'),
 ('function', 'rpc_autocomplete_entities', 'text,text[],text,integer', 'open', '-', 'open-read'),
 ('function', 'rpc_booking_cancel', 'uuid', 'unchanged', 'KAN-728 B09 (pinned)', 'pinned'),
 ('function', 'rpc_booking_hold_for_game', 'uuid,uuid,timestamp with time zone,timestamp with time zone', 'unchanged', 'KAN-728 B09 (pinned)', 'pinned'),
 ('function', 'rpc_booking_hold_for_meetup', 'uuid,uuid,timestamp with time zone,timestamp with time zone', 'converted', 'KAN-728 B09', 'B'),
 ('function', 'rpc_cancel_game', 'uuid,text', 'unchanged', 'KAN-733 B14 (pinned)', 'pinned'),
 ('function', 'rpc_cancel_game_series', 'uuid,text', 'converted', 'KAN-733 B14', 'B'),
 ('function', 'rpc_challenge_spawn_game', 'uuid,timestamp with time zone,uuid', 'open', '-', 'open-write'),
 ('function', 'rpc_create_game', 'text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid', 'open', '-', 'open-write'),
 ('function', 'rpc_create_game_legacy_v1', 'text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer', 'unchanged', '-', 'legacy'),
 ('function', 'rpc_create_game_legacy_v2', 'text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric', 'unchanged', '-', 'legacy'),
 ('function', 'rpc_create_game_series', 'text,uuid,uuid,uuid,uuid,date,time without time zone,integer,text,text,integer,text,uuid,date,text,text,integer,numeric', 'unchanged', '-', 'name-only'),
 ('function', 'rpc_create_meetup', 'text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid', 'open', '-', 'open-write'),
 ('function', 'rpc_create_meetup_legacy_v1', 'text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb', 'unchanged', '-', 'legacy'),
 ('function', 'rpc_create_meetup_legacy_v2', 'text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean', 'unchanged', '-', 'legacy'),
 ('function', 'rpc_decide_join_request', 'uuid,boolean', 'open', '-', 'open-write'),
 ('function', 'rpc_draft_publish_game', 'uuid', 'unchanged', '-', 'name-only'),
 ('function', 'rpc_draft_publish_meetup', 'uuid', 'unchanged', '-', 'name-only'),
 ('function', 'rpc_edit_game_series_future', 'uuid,text,integer,time without time zone,integer,uuid,date,boolean', 'converted', 'KAN-733 B14', 'B'),
 ('function', 'rpc_edit_game_series_occurrence', 'uuid,text,timestamp with time zone,timestamp with time zone,integer,uuid', 'converted', 'KAN-733 B14', 'B'),
 ('function', 'rpc_games_following_joined', 'uuid[]', 'converted', 'KAN-723 B04', 'B'),
 ('function', 'rpc_get_activity_feed', 'text,integer,timestamp with time zone', 'converted', 'KAN-731 B12', 'B'),
 ('function', 'rpc_get_nearby_games', 'double precision,double precision,integer,uuid,text', 'converted', 'KAN-723 B04', 'B'),
 ('function', 'rpc_get_nearby_games', 'double precision,double precision,integer,uuid,text,numeric', 'converted', 'KAN-723 B04', 'B'),
 ('function', 'rpc_get_nearby_games_legacy_v1', 'double precision,double precision,integer,uuid,text', 'unchanged', '-', 'legacy'),
 ('function', 'rpc_invite_user', 'uuid,uuid', 'open', '-', 'open-write'),
 ('function', 'rpc_join_game', 'text,uuid,uuid', 'open', '-', 'open-write'),
 ('function', 'rpc_leave_game', 'text,uuid', 'unchanged', '-', 'name-only'),
 ('function', 'rpc_meetup_attendees', 'uuid,text,integer,integer', 'converted', 'KAN-725 B06', 'B'),
 ('function', 'rpc_meetup_cancel', 'uuid', 'unchanged', 'KAN-712 write', 'write'),
 ('function', 'rpc_meetup_card', 'uuid,text', 'converted', 'KAN-725 B06', 'B'),
 ('function', 'rpc_meetup_decide_request', 'uuid,uuid,text', 'open', '-', 'open-write'),
 ('function', 'rpc_meetup_invite_user', 'uuid,uuid,timestamp with time zone', 'open', '-', 'open-write'),
 ('function', 'rpc_meetup_mint_link', 'uuid,timestamp with time zone,integer', 'open', '-', 'open-write'),
 -- rpc_meetup_my(): RETIRED by KAN-785 (migration 20261104110400, DROP FUNCTION); no longer probed. Manifest row 73 keeps the history.
 ('function', 'rpc_meetup_remove_attendee', 'uuid,uuid', 'open', '-', 'open-write'),
 ('function', 'rpc_meetup_rsvp', 'uuid,text,uuid,uuid', 'open', '-', 'open-write'),
 ('function', 'rpc_meetup_set_attendee', 'uuid,uuid,text', 'open', '-', 'open-write'),
 ('function', 'rpc_meetup_update', 'uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer', 'unchanged', 'KAN-712 write', 'write'),
 ('function', 'rpc_meetup_visible', '', 'open', '-', 'open-read'),
 ('function', 'rpc_mint_join_link', 'uuid,timestamp with time zone,integer', 'open', '-', 'open-write'),
 ('function', 'rpc_rate_game', 'uuid,uuid,jsonb,text', 'converted', 'KAN-727 B08', 'B'),
 ('function', 'rpc_rate_user', 'uuid,uuid,uuid,jsonb,text', 'converted', 'KAN-727 B08', 'B'),
 ('function', 'rpc_rate_venue', 'uuid,uuid,uuid,jsonb,text', 'converted', 'KAN-727 B08', 'B'),
 ('function', 'rpc_recreate_from_game', 'uuid,boolean', 'open', '-', 'open-write'),
 ('function', 'rpc_remove_player', 'uuid,uuid', 'open', '-', 'open-write'),
 ('function', 'rpc_reschedule_game', 'uuid,timestamp with time zone,timestamp with time zone', 'unchanged', 'KAN-712 write', 'write'),
 ('function', 'rpc_search_entities', 'text,text[],text,integer', 'open', '-', 'open-read'),
 ('function', 'rpc_sport_overview', 'uuid,text', 'converted', 'KAN-726 B07', 'B'),
 ('function', 'rpc_unified_search_sectioned', 'text,uuid,double precision,double precision,double precision,integer', 'converted', 'KAN-724 B05', 'B'),
 ('function', 'rpc_update_game', 'uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric', 'unchanged', 'KAN-712 write', 'write'),
 ('function', 'rpc_update_game_legacy_v1', 'uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer', 'unchanged', 'KAN-712 write', 'write'),
 ('function', 'schedule_game_reminders_for_user', 'uuid,uuid,timestamp with time zone,jsonb', 'unchanged', '-', 'name-only'),
 ('function', 'settle_game', 'uuid,boolean', 'converted', 'KAN-729 B10', 'B'),
 ('function', 'sync_game_geo', '', 'unchanged', '-', 'name-only'),
 ('function', 'trg_after_game_rating_event', '', 'unchanged', '-', 'name-only'),
 ('function', 'trg_fn_games_inherit_sport_from_space', '', 'unchanged', '-', 'name-only'),
 ('function', 'trg_fn_games_inherit_venue_geo', '', 'unchanged', '-', 'name-only'),
 ('function', 'trg_fn_games_require_challenge_sport', '', 'unchanged', '-', 'name-only'),
 ('function', 'trg_game_invite_notify', '', 'unchanged', '-', 'name-only'),
 ('function', 'trg_game_join_request_notify', '', 'unchanged', '-', 'trigger'),
 ('function', 'trg_game_updated_notify', '', 'unchanged', '-', 'name-only'),
 ('function', 'trg_game_waitlist_promoted_notify', '', 'unchanged', '-', 'trigger'),
 ('function', 'trg_games_set_search_tsv', '', 'unchanged', '-', 'name-only'),
 ('function', 'trg_meetup_invite_notify', '', 'unchanged', '-', 'name-only'),
 ('function', 'trg_meetup_rsvps_notify', '', 'converted', 'KAN-731 B12', 'B'),
 ('function', 'trg_meetups_cancel_notify', '', 'converted', 'KAN-731 B12', 'B'),
 ('function', 'trg_welcome_notify', '', 'unchanged', '-', 'trigger'),
 ('function', 'trgfn_games_block_frozen', '', 'unchanged', '-', 'name-only'),
 ('function', 'trgfn_games_set_host_user', '', 'unchanged', '-', 'name-only'),
 ('function', 'trgfn_invite_block_frozen', '', 'unchanged', '-', 'trigger'),
 ('function', 'trgfn_invite_block_frozen_guard', '', 'open', '-', 'open-trigger'),
 ('function', 'trgfn_joinreq_block_frozen_guard', '', 'open', '-', 'open-trigger'),
 ('function', 'trgfn_meetups_outbox', '', 'unchanged', '-', 'name-only'),
 ('function', 'trgfn_norm_game_scores', '', 'unchanged', '-', 'name-only'),
 ('function', 'trgfn_posts_set_geo', '', 'open', '-', 'open-trigger'),
 ('function', 'trgfn_roster_block_frozen_guard', '', 'open', '-', 'open-trigger'),
 ('function', 'trgfn_waitlist_block_frozen_guard', '', 'open', '-', 'open-trigger'),
 ('view', 'kan711_events_parity', '', 'unchanged', 'KAN-711', 'infra'),
 ('view', 'v_game_card', '', 'converted', 'KAN-720 B01', 'B'),
 ('view', 'v_game_rating', '', 'unchanged', '-', 'noshared'),
 ('view', 'v_host_weekly_metrics', '', 'converted', 'KAN-726 B07', 'B'),
 ('view', 'v_meetup_counts', '', 'converted', 'KAN-721 B02', 'B'),
 ('view', 'v_meetup_list', '', 'converted', 'KAN-721 B02', 'B'),
 ('view', 'v_my_games', '', 'converted', 'KAN-720 B01', 'B'),
 ('view', 'v_rateable_after_game', '', 'converted', 'KAN-722 B03', 'B')
;
\if :corrupt
-- swap two rows so the totals (C1) still match: only a catalogue re-derivation can catch it
UPDATE k734_manifest SET status = 'converted', ticket = 'CORRUPT', code = 'B' WHERE kind = 'function' AND name = 'rpc_join_game';
UPDATE k734_manifest SET status = 'open', ticket = 'CORRUPT', code = 'open-read' WHERE kind = 'function' AND name = 'rpc_sport_overview';
\echo '-- corrupt=1: rpc_join_game open->converted and rpc_sport_overview converted->open (negative control; totals unchanged)'
\endif

-- Local functions, keyed the way the manifest keys them. A KAN-712 inner is folded onto its
-- wrapper identity; the effective body is the inner's when one exists. Harness-only reference
-- functions are excluded.
CREATE TEMP TABLE k734_local AS
SELECT regexp_replace(p.proname, '_kan712_inner$', '') AS name,
       replace(oidvectortypes(p.proargtypes), ', ', ',') AS args,
       bool_or(p.proname ~ '_kan712_inner$') AS has_inner,
       string_agg(pg_temp.k734_src(p.oid), E'\n' ORDER BY p.proname DESC) AS src,
       array_agg(p.oid ORDER BY p.proname DESC) AS oids
FROM pg_proc p
WHERE p.pronamespace = 'public'::regnamespace AND p.prokind IN ('f','p')
  AND p.proname !~ '^(k7\d\d_ref_|b\d\d_ref_|harness_)'
  AND p.prolang <> (SELECT oid FROM pg_language WHERE lanname = 'c')
GROUP BY 1, 2;
-- effective body: the inner first when one exists (ORDER BY proname DESC puts _kan712_inner first).
-- A candidate is what the repo scan calls one: the body or signature names games/meetups, or the name
-- contains game/meetup.
CREATE TEMP TABLE k734_cand AS
SELECT l.* FROM k734_local l
WHERE l.src ~ '\m(games|meetups)\M' OR l.args ~ '\m(games|meetups)\M' OR l.name ~* '(game|meetup)';

CREATE TEMP VIEW k734_shared(c) AS SELECT unnest(ARRAY['title','creator_profile_id','creator_user_id','start_at','end_at','capacity',
 'listing_visibility','join_policy','rsvp_policy','min_skill','max_skill','is_cancelled','cancelled_at','cancelled_reason','sport_id',
 'geo_location_id','area_id','venue_id','joining_rule','cost_cover','request_id','search_tsv']);

-- residual legacy shared-column refs: alias.sharedcol where alias binds games/meetups (textual)
CREATE TEMP TABLE k734_resid AS
WITH al AS (
  SELECT c.name, c.args, lower(m[2]) a FROM k734_cand c, regexp_matches(c.src, '\m(?:public\.)?(games|meetups)\s+(?:as\s+)?([A-Za-z_][A-Za-z0-9_]*)', 'gi') m
   WHERE lower(m[2]) NOT IN ('where','on','join','left','right','inner','set','using','for','order','group','limit','union','returning','select',
     'values','when','then','and','or','as','cross','full','natural','lateral','into','except','having','window','offset','fetch','default','loop','is')
  UNION SELECT c.name, c.args, lower(m[1]) FROM k734_cand c, regexp_matches(c.src, '\m([A-Za-z_][A-Za-z0-9_]*)\s+(?:public\.)?(?:games|meetups)(?:%rowtype)?\s*;', 'gi') m
  UNION SELECT c.name, c.args, lower(m[1]) FROM k734_cand c, regexp_matches(c.src, '(?:public\.)?(games|meetups)\.', 'gi') m)
SELECT c.name || '(' || c.args || ')' AS ident, string_agg(DISTINCT a.a || '.' || s.c, ',') AS refs
FROM k734_cand c JOIN al a USING (name, args) CROSS JOIN k734_shared s
WHERE c.src ~* ('\m' || a.a || '\.' || s.c || '\M') GROUP BY 1;

CREATE TEMP TABLE k734_sets AS
SELECT 'present' AS s, string_agg(m.name || '(' || m.args || ')', '; ' ORDER BY m.name, m.args) AS v
  FROM k734_manifest m JOIN k734_local l USING (name, args) WHERE m.kind = 'function'
UNION ALL SELECT 'conv_no_events', string_agg(m.name || '(' || m.args || ')', '; ' ORDER BY m.name, m.args)
  FROM k734_manifest m JOIN k734_local l USING (name, args) WHERE m.kind = 'function' AND m.status = 'converted' AND l.src !~ '\m(public\.)?events\M'
UNION ALL SELECT 'resid', string_agg(ident, '; ' ORDER BY ident) FROM k734_resid
UNION ALL SELECT 'rowtype', string_agg(DISTINCT c.name || '(' || c.args || ')', '; ')
  FROM k734_cand c WHERE c.src ~* '\m[A-Za-z_][A-Za-z0-9_]*\s+(public\.)?(games|meetups|events)%rowtype'
UNION ALL SELECT 'composite', string_agg(p.oid::regprocedure::text || '->' || pg_get_function_result(p.oid), '; ' ORDER BY p.oid::regprocedure::text)
  FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
   AND (p.prorettype IN ('public.games'::regtype, 'public.meetups'::regtype, 'public.events'::regtype)
     OR p.proargtypes::oid[] && ARRAY['public.games'::regtype, 'public.meetups'::regtype, 'public.events'::regtype]::oid[]
     OR coalesce(p.proallargtypes, '{}') && ARRAY['public.games'::regtype, 'public.meetups'::regtype, 'public.events'::regtype]::oid[])
UNION ALL SELECT 'typed_columns', string_agg(attrelid::regclass || '.' || attname, '; ')
  FROM pg_attribute WHERE atttypid IN ('public.games'::regtype, 'public.meetups'::regtype, 'public.events'::regtype) AND NOT attisdropped
UNION ALL SELECT 'dynamic', string_agg(c.name || '(' || c.args || ')', '; ' ORDER BY c.name, c.args)
  FROM k734_cand c WHERE c.src ~* '\mexecute\M'
UNION ALL SELECT 'transitive', string_agg(DISTINCT cr.name || '->' || ce.name, '; ')
  FROM k734_manifest cr JOIN k734_local lc ON lc.name = cr.name AND lc.args = cr.args
  JOIN k734_manifest ce ON ce.kind = 'function' AND ce.status = 'open' AND ce.name <> cr.name
  WHERE cr.kind = 'function' AND cr.status = 'converted' AND lc.src ~ ('\m' || ce.name || '\s*\(');

\if :k734_derive
SELECT * FROM k734_sets ORDER BY 1;
SELECT * FROM k734_resid ORDER BY 1;
SELECT name || '(' || args || ')' AS unmanifested_candidate FROM k734_cand c
 WHERE NOT EXISTS (SELECT 1 FROM k734_manifest m WHERE m.kind = 'function' AND m.name = c.name AND m.args = c.args) ORDER BY 1;
\quit
\endif

DO $c$
DECLARE n record; v text; miss text; e text;
  exp_present text := '_can_view_game(uuid); _can_view_game_for_join(uuid); _game_belongs_to_venue(uuid,uuid); _is_game_host(uuid); _meetup_link_valid(uuid,uuid); _slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone); _user_hosted_game(uuid,uuid); _user_played_in_game(uuid,uuid); active_stream(text[],text,integer,timestamp with time zone,text,uuid); admin_cleanup_user_data(uuid,boolean); admin_overview_row(); can_current_user_join_game(uuid,text,uuid); can_current_user_rsvp_meetup(uuid,uuid); events_check_parent_children(); events_check_series_occurrence(); events_check_subtype_link(); fn_games_activity_sync(); fn_games_inherit_geo(); fn_games_sync_joining_rule(); fn_generate_game_series_occurrences(uuid); fn_meetups_activity_sync(); fn_meetups_enforce_solo_sport(); fn_meetups_inherit_geo(); fn_meetups_sync_joining_rule(); game_rating_recompute(uuid); game_slots_left(uuid); handle_game_created(); kan711_events_backfill_batch(text,integer); kan711_events_backfill_run(integer,integer); kan711_events_map_game(games); kan711_events_map_meetup(meetups); kan711_events_validate_links(); kan711_games_mirror(); kan711_meetups_mirror(); kan712_events_compat_mirror(); kan712_legacy_after_delete(); kan712_legacy_guard(); kan712_wrap_rpc(regprocedure,text); kan713_events_location(); kan713_games_joining(); kan713_games_location(); kan713_games_venue_geo(); kan713_meetup_attendee_visible(uuid); kan713_meetup_can_read_row(uuid); kan713_meetup_can_write_row(uuid); kan713_meetup_visible(uuid); kan713_meetups_joining(); kan713_meetups_location(); kan718_series_occurrence_guard(); meetup_counts(uuid); meetup_slots_left(uuid); meetups_search_tsv_trigger(); msg_authorize(uuid,text); msg_evaluate(uuid,uuid,text); msg_game_conversation(uuid,text); msg_my_conversations(integer); msg_system_game_trg(); process_notification_event(uuid,text,text,uuid,uuid,text,text); rpc_booking_cancel(uuid); rpc_booking_hold_for_game(uuid,uuid,timestamp with time zone,timestamp with time zone); rpc_booking_hold_for_meetup(uuid,uuid,timestamp with time zone,timestamp with time zone); rpc_cancel_game(uuid,text); rpc_cancel_game_series(uuid,text); rpc_challenge_spawn_game(uuid,timestamp with time zone,uuid); rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid); rpc_create_game_legacy_v1(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer); rpc_create_game_legacy_v2(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric); rpc_create_game_series(text,uuid,uuid,uuid,uuid,date,time without time zone,integer,text,text,integer,text,uuid,date,text,text,integer,numeric); rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid); rpc_create_meetup_legacy_v1(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb); rpc_create_meetup_legacy_v2(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean); rpc_edit_game_series_future(uuid,text,integer,time without time zone,integer,uuid,date,boolean); rpc_edit_game_series_occurrence(uuid,text,timestamp with time zone,timestamp with time zone,integer,uuid); rpc_games_following_joined(uuid[]); rpc_get_activity_feed(text,integer,timestamp with time zone); rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric); rpc_join_game(text,uuid,uuid); rpc_meetup_attendees(uuid,text,integer,integer); rpc_meetup_cancel(uuid); rpc_meetup_card(uuid,text); rpc_meetup_update(uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer); rpc_rate_game(uuid,uuid,jsonb,text); rpc_rate_user(uuid,uuid,uuid,jsonb,text); rpc_rate_venue(uuid,uuid,uuid,jsonb,text); rpc_reschedule_game(uuid,timestamp with time zone,timestamp with time zone); rpc_sport_overview(uuid,text); rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer); rpc_update_game(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric); rpc_update_game_legacy_v1(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer); settle_game(uuid,boolean); trg_fn_games_inherit_sport_from_space(); trg_fn_games_inherit_venue_geo(); trg_fn_games_require_challenge_sport(); trg_game_updated_notify(); trg_games_set_search_tsv(); trg_meetup_rsvps_notify(); trg_meetups_cancel_notify(); trgfn_games_set_host_user(); trgfn_meetups_outbox()';
  exp_conv_noev text := '';
  exp_resid text := '_can_view_game(uuid); _can_view_game_for_join(uuid); _is_game_host(uuid); _slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone); _user_hosted_game(uuid,uuid); active_stream(text[],text,integer,timestamp with time zone,text,uuid); can_current_user_join_game(uuid,text,uuid); can_current_user_rsvp_meetup(uuid,uuid); fn_generate_game_series_occurrences(uuid); game_slots_left(uuid); kan712_events_compat_mirror(); meetup_counts(uuid); rpc_create_game(text,uuid,uuid,text,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,integer,integer,jsonb,uuid,boolean,boolean,jsonb,text,uuid,uuid,double precision,double precision,integer,integer,numeric,uuid); rpc_create_meetup(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb,boolean,uuid); rpc_edit_game_series_future(uuid,text,integer,time without time zone,integer,uuid,date,boolean); rpc_get_activity_feed(text,integer,timestamp with time zone); rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric); rpc_meetup_cancel(uuid); rpc_meetup_update(uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer); rpc_rate_game(uuid,uuid,jsonb,text); rpc_rate_user(uuid,uuid,uuid,jsonb,text); rpc_rate_venue(uuid,uuid,uuid,jsonb,text); rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer); rpc_update_game(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric); rpc_update_game_legacy_v1(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer)';
  exp_rowtype text := 'can_current_user_join_game(uuid,text,uuid); can_current_user_rsvp_meetup(uuid,uuid); rpc_meetup_update(uuid,text,text,timestamp with time zone,timestamp with time zone,text,integer)';
  exp_composite text := 'kan711_events_map_game(games)->events; kan711_events_map_meetup(meetups)->events; kan711_events_upsert(events)->void';
  exp_dynamic text := 'admin_cleanup_user_data(uuid,boolean); kan711_events_backfill_batch(text,integer); kan712_wrap_rpc(regprocedure,text)';
  exp_transitive text := 'rpc_rate_venue->_user_hosted_game';
BEGIN
  -- C1 matrix totals per category
  SELECT string_agg(kind || ':' || status || '=' || c, ' ' ORDER BY kind, status) INTO v
    FROM (SELECT kind, status, count(*) c FROM k734_manifest GROUP BY 1, 2) x;
  IF v IS DISTINCT FROM 'fk:unchanged=21 function:converted=32 function:open=34 function:unchanged=94 view:converted=6 view:unchanged=2' THEN RAISE EXCEPTION 'KAN-734 C1 FAIL: manifest totals % <> expected fk:unchanged=21 function:converted=32 function:open=34 function:unchanged=94 view:converted=6 view:unchanged=2', v; END IF;
  RAISE NOTICE 'KAN-734 C1 PASS: totals %', v;

  -- C2 every local candidate function is in the manifest (coverage is complete for this catalogue)
  SELECT string_agg(name || '(' || args || ')', ' ') INTO miss FROM k734_cand c
   WHERE NOT EXISTS (SELECT 1 FROM k734_manifest m WHERE m.kind = 'function' AND m.name = c.name AND m.args = c.args);
  IF miss IS NOT NULL THEN RAISE EXCEPTION 'KAN-734 C2 FAIL: local candidate(s) missing from manifest: %', miss; END IF;
  RAISE NOTICE 'KAN-734 C2 PASS: all % local candidate functions are in the manifest', (SELECT count(*) FROM k734_cand);

  -- C3 the manifest rows present in this catalogue are exactly the expected set
  SELECT s.v INTO v FROM k734_sets s WHERE s.s = 'present';
  IF v IS DISTINCT FROM exp_present THEN RAISE EXCEPTION 'KAN-734 C3 FAIL: present set drifted: got [%]', v; END IF;
  RAISE NOTICE 'KAN-734 C3 PASS: % manifest functions present locally, as expected', array_length(string_to_array(v, '; '), 1);

  -- C4 every converted+present row reads events, except the named helper-routed set
  SELECT s.v INTO v FROM k734_sets s WHERE s.s = 'conv_no_events';
  IF v IS DISTINCT FROM nullif(exp_conv_noev, '') THEN RAISE EXCEPTION 'KAN-734 C4 FAIL: converted-without-events set [%] <> expected [%]', v, exp_conv_noev; END IF;
  RAISE NOTICE 'KAN-734 C4 PASS: converted rows read events (helper-routed exceptions: %)', coalesce(v, 'none');

  -- C5 every open+present row is still coupled to games/meetups (open means not yet converted)
  SELECT string_agg(m.name, ' ') INTO miss FROM k734_manifest m JOIN k734_local l USING (name, args)
   WHERE m.kind = 'function' AND m.status = 'open' AND l.src !~ '\m(games|meetups)\M';
  IF miss IS NOT NULL THEN RAISE EXCEPTION 'KAN-734 C5 FAIL: open row(s) no longer reference games/meetups: %', miss; END IF;
  RAISE NOTICE 'KAN-734 C5 PASS: open rows present locally still read legacy tables';

  -- C6 residual legacy shared-column refs (phase-4 DROP COLUMN blockers)
  SELECT s.v INTO v FROM k734_sets s WHERE s.s = 'resid';
  IF v IS DISTINCT FROM exp_resid THEN RAISE EXCEPTION 'KAN-734 C6 FAIL: residual-ref set drifted: got [%]', v; END IF;
  RAISE NOTICE 'KAN-734 C6 PASS: % functions keep legacy shared-column refs (listed in manifest)', array_length(string_to_array(v, '; '), 1);

  -- C7 %rowtype declarations of games/meetups/events
  SELECT s.v INTO v FROM k734_sets s WHERE s.s = 'rowtype';
  IF v IS DISTINCT FROM exp_rowtype THEN RAISE EXCEPTION 'KAN-734 C7 FAIL: rowtype set drifted: got [%]', v; END IF;
  RAISE NOTICE 'KAN-734 C7 PASS: rowtype declarations: %', v;

  -- C8 composite (table-typed) args/results; no column typed as a table row; no whole-row view dep
  SELECT s.v INTO v FROM k734_sets s WHERE s.s = 'composite';
  IF v IS DISTINCT FROM exp_composite THEN RAISE EXCEPTION 'KAN-734 C8 FAIL: composite arg/result set drifted: got [%]', v; END IF;
  SELECT s.v INTO e FROM k734_sets s WHERE s.s = 'typed_columns';
  IF e IS NOT NULL THEN RAISE EXCEPTION 'KAN-734 C8 FAIL: column(s) typed as games/meetups/events: %', e; END IF;
  IF EXISTS (SELECT 1 FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid
             WHERE d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass) AND d.refobjsubid = 0 AND r.ev_class <> d.refobjid) THEN
    RAISE EXCEPTION 'KAN-734 C8 FAIL: a view has a whole-row dependency on games/meetups';
  END IF;
  RAISE NOTICE 'KAN-734 C8 PASS: composite signatures: %; no typed columns; no whole-row view deps', v;

  -- C9 views: none depends on a shared column of games/meetups; the set reading games/meetups/events = manifest views
  SELECT string_agg(r.ev_class::regclass || ':' || a.attname, ' ') INTO e FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid
    JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
   WHERE d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass) AND r.ev_class <> d.refobjid
     AND a.attname IN (SELECT c FROM k734_shared) AND r.ev_class::regclass::text <> 'kan711_events_parity';
  IF e IS NOT NULL THEN RAISE EXCEPTION 'KAN-734 C9 FAIL: view(s) depend on legacy shared columns: %', e; END IF;
  SELECT string_agg(DISTINCT r.ev_class::regclass::text, ' ') INTO v FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid
   WHERE d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND r.ev_class <> d.refobjid;
  SELECT string_agg(name, ' ' ORDER BY name) INTO e FROM k734_manifest WHERE kind = 'view';
  IF v IS DISTINCT FROM e THEN RAISE EXCEPTION 'KAN-734 C9 FAIL: views reading games/meetups/events [%] <> manifest views [%]', v, e; END IF;
  RAISE NOTICE 'KAN-734 C9 PASS: % views; no shared-column dependency outside KAN-711 parity infra', array_length(string_to_array(v, ' '), 1);

  -- C10 dynamic SQL (EXECUTE) among candidates
  SELECT s.v INTO v FROM k734_sets s WHERE s.s = 'dynamic';
  IF v IS DISTINCT FROM exp_dynamic THEN RAISE EXCEPTION 'KAN-734 C10 FAIL: dynamic-SQL set drifted: got [%]', v; END IF;
  RAISE NOTICE 'KAN-734 C10 PASS: dynamic SQL in: %', v;

  -- C11 transitive: converted callers that still call an OPEN helper
  SELECT s.v INTO v FROM k734_sets s WHERE s.s = 'transitive';
  IF v IS DISTINCT FROM nullif(exp_transitive, '') THEN RAISE EXCEPTION 'KAN-734 C11 FAIL: transitive set [%] <> expected [%]', v, exp_transitive; END IF;
  RAISE NOTICE 'KAN-734 C11 PASS: converted -> open calls: %', coalesce(v, 'none');

  -- C12 inbound FKs: every local FK into games/meetups is in the manifest and targets the subtype PK (id)
  SELECT string_agg(c.conrelid::regclass || '.' || c.conname, ' ') INTO miss FROM pg_constraint c
   WHERE c.contype = 'f' AND c.confrelid IN ('public.games'::regclass, 'public.meetups'::regclass)
     AND NOT EXISTS (SELECT 1 FROM k734_manifest m WHERE m.kind = 'fk' AND m.name = c.conrelid::regclass::text || '.' || c.conname);
  IF miss IS NOT NULL THEN RAISE EXCEPTION 'KAN-734 C12 FAIL: local FK(s) missing from manifest: %', miss; END IF;
  SELECT string_agg(c.conrelid::regclass || '.' || c.conname, ' ') INTO miss FROM pg_constraint c
   WHERE c.contype = 'f' AND c.confrelid IN ('public.games'::regclass, 'public.meetups'::regclass)
     AND c.confkey <> ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid = c.confrelid AND attname = 'id')]::int2[];
  IF miss IS NOT NULL THEN RAISE EXCEPTION 'KAN-734 C12 FAIL: FK(s) not targeting id: %', miss; END IF;
  RAISE NOTICE 'KAN-734 C12 PASS: % local inbound FKs, all in manifest, all target the kept subtype id', (SELECT count(*) FROM pg_constraint c WHERE c.contype = 'f' AND c.confrelid IN ('public.games'::regclass, 'public.meetups'::regclass));

  -- C13 legacy shapes unchanged: every pre-image shape recorded by mode=snapshot still holds
  IF to_regclass('kan734_fx.preshape') IS NULL THEN RAISE EXCEPTION 'KAN-734 C13 FAIL: kan734_fx.preshape missing (run mode=snapshot before the B migrations)'; END IF;
  SELECT string_agg(s.ident, ' ') INTO miss FROM kan734_fx.preshape s
   WHERE s.shape IS DISTINCT FROM (
     CASE s.kind WHEN 'function' THEN (SELECT pg_get_function_result(p.oid) || ' | secdef=' || p.prosecdef || ' | vol=' || p.provolatile::text || ' | cfg=' || coalesce(p.proconfig::text, '')
                                         FROM pg_proc p WHERE p.oid = to_regprocedure(s.ident))
       ELSE (SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
               FROM pg_attribute a WHERE a.attrelid = to_regclass(s.ident) AND a.attnum > 0 AND NOT a.attisdropped) END);
  IF miss IS NOT NULL THEN RAISE EXCEPTION 'KAN-734 C13 FAIL: shape changed or object gone: %', miss; END IF;
  RAISE NOTICE 'KAN-734 C13 PASS: % pre-image shapes (result type, security, volatility, config; view columns) unchanged', (SELECT count(*) FROM kan734_fx.preshape);
END $c$;

-- ---------------------------------------------------------------------------------------------
-- Scenario S1-S5: seed one public game, one private game, one public meetup and one hidden meetup
-- through the ordinary legacy INSERT path, then look through the converted read surfaces as anon,
-- as a stranger, as a blocked user and as the owner. Everything rolls back.
-- ---------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.k734_as(p_uid uuid, p_sql text) RETURNS bigint LANGUAGE plpgsql AS $f$
DECLARE n bigint; BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', 'authenticated')::text END, true);
  EXECUTE 'SET LOCAL ROLE ' || CASE WHEN p_uid IS NULL THEN 'anon' ELSE 'authenticated' END;
  EXECUTE p_sql INTO n;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN n; END $f$;
CREATE TEMP TABLE k734_fp AS
SELECT (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t) g,
       (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t) m,
       (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) e;
GRANT SELECT ON k734_fp TO PUBLIC;

BEGIN;
DO $s$
DECLARE
  stranger uuid := '00000000-0000-0000-0000-00000000dead';
  blocked  uuid := '00000000-0000-0000-0000-0000000000a6';
  owner    uuid := '00000000-0000-0000-0000-0000000000a1';
  q_gc text := $q$SELECT count(*) FROM public.v_game_card$q$;
  q_ml text := $q$SELECT count(*) FROM public.v_meetup_list$q$;
  q_gn text := $q$SELECT count(*) FROM public.v_game_card WHERE id::text LIKE '73400000%'$q$;
  q_mn text := $q$SELECT count(*) FROM public.v_meetup_list WHERE id::text LIKE '73400000%'$q$;
  q_my text := $q$SELECT count(*) FROM public.v_my_games WHERE id::text LIKE '73400000%'$q$;
  q_dup text := $q$SELECT (SELECT count(*) - count(DISTINCT id) FROM public.v_game_card) + (SELECT count(*) - count(DISTINCT id) FROM public.v_meetup_list)$q$;
  b record; a record; x bigint;
BEGIN
  SELECT pg_temp.k734_as(stranger, q_gc) s_gc, pg_temp.k734_as(blocked, q_gc) b_gc, pg_temp.k734_as(NULL, q_gc) n_gc,
         pg_temp.k734_as(stranger, q_ml) s_ml, pg_temp.k734_as(blocked, q_ml) b_ml, pg_temp.k734_as(NULL, q_ml) n_ml INTO b;

  -- S1 seed through the legacy INSERT path (KAN-711 mirror creates the events parent)
  INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, sport_id, geo_location_id, area_id, price_aed, min_skill, max_skill)
  VALUES ('73400000-0000-0000-0000-000000000001', 'B15 public', '00000000-0000-0000-0000-0000000000b1', owner, '2031-01-01T10:00:00+04', '2031-01-01T11:30:00+04', 10, 'public', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 0, 1, 5),
         ('73400000-0000-0000-0000-000000000002', NULL, '00000000-0000-0000-0000-0000000000b1', owner, '2031-01-02T10:00:00+04', '2031-01-02T11:30:00+04', 8, 'private', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 0, 1, 5);
  INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(m) || jsonb_build_object('id', '73400000-0000-0000-0000-00000000f001', 'event_id', NULL, 'request_id', NULL, 'title', 'B15 meetup', 'start_at', '2031-01-03T10:00:00+04', 'end_at', NULL, 'listing_visibility', 'public'))).*
    FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';
  INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(m) || jsonb_build_object('id', '73400000-0000-0000-0000-00000000f002', 'event_id', NULL, 'request_id', NULL, 'title', 'B15 hidden', 'start_at', '2031-01-04T10:00:00+04', 'end_at', NULL, 'listing_visibility', 'hidden'))).*
    FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';
  SELECT count(*) INTO x FROM public.events e WHERE e.id::text LIKE '73400000%';
  IF x <> 4 OR EXISTS (SELECT 1 FROM public.games WHERE id::text LIKE '73400000%' AND event_id IS DISTINCT FROM id)
            OR EXISTS (SELECT 1 FROM public.meetups WHERE id::text LIKE '73400000%' AND event_id IS DISTINCT FROM id) THEN
    RAISE EXCEPTION 'KAN-734 S1 FAIL: expected 4 events parents with events.id = subtype id, got %', x;
  END IF;
  IF (SELECT title FROM public.events WHERE id = '73400000-0000-0000-0000-000000000002') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-734 S1 FAIL: NULL game title was not preserved on the events parent';
  END IF;
  RAISE NOTICE 'KAN-734 S1 PASS: 2 games + 2 meetups seeded; each has exactly one events parent, id kept, NULL title preserved';

  -- S2 rows not doubled
  IF pg_temp.k734_as(stranger, q_dup) <> 0 OR pg_temp.k734_as(owner, q_dup) <> 0 THEN
    RAISE EXCEPTION 'KAN-734 S2 FAIL: duplicate ids in v_game_card/v_meetup_list';
  END IF;
  IF pg_temp.k734_as(owner, q_my) <> 2 THEN RAISE EXCEPTION 'KAN-734 S2 FAIL: owner v_my_games new rows = % (expected 2)', pg_temp.k734_as(owner, q_my); END IF;
  RAISE NOTICE 'KAN-734 S2 PASS: no duplicate ids; owner sees each new game once in v_my_games';

  -- S3 counts equal legacy: per-type visibility kept, capacity math equals the legacy reference
  SELECT pg_temp.k734_as(stranger, q_gc) s_gc, pg_temp.k734_as(blocked, q_gc) b_gc, pg_temp.k734_as(NULL, q_gc) n_gc,
         pg_temp.k734_as(stranger, q_ml) s_ml, pg_temp.k734_as(blocked, q_ml) b_ml, pg_temp.k734_as(NULL, q_ml) n_ml INTO a;
  IF a.s_gc - b.s_gc <> 1 OR a.s_ml - b.s_ml <> 1 OR pg_temp.k734_as(stranger, q_gn) <> 1 OR pg_temp.k734_as(stranger, q_mn) <> 1 THEN
    RAISE EXCEPTION 'KAN-734 S3 FAIL: stranger delta game % meetup % (expected +1/+1: public only)', a.s_gc - b.s_gc, a.s_ml - b.s_ml;
  END IF;
  IF a.n_gc - b.n_gc <> pg_temp.k734_as(NULL, q_gn) OR a.n_ml - b.n_ml <> pg_temp.k734_as(NULL, q_mn) OR pg_temp.k734_as(NULL, q_gn) > 1 OR pg_temp.k734_as(NULL, q_mn) > 1 THEN
    RAISE EXCEPTION 'KAN-734 S3 FAIL: anon sees a non-public new row';
  END IF;
  IF pg_temp.k734_as(owner, q_gn) <> 2 OR pg_temp.k734_as(owner, q_mn) <> 2 THEN
    RAISE EXCEPTION 'KAN-734 S3 FAIL: owner sees % games / % meetups of own 2/2', pg_temp.k734_as(owner, q_gn), pg_temp.k734_as(owner, q_mn);
  END IF;
  IF public.game_slots_left('73400000-0000-0000-0000-000000000001') IS DISTINCT FROM public.k727_ref_game_slots_left('73400000-0000-0000-0000-000000000001')
     OR public.game_slots_left('73400000-0000-0000-0000-000000000002') IS DISTINCT FROM public.k727_ref_game_slots_left('73400000-0000-0000-0000-000000000002')
     OR public.meetup_slots_left('73400000-0000-0000-0000-00000000f001') IS DISTINCT FROM public.k727_ref_meetup_slots_left('73400000-0000-0000-0000-00000000f001') THEN
    RAISE EXCEPTION 'KAN-734 S3 FAIL: slots_left differs from the legacy reference';
  END IF;
  RAISE NOTICE 'KAN-734 S3 PASS: stranger +1 game +1 meetup (public only); anon public only; owner 2/2; slots_left = legacy reference (game %, meetup %)',
    public.game_slots_left('73400000-0000-0000-0000-000000000001'), public.meetup_slots_left('73400000-0000-0000-0000-00000000f001');

  -- S4 non-owner / blocked user sees nothing extra
  IF a.b_gc <> b.b_gc OR a.b_ml <> b.b_ml OR pg_temp.k734_as(blocked, q_gn) <> 0 OR pg_temp.k734_as(blocked, q_mn) <> 0
     OR pg_temp.k734_as(stranger, q_my) <> 0 OR pg_temp.k734_as(blocked, q_my) <> 0 THEN
    RAISE EXCEPTION 'KAN-734 S4 FAIL: blocked user sees new rows (games %->%, meetups %->%)', b.b_gc, a.b_gc, b.b_ml, a.b_ml;
  END IF;
  RAISE NOTICE 'KAN-734 S4 PASS: user blocked by the owner sees none of the 4 new rows; non-owners see none in v_my_games';
END $s$;
ROLLBACK;

-- S5 rollback leaves data intact
DO $r$
BEGIN
  IF (SELECT g FROM k734_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t)
     OR (SELECT m FROM k734_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t)
     OR (SELECT e FROM k734_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) THEN
    RAISE EXCEPTION 'KAN-734 S5 FAIL: games/meetups/events fingerprint changed after ROLLBACK';
  END IF;
  RAISE NOTICE 'KAN-734 S5 PASS: games/meetups/events md5 fingerprints identical after ROLLBACK';
  RAISE NOTICE 'KAN-734 ALL PASS';
END $r$;
