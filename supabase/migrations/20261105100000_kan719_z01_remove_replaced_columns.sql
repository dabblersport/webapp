-- KAN-778 (KAN-719 Z01, Epic KAN-708): PHASE 4. Remove the subtype columns, indexes, constraints and temporary
-- sync logic that the KAN-718 D06 deletion manifest (KAN-774) lists as replaced by public.events.
--
-- RE-SCOPED BY KAN-861 (F8) under CTO ruling dreq-0f6e9434, option (A). Measured on the local chain (KAN-718 D04
-- harness, PG16): games has 36 columns and meetups 30. SLATED 22: games 1 (search_tsv, seq 616), meetups 21.
-- RETAINED 44: games 35 (the 13 KAN-718 retained-subtype columns plus the 22 columns D03 lists as client-read),
-- meetups 9 (the 6 KAN-718 retained columns plus description, location_name, is_indoor under ruling 2). Before F8
-- this file slated 44 and retained 19. Every games trigger, index and constraint on a kept column stays (rule 3):
-- of the games objects only trg_games_search_tsv (311) and idx_games_search_tsv (409) go with search_tsv.
--
-- AUTHORED FOR REVIEW. NEVER APPLIED BY THIS TICKET. DROP is Memphis's (operations workflow), and only after the
-- E9/E10 gates. Local proof only: supabase/tests/events_p4/kan719_z01_removal_test.sql (throwaway PG16).
--
-- SOURCE. Every statement below is the D06 manifest entry of the same seq, verbatim and in manifest order
-- (k774_manifest in supabase/tests/events_p4/kan718_d06_manifest_check.sql; KAN718_DELETION_MANIFEST.md s4).
-- 63 statements. md5 of the 63 statements joined by newline, manifest order = ed136455ca8dfda23a8c83342a4a5110
-- (the test recomputes it from k774_manifest). This file carries those 63 verbatim EXCEPT one named correction,
-- plus one named addition:
--   seq 202  CORRECTED. The manifest text `ALTER PUBLICATION supabase_realtime SET TABLE ONLY public.meetups (...)`
--            REPLACES the publication's whole table list (PG16 ALTER PUBLICATION ... SET), dropping every other
--            realtime table. Authored here in the KAN-716 form: DROP TABLE ONLY public.meetups; ADD TABLE ONLY
--            public.meetups (id, vibe_key). Evidence: the test's Z3 publication probe. (The pre-F8 201 games pair
--            is gone: the games publication list holds no slated column, so games realtime is unchanged.)
--   seq 690/691  REPLACE public.kan712_events_compat_mirror() (CTO rule 2). Authored from pg_get_functiondef on the
--            local chain (T-058), NOT from a migration file; 20261103100000 is not edited. The games branch is
--            byte-for-byte the pre-image (same 22 columns, same IS DISTINCT FROM guard, same pg_trigger_depth() /
--            kan712.routing skip, same kan712.compat set_config); the meetups branch is removed, so an events row
--            whose event_type <> 'game' returns without touching meetups. SECURITY DEFINER and search_path = ''
--            unchanged; 691 re-asserts the revoke. It runs before the meetups column drops (7xx), in this same
--            transaction, so no events UPDATE can reach a dropped meetups column. The trigger
--            trg_zz_kan712_events_compat_mirror (pre-F8 seq 334) is KEPT: the games side-effect triggers still
--            fire from the mirrored games UPDATE. Evidence: the test's Z4 events-UPDATE and games-UPDATE smokes.
--   seq 801-803  DROP FUNCTION get_nearby_games x2 and getnearbygames (CTO rule 4), no CASCADE. pg_depend and
--            pg_proc body scans on the local chain show no dependants. getnearbymeetups was converted (F3) and stays.
--
-- KEPT (never touched): games/meetups ids, event_id, every retained subtype column (games 35, meetups 9), every
-- inbound FK (game_id / meetup_id references), every events object. No CASCADE, no IF EXISTS, no wildcard.
-- Column defaults go with their column.
--
-- FAIL-CLOSED GATE. The first block collects every unmet precondition and raises once, listing them all. Nothing
-- below it runs unless all of these hold:
--   G1 authorisation: the operator has run  SET LOCAL kan719.phase4_manifest_md5 = 'ed136455ca8dfda23a8c83342a4a5110';
--      in the same transaction. That is the explicit act operations does only after E9/E10 (D01/D02/D03
--      re-run with 0 consumers, the D06 decisions taken). Without it the migration is a refusal.
--   G2 the caller bypasses RLS (otherwise G5 undercounts meetups, as in D09).
--   G3 every object the manifest names exists, and kan712_events_compat_mirror() is still the pre-image 690
--      was authored from (md5(prosrc) = 965655a8ca3f6f1a9674e36a212b9b9b) with its events trigger attached.
--      4 indexes and the 3 functions are in the repo baseline but missing from the local harness
--      (KAN718_DELETION_MANIFEST.md, "baseline-only"); if production lacks one, the manifest is wrong for
--      production and must be regenerated rather than skipped.
--   G4 the named replacements exist on events: trg_events_search_tsv, trg_events_touch,
--      trg_kan713_events_location, and the D07 (KAN-775) trg_kan718_events_series_occurrence.
--   G5 the D09 (KAN-777) verdict holds: the same equalities as kan718_d09_parity_precheck.sql section 2. Every
--      subtype row has its events parent (id = event_id), events = games + meetups, and no field mismatch.
--   G6 no view or rule depends on a column being dropped (retained lists: games 35, meetups 9).
-- The last block re-checks the result (no slated column left, every retained column present, counts kept, the
-- mirror has no meetups branch, the three RPCs are gone).
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
  IF coalesce(current_setting('kan719.phase4_manifest_md5', true), '') <> 'ed136455ca8dfda23a8c83342a4a5110' THEN
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
      (202, 'publication', 'meetups', 'supabase_realtime'),
      (302, 'trigger', 'meetups', 'trg_kan711_meetups_mirror'),
      (304, 'trigger', 'meetups', 'trg_zz_kan712_meetups_guard'),
      (308, 'trigger', 'meetups', 'trg_kan713_meetups_a_location'),
      (309, 'trigger', 'meetups', 'trg_kan713_meetups_b_joining'),
      (311, 'trigger', 'games', 'trg_games_search_tsv'),
      (312, 'trigger', 'meetups', 'trg_meetups_search_tsv'),
      (314, 'trigger', 'meetups', 'trg_meetups_touch'),
      (315, 'trigger', 'meetups', 'trg_meetups_updated'),
      (318, 'trigger', 'meetups', 'trg_meetups_inherit_geo'),
      (320, 'trigger', 'meetups', 'tr_meetups_activity_sync'),
      (324, 'trigger', 'meetups', 'trg_meetups_cancel_notify'),
      (325, 'trigger', 'meetups', 'trg_meetups_outbox'),
      (328, 'trigger', 'meetups', 'trg_meetups_stamp_request_id'),
      (331, 'trigger', 'meetups', 'trg_meetups_enforce_solo_sport'),
      (333, 'trigger', 'meetups', 'trg_meetups_sync_joining_rule'),
      (403, 'index', 'meetups', 'meetups_creator_user_request_id_key'),
      (409, 'index', 'games', 'idx_games_search_tsv'),
      (414, 'index', 'meetups', 'idx_meetups_owner'),
      (415, 'index', 'meetups', 'idx_meetups_owner_time'),
      (416, 'index', 'meetups', 'idx_meetups_search_tsv'),
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
      (616, 'column', 'games', 'search_tsv'),
      (701, 'column', 'meetups', 'creator_profile_id'),
      (702, 'column', 'meetups', 'creator_user_id'),
      (703, 'column', 'meetups', 'title'),
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
      (724, 'column', 'meetups', 'request_id'),
      (801, 'function', 'games', 'get_nearby_games(double precision,double precision,double precision)'),
      (802, 'function', 'games', 'get_nearby_games(double precision,double precision,integer)'),
      (803, 'function', 'games', 'getnearbygames(double precision,double precision,double precision)')
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
     WHEN 'function'    THEN to_regprocedure('public.' || m.obj) IS NOT NULL
   END;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND tgname = 'trg_zz_kan712_events_compat_mirror')
     OR (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure('public.kan712_events_compat_mirror()')) IS DISTINCT FROM '965655a8ca3f6f1a9674e36a212b9b9b' THEN
    x := concat_ws(', ', x, '690 function kan712_events_compat_mirror() is not the authored pre-image, or its events trigger is gone');
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
     AND NOT (d.refobjid = 'public.games'::regclass AND a.attname = ANY ('{id,event_id,game_type,venue_space_id,sport_variant_id,allow_spectators,rules,squad_id,sport_specific_data,allows_waitlist,bench_slots,price_aed,series_id,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'))
     AND NOT (d.refobjid = 'public.meetups'::regclass AND a.attname = ANY ('{id,event_id,vibe_key,meta,host_actor_id,members_only,description,location_name,is_indoor}'));
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

