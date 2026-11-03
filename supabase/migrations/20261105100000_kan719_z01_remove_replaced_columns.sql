-- KAN-778 (KAN-719 Z01, Epic KAN-708): PHASE 4. Remove the subtype columns, indexes, constraints and temporary
-- sync logic that the KAN-718 D06 deletion manifest (KAN-774) lists as replaced by public.events.
--
-- AUTHORED FOR REVIEW. NEVER APPLIED BY THIS TICKET. DROP is Memphis's (operations workflow), and only after the
-- E9/E10 gates. Local proof only: supabase/tests/events_p4/kan719_z01_removal_test.sql (throwaway PG16).
--
-- SOURCE. Every statement below is the D06 manifest entry of the same seq, verbatim and in manifest order
-- (k774_manifest in supabase/tests/events_p4/kan718_d06_manifest_check.sql; KAN718_DELETION_MANIFEST.md s4).
-- 130 statements. md5 of the 130 statements joined by newline, manifest order = 614c1f8d29cd017126bca92588e96d9f
-- (the test recomputes it from k774_manifest). This file carries those 130 verbatim EXCEPT two named corrections,
-- plus one named addition:
--   seq 201/202 CORRECTED. The manifest text `ALTER PUBLICATION supabase_realtime SET TABLE ONLY public.games (id)`
--            REPLACES the publication's whole table list (PG16 ALTER PUBLICATION ... SET). 201 would drop every
--            other realtime table, and 202 would then drop games. Authored here in the KAN-716 form, one pair per
--            table: DROP TABLE ONLY public.<t>; ADD TABLE ONLY public.<t> (<retained cols>). The resulting column
--            lists are the ones the manifest intended. Evidence: the test's Z3 publication probe. Fix the
--            manifest text too (D06 follow-up; not edited here, it is another ticket's file).
--   seq 334  DROP TRIGGER trg_zz_kan712_events_compat_mirror ON public.events
--            the KAN-712 events -> games/meetups compatibility mirror. It is temporary sync logic and it writes
--            the slated columns, so once they are gone EVERY events UPDATE fails (42703). D06 only scanned
--            triggers on games/meetups, so it is missing there. Evidence: the test's Z4 events-UPDATE smoke.
--            The function kan712_events_compat_mirror() is left in place, like the other trigger functions
--            (dropping functions is a follow-up, KAN718_DELETION_MANIFEST.md s3).
--
-- KEPT (never touched): games/meetups ids, event_id, every retained subtype column (games 13, meetups 6, the
-- KAN-718 "Retained subtype data" list), every inbound FK (game_id / meetup_id references), every events object.
-- No CASCADE, no IF EXISTS, no wildcard. Column defaults go with their column.
--
-- FAIL-CLOSED GATE. The first block collects every unmet precondition and raises once, listing them all. Nothing
-- below it runs unless all of these hold:
--   G1 authorisation: the operator has run  SET LOCAL kan719.phase4_manifest_md5 = '614c1f8d29cd017126bca92588e96d9f';
--      in the same transaction. That is the explicit act operations does only after E9/E10 (D01/D02/D03
--      re-run with 0 consumers, the three D06 decisions taken). Without it the migration is a refusal.
--   G2 the caller bypasses RLS (otherwise G5 undercounts meetups, as in D09).
--   G3 every object the manifest names exists. 13 indexes are in the repo baseline but missing from the local
--      harness (KAN718_DELETION_MANIFEST.md, "baseline-only"); if production lacks one, the manifest is wrong
--      for production and must be regenerated rather than skipped.
--   G4 the named replacements exist on events: trg_events_search_tsv, trg_events_touch,
--      trg_kan713_events_location, and the D07 (KAN-775) trg_kan718_events_series_occurrence.
--   G5 the D09 (KAN-777) verdict holds: the same equalities as kan718_d09_parity_precheck.sql section 2. Every
--      subtype row has its events parent (id = event_id), events = games + meetups, and no field mismatch.
--   G6 no view or rule depends on a column being dropped. Today v_meetup_list reads meetups.description,
--      location_name and is_indoor. Those three have no events column (the D06 contract gap), so this gate
--      holds them until that decision is made.
-- The last block re-checks the result (no slated column left, every retained column present, counts kept).
--
-- RUN: Supabase CLI applies a migration file in one transaction. With psql use --single-transaction. Either way
-- a failure anywhere rolls back everything.
-- ROLLBACK: before COMMIT, any error rolls the whole file back (the test proves it). AFTER COMMIT, the dropped
-- columns and their data cannot be restored from SQL in this repo. Restore needs the pre-phase-4 backup of
-- public.games and public.meetups, which E10 must take and verify. That is why G1 exists.
-- IDEMPOTENT: no. A second run refuses at G3 (the objects are gone), and that is the intended answer.

DO $gate$
DECLARE
  fails text[] := '{}';
  x text;
  ok boolean;
BEGIN
  IF coalesce(current_setting('kan719.phase4_manifest_md5', true), '') <> '614c1f8d29cd017126bca92588e96d9f' THEN
    fails := fails || 'G1 not authorised: kan719.phase4_manifest_md5 is not set to the manifest md5 (E9/E10 gates, operations only)'::text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    fails := fails || format('G2 role %s does not bypass RLS', current_user);
  END IF;

  WITH m(seq, kind, tbl, obj) AS (VALUES
      (101, 'policy', 'meetups', 'meetups_select_visible'),
      (102, 'policy', 'meetups', 'meetup_attendees_select ON meetup_attendees'),
      (103, 'policy', 'meetups', 'meetup_attendees_select_visible ON meetup_attendees'),
      (104, 'policy', 'meetups', 'meetup_attendees_write ON meetup_attendees'),
      (201, 'publication', 'games', 'supabase_realtime'),
      (202, 'publication', 'meetups', 'supabase_realtime'),
      (301, 'trigger', 'games', 'trg_kan711_games_mirror'),
      (302, 'trigger', 'meetups', 'trg_kan711_meetups_mirror'),
      (303, 'trigger', 'games', 'trg_zz_kan712_games_guard'),
      (304, 'trigger', 'meetups', 'trg_zz_kan712_meetups_guard'),
      (305, 'trigger', 'games', 'trg_kan713_games_a_location'),
      (306, 'trigger', 'games', 'trg_kan713_games_b_joining'),
      (307, 'trigger', 'games', 'trg_kan713_games_c_venue_geo'),
      (308, 'trigger', 'meetups', 'trg_kan713_meetups_a_location'),
      (309, 'trigger', 'meetups', 'trg_kan713_meetups_b_joining'),
      (310, 'trigger', 'games', 'trg_kan718_games_series_occurrence'),
      (311, 'trigger', 'games', 'trg_games_search_tsv'),
      (312, 'trigger', 'meetups', 'trg_meetups_search_tsv'),
      (313, 'trigger', 'games', 'trg_games_touch'),
      (314, 'trigger', 'meetups', 'trg_meetups_touch'),
      (315, 'trigger', 'meetups', 'trg_meetups_updated'),
      (316, 'trigger', 'games', 'trg_games_inherit_geo'),
      (317, 'trigger', 'games', 'trg_games_inherit_venue_geo'),
      (318, 'trigger', 'meetups', 'trg_meetups_inherit_geo'),
      (319, 'trigger', 'games', 'tr_games_activity_sync'),
      (320, 'trigger', 'meetups', 'tr_meetups_activity_sync'),
      (321, 'trigger', 'games', 'trg_game_created'),
      (322, 'trigger', 'games', 'trg_game_updated_notify'),
      (323, 'trigger', 'games', 'msg_system_game_cancelled'),
      (324, 'trigger', 'meetups', 'trg_meetups_cancel_notify'),
      (325, 'trigger', 'meetups', 'trg_meetups_outbox'),
      (326, 'trigger', 'games', 'trg_games_set_host'),
      (327, 'trigger', 'games', 'trg_games_stamp_request_id'),
      (328, 'trigger', 'meetups', 'trg_meetups_stamp_request_id'),
      (329, 'trigger', 'games', 'trg_games_require_challenge_sport'),
      (330, 'trigger', 'games', 'trg_games_inherit_sport_from_space'),
      (331, 'trigger', 'meetups', 'trg_meetups_enforce_solo_sport'),
      (332, 'trigger', 'games', 'trg_games_sync_joining_rule'),
      (333, 'trigger', 'meetups', 'trg_meetups_sync_joining_rule'),
      (401, 'index', 'games', 'games_series_id_start_at_key'),
      (402, 'index', 'games', 'games_creator_user_request_id_key'),
      (403, 'index', 'meetups', 'meetups_creator_user_request_id_key'),
      (404, 'index', 'games', 'idx_games_area'),
      (405, 'index', 'games', 'idx_games_cancelled'),
      (406, 'index', 'games', 'idx_games_is_cancelled'),
      (407, 'index', 'games', 'idx_games_geo'),
      (408, 'index', 'games', 'idx_games_host'),
      (409, 'index', 'games', 'idx_games_search_tsv'),
      (410, 'index', 'games', 'idx_games_start_at'),
      (411, 'index', 'games', 'idx_games_time'),
      (412, 'index', 'games', 'idx_games_title_prefix'),
      (413, 'index', 'games', 'idx_games_visibility'),
      (414, 'index', 'meetups', 'idx_meetups_owner'),
      (415, 'index', 'meetups', 'idx_meetups_owner_time'),
      (416, 'index', 'meetups', 'idx_meetups_search_tsv'),
      (501, 'constraint', 'games', 'games_area_id_fkey'),
      (502, 'constraint', 'games', 'games_capacity_check'),
      (503, 'constraint', 'games', 'games_cost_cover_check'),
      (504, 'constraint', 'games', 'games_cost_cover_logic'),
      (505, 'constraint', 'games', 'games_creator_profile_id_fkey'),
      (506, 'constraint', 'games', 'games_geo_location_id_fkey'),
      (507, 'constraint', 'games', 'games_join_policy_check'),
      (508, 'constraint', 'games', 'games_join_policy_chk'),
      (509, 'constraint', 'games', 'games_joining_rule_check'),
      (510, 'constraint', 'games', 'games_listing_visibility_check'),
      (511, 'constraint', 'games', 'games_location_required'),
      (512, 'constraint', 'games', 'games_max_skill_check'),
      (513, 'constraint', 'games', 'games_min_skill_check'),
      (514, 'constraint', 'games', 'games_sport_id_fkey'),
      (515, 'constraint', 'games', 'games_venue_id_fkey'),
      (516, 'constraint', 'meetups', 'chk_meetups_title_len'),
      (517, 'constraint', 'meetups', 'meetups_area_id_fkey'),
      (518, 'constraint', 'meetups', 'meetups_capacity_check'),
      (519, 'constraint', 'meetups', 'meetups_cost_cover_check'),
      (520, 'constraint', 'meetups', 'meetups_cost_cover_logic'),
      (521, 'constraint', 'meetups', 'meetups_creator_profile_id_fkey'),
      (522, 'constraint', 'meetups', 'meetups_geo_location_id_fkey'),
      (523, 'constraint', 'meetups', 'meetups_joining_rule_check'),
      (524, 'constraint', 'meetups', 'meetups_listing_visibility_check'),
      (525, 'constraint', 'meetups', 'meetups_rsvp_policy_check'),
      (526, 'constraint', 'meetups', 'meetups_sport_id_fkey'),
      (527, 'constraint', 'meetups', 'meetups_title_check'),
      (528, 'constraint', 'meetups', 'meetups_venue_id_fkey'),
      (601, 'column', 'games', 'title'),
      (602, 'column', 'games', 'creator_profile_id'),
      (603, 'column', 'games', 'creator_user_id'),
      (604, 'column', 'games', 'start_at'),
      (605, 'column', 'games', 'end_at'),
      (606, 'column', 'games', 'capacity'),
      (607, 'column', 'games', 'listing_visibility'),
      (608, 'column', 'games', 'join_policy'),
      (609, 'column', 'games', 'min_skill'),
      (610, 'column', 'games', 'max_skill'),
      (611, 'column', 'games', 'is_cancelled'),
      (612, 'column', 'games', 'cancelled_at'),
      (613, 'column', 'games', 'cancelled_reason'),
      (614, 'column', 'games', 'created_at'),
      (615, 'column', 'games', 'updated_at'),
      (616, 'column', 'games', 'search_tsv'),
      (617, 'column', 'games', 'sport_id'),
      (618, 'column', 'games', 'geo_location_id'),
      (619, 'column', 'games', 'area_id'),
      (620, 'column', 'games', 'venue_id'),
      (621, 'column', 'games', 'joining_rule'),
      (622, 'column', 'games', 'cost_cover'),
      (623, 'column', 'games', 'request_id'),
      (701, 'column', 'meetups', 'creator_profile_id'),
      (702, 'column', 'meetups', 'creator_user_id'),
      (703, 'column', 'meetups', 'title'),
      (704, 'column', 'meetups', 'description'),
      (705, 'column', 'meetups', 'listing_visibility'),
      (706, 'column', 'meetups', 'rsvp_policy'),
      (707, 'column', 'meetups', 'capacity'),
      (708, 'column', 'meetups', 'start_at'),
      (709, 'column', 'meetups', 'end_at'),
      (710, 'column', 'meetups', 'is_cancelled'),
      (711, 'column', 'meetups', 'created_at'),
      (712, 'column', 'meetups', 'updated_at'),
      (713, 'column', 'meetups', 'search_tsv'),
      (714, 'column', 'meetups', 'geo_location_id'),
      (715, 'column', 'meetups', 'sport_id'),
      (716, 'column', 'meetups', 'area_id'),
      (717, 'column', 'meetups', 'venue_id'),
      (718, 'column', 'meetups', 'min_skill'),
      (719, 'column', 'meetups', 'max_skill'),
      (720, 'column', 'meetups', 'joining_rule'),
      (721, 'column', 'meetups', 'cost_cover'),
      (722, 'column', 'meetups', 'location_name'),
      (723, 'column', 'meetups', 'is_indoor'),
      (724, 'column', 'meetups', 'request_id')
  )
  SELECT string_agg(m.seq || ' ' || m.kind || ' ' || m.tbl || '.' || m.obj, ', ' ORDER BY m.seq) INTO x FROM m
   WHERE NOT CASE m.kind
     WHEN 'policy'      THEN EXISTS (SELECT 1 FROM pg_policy WHERE polname = split_part(m.obj, ' ', 1)
                           AND polrelid = ('public.' || coalesce(nullif(split_part(m.obj, ' ON ', 2), ''), m.tbl))::regclass)
     WHEN 'publication' THEN EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = m.obj AND schemaname = 'public' AND tablename = m.tbl)
     WHEN 'trigger'     THEN EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = ('public.' || m.tbl)::regclass AND tgname = m.obj AND NOT tgisinternal)
     WHEN 'index'       THEN to_regclass('public.' || m.obj) IS NOT NULL
     WHEN 'constraint'  THEN EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = ('public.' || m.tbl)::regclass AND conname = m.obj)
     WHEN 'column'      THEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = ('public.' || m.tbl)::regclass AND attname = m.obj AND NOT attisdropped)
   END;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND tgname = 'trg_zz_kan712_events_compat_mirror') THEN
    x := concat_ws(', ', x, '334 trigger events.trg_zz_kan712_events_compat_mirror');
  END IF;
  IF x IS NOT NULL THEN fails := fails || ('G3 manifest objects missing (regenerate the manifest for this database): ' || x); END IF;

  SELECT string_agg(t, ', ') INTO x FROM unnest(ARRAY['trg_events_search_tsv', 'trg_events_touch', 'trg_kan713_events_location',
                                                       'trg_kan718_events_series_occurrence']) t
   WHERE NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND tgname = t AND NOT tgisinternal);
  IF x IS NOT NULL THEN fails := fails || ('G4 events replacements missing: ' || x); END IF;

  SELECT NOT EXISTS (SELECT 1 FROM public.games g JOIN public.events e ON e.id = g.id
                      WHERE e.event_type IS DISTINCT FROM 'game' OR e.title IS DISTINCT FROM g.title
                         OR e.creator_profile_id IS DISTINCT FROM g.creator_profile_id OR e.creator_user_id IS DISTINCT FROM g.creator_user_id
                         OR e.sport_id IS DISTINCT FROM g.sport_id OR e.start_at IS DISTINCT FROM g.start_at OR e.end_at IS DISTINCT FROM g.end_at
                         OR e.capacity IS DISTINCT FROM g.capacity OR e.venue_id IS DISTINCT FROM g.venue_id
                         OR e.geo_location_id IS DISTINCT FROM g.geo_location_id OR e.area_id IS DISTINCT FROM g.area_id
                         OR e.listing_visibility IS DISTINCT FROM g.listing_visibility OR e.join_policy IS DISTINCT FROM g.join_policy
                         OR e.min_skill IS DISTINCT FROM g.min_skill::smallint OR e.max_skill IS DISTINCT FROM g.max_skill::smallint
                         OR e.joining_rule IS DISTINCT FROM g.joining_rule OR e.cost_cover IS DISTINCT FROM g.cost_cover
                         OR e.is_cancelled IS DISTINCT FROM g.is_cancelled OR e.cancelled_at IS DISTINCT FROM g.cancelled_at
                         OR e.cancelled_reason IS DISTINCT FROM g.cancelled_reason OR e.request_id IS DISTINCT FROM g.request_id
                         OR e.created_at IS DISTINCT FROM g.created_at OR e.updated_at IS DISTINCT FROM g.updated_at)
     AND NOT EXISTS (SELECT 1 FROM public.meetups m JOIN public.events e ON e.id = m.id
                      WHERE e.event_type IS DISTINCT FROM 'meetup' OR e.title IS DISTINCT FROM m.title
                         OR e.creator_profile_id IS DISTINCT FROM m.creator_profile_id OR e.creator_user_id IS DISTINCT FROM m.creator_user_id
                         OR e.sport_id IS DISTINCT FROM m.sport_id OR e.start_at IS DISTINCT FROM m.start_at OR e.end_at IS DISTINCT FROM m.end_at
                         OR e.capacity IS DISTINCT FROM m.capacity OR e.venue_id IS DISTINCT FROM m.venue_id
                         OR e.geo_location_id IS DISTINCT FROM m.geo_location_id OR e.area_id IS DISTINCT FROM m.area_id
                         OR e.listing_visibility IS DISTINCT FROM m.listing_visibility OR e.join_policy IS DISTINCT FROM m.rsvp_policy
                         OR e.min_skill IS DISTINCT FROM m.min_skill::smallint OR e.max_skill IS DISTINCT FROM m.max_skill::smallint
                         OR e.joining_rule IS DISTINCT FROM m.joining_rule OR e.cost_cover IS DISTINCT FROM m.cost_cover
                         OR e.is_cancelled IS DISTINCT FROM m.is_cancelled OR e.cancelled_at IS NOT NULL OR e.cancelled_reason IS NOT NULL
                         OR e.request_id IS DISTINCT FROM m.request_id OR e.created_at IS DISTINCT FROM m.created_at
                         OR e.updated_at IS DISTINCT FROM m.updated_at)
     AND (SELECT count(*) FROM public.games) = (SELECT count(*) FROM public.events WHERE event_type = 'game')
     AND (SELECT count(*) FROM public.meetups) = (SELECT count(*) FROM public.events WHERE event_type = 'meetup')
     AND (SELECT count(*) FROM public.events) = (SELECT count(*) FROM public.games) + (SELECT count(*) FROM public.meetups)
     AND NOT EXISTS (SELECT 1 FROM public.games g JOIN public.meetups m ON m.id = g.id)
     AND NOT EXISTS (SELECT 1 FROM public.games WHERE event_id IS DISTINCT FROM id)
     AND NOT EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS DISTINCT FROM id)
    INTO ok;
  IF NOT ok THEN fails := fails || 'G5 D09 verdict fails: a subtype row differs from, or lacks, its events parent'::text; END IF;

  SELECT string_agg(DISTINCT r.ev_class::regclass::text || ' -> ' || d.refobjid::regclass::text || '.' || a.attname, ', ') INTO x
    FROM pg_depend d
    JOIN pg_rewrite r ON d.classid = 'pg_rewrite'::regclass AND d.objid = r.oid
    JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
   WHERE d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass) AND d.refobjsubid > 0
     AND r.ev_class <> d.refobjid
     AND NOT (d.refobjid = 'public.games'::regclass AND a.attname = ANY ('{id,event_id,game_type,venue_space_id,sport_variant_id,allow_spectators,rules,squad_id,sport_specific_data,allows_waitlist,bench_slots,price_aed,series_id}'))
     AND NOT (d.refobjid = 'public.meetups'::regclass AND a.attname = ANY ('{id,event_id,vibe_key,meta,host_actor_id,members_only}'));
  IF x IS NOT NULL THEN fails := fails || ('G6 views still read columns being dropped: ' || x); END IF;

  IF cardinality(fails) > 0 THEN
    RAISE EXCEPTION 'KAN-778: phase-4 removal refused, % unmet precondition(s): %', cardinality(fails), array_to_string(fails, ' | ');
  END IF;
