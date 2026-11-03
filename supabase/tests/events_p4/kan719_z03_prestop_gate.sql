-- KAN-780 (KAN-719 Z03, Epic KAN-708): immediate pre-application dependency re-scan gate for the phase-4 removal.
--
-- READ-ONLY. It writes nothing (it runs inside BEGIN READ ONLY; the test proves it) and it is safe on production.
-- It is NOT a migration and applies nothing. Operations runs it IMMEDIATELY before the destructive step, in the SAME
-- transaction, so a refusal aborts that transaction before any DROP runs:
--
--   psql --single-transaction -v ON_ERROR_STOP=1 \
--        -f supabase/tests/events_p4/kan719_z03_prestop_gate.sql \
--        -c "SET LOCAL kan719.phase4_manifest_md5 = '614c1f8d29cd017126bca92588e96d9f'" \
--        -f supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql
--
-- What it re-scans, against the catalogue as it is at that moment, for the 47 slated games/meetups columns of the
-- D06 manifest (KAN-774, md5 614c1f8d29cd017126bca92588e96d9f):
--   S1  every object with a column-level pg_depend on a slated column (view, policy on any table, index, constraint,
--       trigger, publication, extended statistics, a retained column's generation expression, anything else)
--   S2  every non-internal trigger on games/meetups whose function reads a slated NEW./OLD. column or the whole row
--   S3  every SQL / plpgsql function in public whose body names games/meetups and a slated column token (the D02 A2
--       rule: comments stripped, extension members and test-harness reference functions excluded). Function bodies
--       carry no pg_depend, so this is the only way they are seen
--   S4  pg_cron jobs whose command names games/meetups and a slated column (when cron.job exists)
-- Each dependency found is one of:
--   REMOVED   the D06 manifest / Z01 migration drops or rewrites it (83 objects, embedded below)
--   KNOWN     reviewed and still open; it is not new, and it stops the removal elsewhere (Z01 gate G6 for the views,
--             the D01/D02 consumer rewrite, E9, for the functions): 61 entries, embedded below
--   NEW       anything else. One NEW dependency = STOP: the gate raises, the transaction aborts, the destructive step
--             does not run. Clearing it needs a review and a new manifest/Z01 revision, never an edit of this list in
--             the apply session.
--
-- Residual window, by construction: a function created by another session AFTER this scan and before the DROP commits
-- is not seen (function bodies take no lock and record no dependency). Views/policies/indexes/constraints created in
-- that window are still refused by the DROP itself, which uses no CASCADE.
DO $z03$
DECLARE
  sl_t text[]; sl_c text[];
  removed text[] := ARRAY[
    'constraint:chk_meetups_title_len', 'constraint:games_area_id_fkey', 'constraint:games_capacity_check', 'constraint:games_cost_cover_check',
    'constraint:games_cost_cover_logic', 'constraint:games_creator_profile_id_fkey', 'constraint:games_geo_location_id_fkey', 'constraint:games_join_policy_check',
    'constraint:games_join_policy_chk', 'constraint:games_joining_rule_check', 'constraint:games_listing_visibility_check', 'constraint:games_location_required',
    'constraint:games_max_skill_check', 'constraint:games_min_skill_check', 'constraint:games_sport_id_fkey', 'constraint:games_venue_id_fkey',
    'constraint:meetups_area_id_fkey', 'constraint:meetups_capacity_check', 'constraint:meetups_cost_cover_check', 'constraint:meetups_cost_cover_logic',
    'constraint:meetups_creator_profile_id_fkey', 'constraint:meetups_geo_location_id_fkey', 'constraint:meetups_joining_rule_check', 'constraint:meetups_listing_visibility_check',
    'constraint:meetups_rsvp_policy_check', 'constraint:meetups_sport_id_fkey', 'constraint:meetups_title_check', 'constraint:meetups_venue_id_fkey',
    'index:games_creator_user_request_id_key', 'index:games_series_id_start_at_key', 'index:idx_games_area', 'index:idx_games_cancelled',
    'index:idx_games_geo', 'index:idx_games_host', 'index:idx_games_is_cancelled', 'index:idx_games_search_tsv',
    'index:idx_games_start_at', 'index:idx_games_time', 'index:idx_games_title_prefix', 'index:idx_games_visibility',
    'index:idx_meetups_owner', 'index:idx_meetups_owner_time', 'index:idx_meetups_search_tsv', 'index:meetups_creator_user_request_id_key',
    'policy:meetup_attendees_select', 'policy:meetup_attendees_select_visible', 'policy:meetup_attendees_write', 'policy:meetups_select_visible',
    'publication:games', 'publication:meetups', 'trigger:msg_system_game_cancelled', 'trigger:tr_games_activity_sync',
    'trigger:tr_meetups_activity_sync', 'trigger:trg_game_created', 'trigger:trg_game_updated_notify', 'trigger:trg_games_inherit_geo',
    'trigger:trg_games_inherit_sport_from_space', 'trigger:trg_games_inherit_venue_geo', 'trigger:trg_games_require_challenge_sport', 'trigger:trg_games_search_tsv',
    'trigger:trg_games_set_host', 'trigger:trg_games_stamp_request_id', 'trigger:trg_games_sync_joining_rule', 'trigger:trg_games_touch',
    'trigger:trg_kan711_games_mirror', 'trigger:trg_kan711_meetups_mirror', 'trigger:trg_kan713_games_a_location', 'trigger:trg_kan713_games_b_joining',
    'trigger:trg_kan713_games_c_venue_geo', 'trigger:trg_kan713_meetups_a_location', 'trigger:trg_kan713_meetups_b_joining', 'trigger:trg_kan718_games_series_occurrence',
    'trigger:trg_meetups_cancel_notify', 'trigger:trg_meetups_enforce_solo_sport', 'trigger:trg_meetups_inherit_geo', 'trigger:trg_meetups_outbox',
    'trigger:trg_meetups_search_tsv', 'trigger:trg_meetups_stamp_request_id', 'trigger:trg_meetups_sync_joining_rule', 'trigger:trg_meetups_touch',
    'trigger:trg_meetups_updated', 'trigger:trg_zz_kan712_games_guard', 'trigger:trg_zz_kan712_meetups_guard'
  ];
  known text[] := ARRAY[
    -- views reading the 3 homeless meetups columns (D06 704/722/723 hard block; Z01 G6 refuses on them)
    'view:v_meetup_list', 'view:kan718_meetups_compat',
    -- column defaults / own generated columns go with their column
    'default',
    -- function consumers reviewed by D01/D02 (KAN-769/770), re-derived with the D02 A2 rule on the KAN-788 harness
    'function:_can_view_game', 'function:_can_view_game_for_join', 'function:_game_belongs_to_venue', 'function:_is_game_host',
    'function:_slot_conflicts_game', 'function:_user_hosted_game', 'function:active_stream', 'function:admin_cleanup_user_data',
    'function:admin_overview_row', 'function:can_current_user_join_game', 'function:can_current_user_rsvp_meetup', 'function:events_check_series_occurrence',
    'function:fn_games_activity_sync', 'function:fn_generate_game_series_occurrences_kan712_inner', 'function:fn_meetups_activity_sync', 'function:fn_meetups_enforce_solo_sport',
    'function:game_slots_left', 'function:kan711_events_backfill_batch', 'function:kan712_events_compat_mirror', 'function:kan712_legacy_guard',
    'function:kan713_events_location', 'function:kan713_games_location', 'function:kan713_meetups_joining', 'function:kan718_series_occurrence_guard',
    'function:meetup_counts', 'function:meetup_slots_left', 'function:msg_authorize', 'function:msg_evaluate',
    'function:msg_my_conversations', 'function:rpc_booking_cancel', 'function:rpc_booking_hold_for_game_kan712_inner', 'function:rpc_booking_hold_for_meetup',
    'function:rpc_cancel_game_kan712_inner', 'function:rpc_cancel_game_series_kan712_inner', 'function:rpc_challenge_spawn_game', 'function:rpc_create_game',
    'function:rpc_create_game_legacy_v1', 'function:rpc_create_game_legacy_v2', 'function:rpc_create_meetup', 'function:rpc_create_meetup_legacy_v1',
    'function:rpc_create_meetup_legacy_v2', 'function:rpc_edit_game_series_future_kan712_inner', 'function:rpc_edit_game_series_occurrence_kan712_inner', 'function:rpc_games_following_joined',
    'function:rpc_get_activity_feed', 'function:rpc_meetup_attendees', 'function:rpc_meetup_cancel_kan712_inner', 'function:rpc_meetup_card',
    'function:rpc_meetup_update_kan712_inner', 'function:rpc_rate_game', 'function:rpc_rate_user', 'function:rpc_rate_venue',
    'function:rpc_reschedule_game_kan712_inner', 'function:rpc_sport_overview', 'function:rpc_unified_search_sectioned', 'function:rpc_update_game_kan712_inner',
    'function:rpc_update_game_legacy_v1_kan712_inner', 'function:settle_game', 'function:trg_meetup_rsvps_notify'
  ];
  found text[] := '{}';
  x text[];
  nnew text[];
BEGIN
  SELECT array_agg(t ORDER BY t, c), array_agg(c ORDER BY t, c) INTO sl_t, sl_c FROM (VALUES
    ('games', 'title'), ('games', 'creator_profile_id'), ('games', 'creator_user_id'), ('games', 'start_at'), ('games', 'end_at'), ('games', 'capacity'),
    ('games', 'listing_visibility'), ('games', 'join_policy'), ('games', 'min_skill'), ('games', 'max_skill'), ('games', 'is_cancelled'), ('games', 'cancelled_at'),
    ('games', 'cancelled_reason'), ('games', 'created_at'), ('games', 'updated_at'), ('games', 'search_tsv'), ('games', 'sport_id'), ('games', 'geo_location_id'),
    ('games', 'area_id'), ('games', 'venue_id'), ('games', 'joining_rule'), ('games', 'cost_cover'), ('games', 'request_id'), ('meetups', 'creator_profile_id'),
    ('meetups', 'creator_user_id'), ('meetups', 'title'), ('meetups', 'description'), ('meetups', 'listing_visibility'), ('meetups', 'rsvp_policy'), ('meetups', 'capacity'),
    ('meetups', 'start_at'), ('meetups', 'end_at'), ('meetups', 'is_cancelled'), ('meetups', 'created_at'), ('meetups', 'updated_at'), ('meetups', 'search_tsv'),
    ('meetups', 'geo_location_id'), ('meetups', 'sport_id'), ('meetups', 'area_id'), ('meetups', 'venue_id'), ('meetups', 'min_skill'), ('meetups', 'max_skill'),
    ('meetups', 'joining_rule'), ('meetups', 'cost_cover'), ('meetups', 'location_name'), ('meetups', 'is_indoor'), ('meetups', 'request_id')
  ) v(t, c);

  -- S1 column-level pg_depend
  SELECT array_agg(DISTINCT k) INTO x FROM (
    SELECT CASE
             WHEN d.classid = 'pg_class'::regclass AND d.objid = d.refobjid THEN
               CASE WHEN (s.tbl, (SELECT attname FROM pg_attribute WHERE attrelid = d.objid AND attnum = d.objsubid)) IN
                         (SELECT * FROM unnest(sl_t, sl_c)) THEN 'default'
                    ELSE 'column:' || s.tbl || '.' || (SELECT attname FROM pg_attribute WHERE attrelid = d.objid AND attnum = d.objsubid) END
             WHEN d.classid = 'pg_constraint'::regclass THEN 'constraint:' || (SELECT conname FROM pg_constraint WHERE oid = d.objid)
             WHEN d.classid = 'pg_class'::regclass THEN
               CASE (SELECT relkind FROM pg_class WHERE oid = d.objid) WHEN 'i' THEN 'index:' ELSE 'relation:' END
               || (SELECT relname FROM pg_class WHERE oid = d.objid)
             WHEN d.classid = 'pg_trigger'::regclass THEN 'trigger:' || (SELECT tgname FROM pg_trigger WHERE oid = d.objid)
             WHEN d.classid = 'pg_policy'::regclass THEN 'policy:' || (SELECT polname FROM pg_policy WHERE oid = d.objid)
             WHEN d.classid = 'pg_rewrite'::regclass THEN 'view:' || (SELECT ev_class::regclass::text FROM pg_rewrite WHERE oid = d.objid)
             WHEN d.classid = 'pg_publication_rel'::regclass THEN 'publication:' || s.tbl
             WHEN d.classid = 'pg_attrdef'::regclass THEN 'default'
             WHEN d.classid = 'pg_statistic_ext'::regclass THEN 'statistics:' || (SELECT stxname FROM pg_statistic_ext WHERE oid = d.objid)
             ELSE 'other:' || pg_describe_object(d.classid, d.objid, d.objsubid) END AS k
      FROM pg_depend d
      JOIN unnest(sl_t, sl_c) s(tbl, col) ON d.refclassid = 'pg_class'::regclass AND d.refobjid = ('public.' || s.tbl)::regclass
      JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid AND a.attname = s.col
     WHERE NOT (d.classid = 'pg_class'::regclass AND d.objid <> d.refobjid
                AND EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conindid = d.objid))) q;
  found := found || coalesce(x, '{}');

  -- S2 triggers on games/meetups reading slated NEW./OLD. columns or the whole row
  SELECT array_agg(DISTINCT 'trigger:' || t.tgname) INTO x
    FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
   WHERE t.tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass) AND NOT t.tgisinternal
     AND p.proname !~ '^harness_'
     AND (p.prosrc ~* 'kan711_events_map_'
          OR EXISTS (SELECT 1 FROM unnest(sl_t, sl_c) s(tbl, col)
                      WHERE ('public.' || s.tbl)::regclass = t.tgrelid AND p.prosrc ~* ('\m(new|old)\.' || s.col || '\M')));
  found := found || coalesce(x, '{}');

  -- S3 function bodies (D02 A2 rule)
  SELECT array_agg(DISTINCT 'function:' || f.proname) INTO x FROM (
    SELECT p.proname, regexp_replace(regexp_replace(coalesce(p.prosrc, ''), '/\*([^*]|\*+[^*/])*\*+/', '', 'g'), '--[^\n]*', '', 'g') AS src
      FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace AND p.prokind IN ('f', 'p')
       AND p.prolang IN (SELECT oid FROM pg_language WHERE lanname IN ('sql', 'plpgsql'))
       AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e')
       AND p.proname !~ '^(k7\d\d_ref_|b\d\d_ref_|harness_)') f
   WHERE f.src ~* '\m(public\.)?(games|meetups)\M'
     AND EXISTS (SELECT 1 FROM unnest(sl_c) c WHERE f.src ~* ('\m' || c || '\M'));
  found := found || coalesce(x, '{}');

  -- S4 pg_cron
  IF to_regclass('cron.job') IS NOT NULL THEN
    EXECUTE $q$SELECT array_agg(DISTINCT 'cron:' || coalesce(jobname, jobid::text)) FROM cron.job
                WHERE command ~* '\m(public\.)?(games|meetups)\M' AND EXISTS (SELECT 1 FROM unnest($1) c WHERE command ~* ('\m' || c || '\M'))$q$
      INTO x USING sl_c;
    found := found || coalesce(x, '{}');
  END IF;

  SELECT array_agg(k ORDER BY k) INTO nnew FROM (SELECT DISTINCT unnest(found) k) u WHERE k <> ALL (removed) AND k <> ALL (known);
  IF cardinality(nnew) > 0 THEN
    RAISE EXCEPTION 'KAN-780 STOP: % NEW dependenc(ies) on slated games/meetups columns since the D06/Z01 review; the destructive step must not run: %',
      cardinality(nnew), array_to_string(nnew, ', ')
      USING HINT = 'Review each one; a new manifest/Z01 revision is needed before phase 4. Do not edit the gate lists in the apply session.';
  END IF;
  RAISE NOTICE 'KAN-780 GATE PASS at % (txid %): % dependencies on % slated columns, 0 NEW; % removed by Z01, % KNOWN still open (stop elsewhere: %)',
    clock_timestamp(), txid_current_if_assigned(), (SELECT count(DISTINCT k) FROM unnest(found) k), cardinality(sl_c),
    (SELECT count(DISTINCT k) FROM unnest(found) k WHERE k = ANY (removed)),
    (SELECT count(DISTINCT k) FROM unnest(found) k WHERE k = ANY (known) AND k <> 'default'),
    (SELECT string_agg(DISTINCT k, ', ') FROM unnest(found) k WHERE k = ANY (known) AND k LIKE 'view:%');
END $z03$;