-- 200 realtime column lists (202 corrected, see header; the pre-F8 games entry 201 is gone)
ALTER PUBLICATION supabase_realtime DROP TABLE ONLY public.meetups;  -- 202 (corrected, see header)
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.meetups (id, vibe_key);  -- 202

-- 300 triggers that read slated columns (games: 311 only; the other games triggers are on kept columns and stay)
DROP TRIGGER trg_kan711_meetups_mirror ON public.meetups;  -- 302
DROP TRIGGER trg_zz_kan712_meetups_guard ON public.meetups;  -- 304
DROP TRIGGER trg_kan713_meetups_a_location ON public.meetups;  -- 308
DROP TRIGGER trg_kan713_meetups_b_joining ON public.meetups;  -- 309
DROP TRIGGER trg_games_search_tsv ON public.games;  -- 311
DROP TRIGGER trg_meetups_search_tsv ON public.meetups;  -- 312
DROP TRIGGER trg_meetups_touch ON public.meetups;  -- 314
DROP TRIGGER trg_meetups_updated ON public.meetups;  -- 315
DROP TRIGGER trg_meetups_inherit_geo ON public.meetups;  -- 318
DROP TRIGGER tr_meetups_activity_sync ON public.meetups;  -- 320
DROP TRIGGER trg_meetups_cancel_notify ON public.meetups;  -- 324
DROP TRIGGER trg_meetups_outbox ON public.meetups;  -- 325
DROP TRIGGER trg_meetups_stamp_request_id ON public.meetups;  -- 328
DROP TRIGGER trg_meetups_enforce_solo_sport ON public.meetups;  -- 331
DROP TRIGGER trg_meetups_sync_joining_rule ON public.meetups;  -- 333