END $gate$;

-- ===== D06 manifest statements, verbatim, manifest order (seq in the trailing comment) =====

-- 100 policies: keep only the events half
ALTER POLICY meetups_select_visible ON public.meetups USING (public.kan713_meetup_visible(event_id));  -- 101
ALTER POLICY meetup_attendees_select ON public.meetup_attendees USING (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND public.kan713_meetup_can_read_row(m.event_id)));  -- 102
ALTER POLICY meetup_attendees_select_visible ON public.meetup_attendees USING ((auth.uid() = user_id) OR EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND public.kan713_meetup_attendee_visible(m.event_id)));  -- 103
ALTER POLICY meetup_attendees_write ON public.meetup_attendees USING (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND (public.kan713_meetup_can_write_row(m.event_id) OR auth.uid() = meetup_attendees.user_id))) WITH CHECK (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND (public.kan713_meetup_can_write_row(m.event_id) OR auth.uid() = meetup_attendees.user_id)));  -- 104

-- 200 realtime column lists: retained columns only
ALTER PUBLICATION supabase_realtime DROP TABLE ONLY public.games;  -- 201 (corrected, see header)
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.games (id);  -- 201
ALTER PUBLICATION supabase_realtime DROP TABLE ONLY public.meetups;  -- 202 (corrected, see header)
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.meetups (id, vibe_key);  -- 202