-- 400 indexes (409, 414-416 are in the repo baseline, absent from the local harness)
DROP INDEX public.meetups_creator_user_request_id_key;  -- 403
DROP INDEX public.idx_games_search_tsv;  -- 409  baseline-only
DROP INDEX public.idx_meetups_owner;  -- 414  baseline-only
DROP INDEX public.idx_meetups_owner_time;  -- 415  baseline-only
DROP INDEX public.idx_meetups_search_tsv;  -- 416  baseline-only

-- 500 constraints (meetups only; the games constraints are on kept columns and stay)
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

-- 600 games columns: search_tsv only
ALTER TABLE public.games DROP COLUMN search_tsv;  -- 616

-- ===== named addition 690/691 (see header): the compat mirror loses its meetups branch, before any meetups column drops =====
CREATE OR REPLACE FUNCTION public.kan712_events_compat_mirror()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  -- Skip only the row the guard is routing right now. The guard is a trigger, so its events UPDATE fires
  -- this one at depth > 1; a session-level SET kan712.routing followed by a direct events write runs
  -- at depth 1 and is mirrored normally (no spoofed divergence).
  IF pg_trigger_depth() > 1 AND coalesce(current_setting('kan712.routing', true), '') = NEW.id::text THEN
    RETURN NULL;
  END IF;
  PERFORM set_config('kan712.compat', NEW.id::text, true);
  IF NEW.event_type = 'game' THEN
    UPDATE public.games g SET
      creator_profile_id = NEW.creator_profile_id, creator_user_id = NEW.creator_user_id, title = NEW.title,
      start_at = NEW.start_at, end_at = NEW.end_at, capacity = NEW.capacity,
      listing_visibility = NEW.listing_visibility, join_policy = NEW.join_policy,
      is_cancelled = NEW.is_cancelled, cancelled_at = NEW.cancelled_at, cancelled_reason = NEW.cancelled_reason,
      sport_id = NEW.sport_id, area_id = NEW.area_id, geo_location_id = NEW.geo_location_id,
      venue_id = NEW.venue_id, min_skill = NEW.min_skill, max_skill = NEW.max_skill,
      joining_rule = NEW.joining_rule, cost_cover = NEW.cost_cover, request_id = NEW.request_id,
      created_at = NEW.created_at, updated_at = NEW.updated_at
    WHERE g.id = NEW.id
      AND ROW(g.creator_profile_id, g.creator_user_id, g.title, g.start_at, g.end_at, g.capacity,
              g.listing_visibility, g.join_policy, g.is_cancelled, g.cancelled_at, g.cancelled_reason,
              g.sport_id, g.area_id, g.geo_location_id, g.venue_id, g.min_skill, g.max_skill,
              g.joining_rule, g.cost_cover, g.request_id, g.created_at, g.updated_at)
          IS DISTINCT FROM
          ROW(NEW.creator_profile_id, NEW.creator_user_id, NEW.title, NEW.start_at, NEW.end_at, NEW.capacity,
              NEW.listing_visibility, NEW.join_policy, NEW.is_cancelled, NEW.cancelled_at, NEW.cancelled_reason,
              NEW.sport_id, NEW.area_id, NEW.geo_location_id, NEW.venue_id, NEW.min_skill::integer,
              NEW.max_skill::integer, NEW.joining_rule, NEW.cost_cover, NEW.request_id, NEW.created_at,
              NEW.updated_at);
  END IF;
  PERFORM set_config('kan712.compat', '', true);
  RETURN NULL;