-- 300 triggers that read slated columns
DROP TRIGGER trg_kan711_games_mirror ON public.games;  -- 301
DROP TRIGGER trg_kan711_meetups_mirror ON public.meetups;  -- 302
DROP TRIGGER trg_zz_kan712_games_guard ON public.games;  -- 303
DROP TRIGGER trg_zz_kan712_meetups_guard ON public.meetups;  -- 304
DROP TRIGGER trg_kan713_games_a_location ON public.games;  -- 305
DROP TRIGGER trg_kan713_games_b_joining ON public.games;  -- 306
DROP TRIGGER trg_kan713_games_c_venue_geo ON public.games;  -- 307
DROP TRIGGER trg_kan713_meetups_a_location ON public.meetups;  -- 308
DROP TRIGGER trg_kan713_meetups_b_joining ON public.meetups;  -- 309
DROP TRIGGER trg_kan718_games_series_occurrence ON public.games;  -- 310
DROP TRIGGER trg_games_search_tsv ON public.games;  -- 311
DROP TRIGGER trg_meetups_search_tsv ON public.meetups;  -- 312
DROP TRIGGER trg_games_touch ON public.games;  -- 313
DROP TRIGGER trg_meetups_touch ON public.meetups;  -- 314
DROP TRIGGER trg_meetups_updated ON public.meetups;  -- 315
DROP TRIGGER trg_games_inherit_geo ON public.games;  -- 316
DROP TRIGGER trg_games_inherit_venue_geo ON public.games;  -- 317
DROP TRIGGER trg_meetups_inherit_geo ON public.meetups;  -- 318
DROP TRIGGER tr_games_activity_sync ON public.games;  -- 319
DROP TRIGGER tr_meetups_activity_sync ON public.meetups;  -- 320
DROP TRIGGER trg_game_created ON public.games;  -- 321
DROP TRIGGER trg_game_updated_notify ON public.games;  -- 322
DROP TRIGGER msg_system_game_cancelled ON public.games;  -- 323
DROP TRIGGER trg_meetups_cancel_notify ON public.meetups;  -- 324
DROP TRIGGER trg_meetups_outbox ON public.meetups;  -- 325
DROP TRIGGER trg_games_set_host ON public.games;  -- 326
DROP TRIGGER trg_games_stamp_request_id ON public.games;  -- 327
DROP TRIGGER trg_meetups_stamp_request_id ON public.meetups;  -- 328
DROP TRIGGER trg_games_require_challenge_sport ON public.games;  -- 329
DROP TRIGGER trg_games_inherit_sport_from_space ON public.games;  -- 330
DROP TRIGGER trg_meetups_enforce_solo_sport ON public.meetups;  -- 331
DROP TRIGGER trg_games_sync_joining_rule ON public.games;  -- 332
DROP TRIGGER trg_meetups_sync_joining_rule ON public.meetups;  -- 333

-- 400 indexes on slated columns
DROP INDEX public.games_series_id_start_at_key;  -- 401
DROP INDEX public.games_creator_user_request_id_key;  -- 402
DROP INDEX public.meetups_creator_user_request_id_key;  -- 403
DROP INDEX public.idx_games_area;  -- 404  baseline-only
DROP INDEX public.idx_games_cancelled;  -- 405  baseline-only
DROP INDEX public.idx_games_is_cancelled;  -- 406  baseline-only
DROP INDEX public.idx_games_geo;  -- 407  baseline-only
DROP INDEX public.idx_games_host;  -- 408  baseline-only
DROP INDEX public.idx_games_search_tsv;  -- 409  baseline-only
DROP INDEX public.idx_games_start_at;  -- 410  baseline-only
DROP INDEX public.idx_games_time;  -- 411  baseline-only
DROP INDEX public.idx_games_title_prefix;  -- 412  baseline-only
DROP INDEX public.idx_games_visibility;  -- 413  baseline-only
DROP INDEX public.idx_meetups_owner;  -- 414  baseline-only
DROP INDEX public.idx_meetups_owner_time;  -- 415  baseline-only
DROP INDEX public.idx_meetups_search_tsv;  -- 416  baseline-only

-- 500 constraints on slated columns
ALTER TABLE public.games DROP CONSTRAINT games_area_id_fkey;  -- 501
ALTER TABLE public.games DROP CONSTRAINT games_capacity_check;  -- 502
ALTER TABLE public.games DROP CONSTRAINT games_cost_cover_check;  -- 503
ALTER TABLE public.games DROP CONSTRAINT games_cost_cover_logic;  -- 504
ALTER TABLE public.games DROP CONSTRAINT games_creator_profile_id_fkey;  -- 505
ALTER TABLE public.games DROP CONSTRAINT games_geo_location_id_fkey;  -- 506
ALTER TABLE public.games DROP CONSTRAINT games_join_policy_check;  -- 507
ALTER TABLE public.games DROP CONSTRAINT games_join_policy_chk;  -- 508
ALTER TABLE public.games DROP CONSTRAINT games_joining_rule_check;  -- 509
ALTER TABLE public.games DROP CONSTRAINT games_listing_visibility_check;  -- 510
ALTER TABLE public.games DROP CONSTRAINT games_location_required;  -- 511
ALTER TABLE public.games DROP CONSTRAINT games_max_skill_check;  -- 512
ALTER TABLE public.games DROP CONSTRAINT games_min_skill_check;  -- 513
ALTER TABLE public.games DROP CONSTRAINT games_sport_id_fkey;  -- 514
ALTER TABLE public.games DROP CONSTRAINT games_venue_id_fkey;  -- 515
ALTER TABLE public.meetups DROP CONSTRAINT chk_meetups_title_len;  -- 516
ALTER TABLE public.meetups DROP CONSTRAINT meetups_area_id_fkey;  -- 517
ALTER TABLE public.meetups DROP CONSTRAINT meetups_capacity_check;  -- 518
ALTER TABLE public.meetups DROP CONSTRAINT meetups_cost_cover_check;  -- 519
ALTER TABLE public.meetups DROP CONSTRAINT meetups_cost_cover_logic;  -- 520
ALTER TABLE public.meetups DROP CONSTRAINT meetups_creator_profile_id_fkey;  -- 521
ALTER TABLE public.meetups DROP CONSTRAINT meetups_geo_location_id_fkey;  -- 522
ALTER TABLE public.meetups DROP CONSTRAINT meetups_joining_rule_check;  -- 523
ALTER TABLE public.meetups DROP CONSTRAINT meetups_listing_visibility_check;  -- 524
ALTER TABLE public.meetups DROP CONSTRAINT meetups_rsvp_policy_check;  -- 525
ALTER TABLE public.meetups DROP CONSTRAINT meetups_sport_id_fkey;  -- 526
ALTER TABLE public.meetups DROP CONSTRAINT meetups_title_check;  -- 527
ALTER TABLE public.meetups DROP CONSTRAINT meetups_venue_id_fkey;  -- 528