END $function$;  -- 690
REVOKE ALL ON FUNCTION public.kan712_events_compat_mirror() FROM PUBLIC, anon, authenticated, service_role;  -- 691

-- 700 meetups columns (description, location_name, is_indoor are retained: ruling 2)
ALTER TABLE public.meetups DROP COLUMN creator_profile_id;  -- 701
ALTER TABLE public.meetups DROP COLUMN creator_user_id;  -- 702
ALTER TABLE public.meetups DROP COLUMN title;  -- 703
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
ALTER TABLE public.meetups DROP COLUMN request_id;  -- 724

-- 800 retired RPCs (no dependants; no CASCADE)
DROP FUNCTION public.get_nearby_games(double precision, double precision, double precision);  -- 801  baseline-only
DROP FUNCTION public.get_nearby_games(double precision, double precision, integer);  -- 802  baseline-only
DROP FUNCTION public.getnearbygames(double precision, double precision, double precision);  -- 803  baseline-only

-- ===== post-condition =====
DO $post$
DECLARE x text;
BEGIN
  SELECT string_agg(c.relname || '.' || a.attname, ', ') INTO x
    FROM pg_class c JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
   WHERE c.oid IN ('public.games'::regclass, 'public.meetups'::regclass)
     AND NOT (c.relname = 'games' AND a.attname = ANY ('{id,event_id,game_type,venue_space_id,sport_variant_id,allow_spectators,rules,squad_id,sport_specific_data,allows_waitlist,bench_slots,price_aed,series_id,creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'))
     AND NOT (c.relname = 'meetups' AND a.attname = ANY ('{id,event_id,vibe_key,meta,host_actor_id,members_only,description,location_name,is_indoor}'));
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-778 post: columns outside the retained list survived: %', x; END IF;
  IF (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attnum > 0 AND NOT attisdropped) <> 35
     OR (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attnum > 0 AND NOT attisdropped) <> 9 THEN
    RAISE EXCEPTION 'KAN-778 post: a retained column is missing';
  END IF;
  IF (SELECT count(*) FROM public.events) <> (SELECT count(*) FROM public.games) + (SELECT count(*) FROM public.meetups)
     OR EXISTS (SELECT 1 FROM public.games WHERE event_id IS DISTINCT FROM id)
     OR EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS DISTINCT FROM id) THEN
    RAISE EXCEPTION 'KAN-778 post: subtype/events linkage changed';
  END IF;
  IF (SELECT prosrc ~* 'public\.meetups' OR NOT prosecdef OR proconfig IS DISTINCT FROM ARRAY['search_path=""']
             OR has_function_privilege('anon', oid, 'EXECUTE') OR has_function_privilege('authenticated', oid, 'EXECUTE')
        FROM pg_proc WHERE oid = 'public.kan712_events_compat_mirror()'::regprocedure)
     OR to_regprocedure('public.get_nearby_games(double precision,double precision,double precision)') IS NOT NULL
     OR to_regprocedure('public.get_nearby_games(double precision,double precision,integer)') IS NOT NULL
     OR to_regprocedure('public.getnearbygames(double precision,double precision,double precision)') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-778 post: the compat mirror still writes meetups, lost SECURITY DEFINER / search_path / its revoke, or a retired RPC survived';
  END IF;
END $post$;