-- 600 games columns
ALTER TABLE public.games DROP COLUMN title;  -- 601
ALTER TABLE public.games DROP COLUMN creator_profile_id;  -- 602
ALTER TABLE public.games DROP COLUMN creator_user_id;  -- 603
ALTER TABLE public.games DROP COLUMN start_at;  -- 604
ALTER TABLE public.games DROP COLUMN end_at;  -- 605
ALTER TABLE public.games DROP COLUMN capacity;  -- 606
ALTER TABLE public.games DROP COLUMN listing_visibility;  -- 607
ALTER TABLE public.games DROP COLUMN join_policy;  -- 608
ALTER TABLE public.games DROP COLUMN min_skill;  -- 609
ALTER TABLE public.games DROP COLUMN max_skill;  -- 610
ALTER TABLE public.games DROP COLUMN is_cancelled;  -- 611
ALTER TABLE public.games DROP COLUMN cancelled_at;  -- 612
ALTER TABLE public.games DROP COLUMN cancelled_reason;  -- 613
ALTER TABLE public.games DROP COLUMN created_at;  -- 614
ALTER TABLE public.games DROP COLUMN updated_at;  -- 615
ALTER TABLE public.games DROP COLUMN search_tsv;  -- 616
ALTER TABLE public.games DROP COLUMN sport_id;  -- 617
ALTER TABLE public.games DROP COLUMN geo_location_id;  -- 618
ALTER TABLE public.games DROP COLUMN area_id;  -- 619
ALTER TABLE public.games DROP COLUMN venue_id;  -- 620
ALTER TABLE public.games DROP COLUMN joining_rule;  -- 621
ALTER TABLE public.games DROP COLUMN cost_cover;  -- 622
ALTER TABLE public.games DROP COLUMN request_id;  -- 623

-- 700 meetups columns
ALTER TABLE public.meetups DROP COLUMN creator_profile_id;  -- 701
ALTER TABLE public.meetups DROP COLUMN creator_user_id;  -- 702
ALTER TABLE public.meetups DROP COLUMN title;  -- 703
ALTER TABLE public.meetups DROP COLUMN description;  -- 704  HARD: homeless column (decision)
ALTER TABLE public.meetups DROP COLUMN listing_visibility;  -- 705
ALTER TABLE public.meetups DROP COLUMN rsvp_policy;  -- 706
ALTER TABLE public.meetups DROP COLUMN capacity;  -- 707
ALTER TABLE public.meetups DROP COLUMN start_at;  -- 708
ALTER TABLE public.meetups DROP COLUMN end_at;  -- 709
ALTER TABLE public.meetups DROP COLUMN is_cancelled;  -- 710
ALTER TABLE public.meetups DROP COLUMN created_at;  -- 711
ALTER TABLE public.meetups DROP COLUMN updated_at;  -- 712
ALTER TABLE public.meetups DROP COLUMN search_tsv;  -- 713
ALTER TABLE public.meetups DROP COLUMN geo_location_id;  -- 714
ALTER TABLE public.meetups DROP COLUMN sport_id;  -- 715
ALTER TABLE public.meetups DROP COLUMN area_id;  -- 716
ALTER TABLE public.meetups DROP COLUMN venue_id;  -- 717
ALTER TABLE public.meetups DROP COLUMN min_skill;  -- 718
ALTER TABLE public.meetups DROP COLUMN max_skill;  -- 719
ALTER TABLE public.meetups DROP COLUMN joining_rule;  -- 720
ALTER TABLE public.meetups DROP COLUMN cost_cover;  -- 721
ALTER TABLE public.meetups DROP COLUMN location_name;  -- 722  HARD: homeless column (decision)
ALTER TABLE public.meetups DROP COLUMN is_indoor;  -- 723  HARD: homeless column (decision)
ALTER TABLE public.meetups DROP COLUMN request_id;  -- 724

-- ===== named addition outside the manifest (see header) =====
DROP TRIGGER trg_zz_kan712_events_compat_mirror ON public.events;  -- 334

-- ===== post-condition =====
DO $post$
DECLARE x text;
BEGIN
  SELECT string_agg(c.relname || '.' || a.attname, ', ') INTO x
    FROM pg_class c JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
   WHERE c.oid IN ('public.games'::regclass, 'public.meetups'::regclass)
     AND NOT (c.relname = 'games' AND a.attname = ANY ('{id,event_id,game_type,venue_space_id,sport_variant_id,allow_spectators,rules,squad_id,sport_specific_data,allows_waitlist,bench_slots,price_aed,series_id}'))
     AND NOT (c.relname = 'meetups' AND a.attname = ANY ('{id,event_id,vibe_key,meta,host_actor_id,members_only}'));
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-778 post: columns outside the retained list survived: %', x; END IF;
  IF (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attnum > 0 AND NOT attisdropped) <> 13
     OR (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attnum > 0 AND NOT attisdropped) <> 6 THEN
    RAISE EXCEPTION 'KAN-778 post: a retained column is missing';
  END IF;
  IF (SELECT count(*) FROM public.events) <> (SELECT count(*) FROM public.games) + (SELECT count(*) FROM public.meetups)
     OR EXISTS (SELECT 1 FROM public.games WHERE event_id IS DISTINCT FROM id)
     OR EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS DISTINCT FROM id) THEN
    RAISE EXCEPTION 'KAN-778 post: subtype/events linkage changed';
  END IF;
END $post$;
