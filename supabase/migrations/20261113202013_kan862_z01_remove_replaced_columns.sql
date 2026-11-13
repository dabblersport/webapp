-- KAN-862 (Epic KAN-708) serial finish: Z01 regenerated from the LIVE catalogue of wtncuzcskpigqpmnxwws on 2026-11-13.
-- Supersedes 20261105100000_kan719_z01_remove_replaced_columns.sql (moved unedited to _superseded/; never applied), whose
-- G3 failed on production: two object names differ live, the compat mirror it rewrote no longer exists, and two of
-- its three retired RPCs are still called by every shipped client.
--
-- WHAT IT REMOVES (64 statements, the manifest below; md5 of the statements joined by newline in seq order =
-- 254f6202893607899592380ee724a79b, re-checked by G1):
--   meetups: 21 columns, every one except the 9 retained (id, event_id, vibe_key, meta, host_actor_id, members_only,
--            description, location_name, is_indoor). The values live on public.events (G5 proves parity first).
--   games:   search_tsv only (+ trg_games_search_tsv, idx_games_search_tsv). Not client-read: no select string in lib/ on
--            this branch, origin/main or origin/Alpha names it; the nullable Game.searchTsv field is filled only by a
--            select('*') and reads null when the key is absent; every search path reads search_tsv from events through
--            kan714_games_read (KAN-862 P5). Every other games column stays; the client-read ones are KAN-866 (C4).
--   policies 101-104: the legacy half of each (meetups.creator_user_id / listing_visibility) is removed; the events half,
--            kept, is the same predicate on events (kan713_meetup_* helpers) and the rows are equal (G5).
--   realtime 201/202: meetups stays published, with the column list (id, vibe_key).
--   triggers 302-334: the 15 meetups triggers of the old manifest that are still live, trg_games_search_tsv, and
--            trg_meetups_sync_geo (fn_sync_geo_fields reads NEW.area_id/geo_location_id; added). The trigger functions
--            stay (several also serve games). Kept on meetups: trg_kan711_meetups_assign_event_id,
--            trg_meetups_event_link_check, trg_zz_kan712_meetups_after_delete (they read id/event_id only).
--   indexes 403-416, constraints 516-528 on the dropped columns. Live names: 403 meetups_creator_request_id_key (the old
--            file said meetups_creator_user_request_id_key), 521 meetups_owner_profile_id_fkey (old: _creator_profile_id_fkey).
--   functions 803 getnearbygames (no caller in SQL, lib/ on any ref, or edge functions) and 804 rpc_create_meetup_legacy_v1
--            (no caller; postgres/service_role only; inserts dropped columns).
-- NOT REMOVED, against the old file: get_nearby_games x2 (old 801/802): called by the shipped client
--   (lib/data/repositories/nearby_games_repository_impl.dart:23, lib/features/games/data/datasources/supabase_games_datasource.dart:666
--   on HEAD, origin/main and origin/Alpha). Old 690/691 (kan712_events_compat_mirror rewrite): the function and its events
--   trigger no longer exist live. The dead kan711 tooling functions stay (no column drop fails because of them).
--
-- FAIL-CLOSED GATE (one block, every unmet precondition listed, raises once):
--   G1 the manifest is the pinned one (md5 + count)            G2 the caller bypasses RLS (else G5 undercounts)
--   G3 every manifest object exists on this database           G4 the events replacements exist
--   G5 D09 parity: games and meetups <-> events, every shared column, counts 1:1
--   G6 no pg_depend dependant of a dropped column outside the manifest (views, policies, indexes, constraints, triggers,
--      publications, statistics, anything else); column defaults go with their column
--   G7 no public function body reads a dropped column (KAN-862 P2 lexical scanner, PEER-reviewed in comments 16226/16229,
--      generalised to games.search_tsv), except functions the manifest drops, trigger functions reached only through a
--      trigger the manifest drops, and the kan711 tooling. (kan712_legacy_guard is attached only to meetups, by
--      trg_zz_kan712_meetups_guard, which the manifest drops; no games trigger uses it.)
-- The statements run from the md5-pinned manifest table, so what runs is exactly what G1 checked. The last block
-- re-checks the result. Run in one transaction (apply_migration does): any failure rolls everything back.
-- Pre-apply: supabase/tests/events_p4/kan719_z03_prestop_gate.sql (same manifest md5) runs read-only first.
-- RESTORE: the dropped meetups values equal events (G5) and the derived search_tsv is recomputed by the views. Pre-image
-- md5(pg_get_functiondef) of the two dropped functions: getnearbygames d4b7efecdaee83a216b99b9a0d037ce1,
-- rpc_create_meetup_legacy_v1 683eac510ce0b236f656ae8129da12ee (bodies in the repo baseline and git history).
-- IDEMPOTENT: no. A second run refuses at G3.

CREATE TEMP TABLE k862_z01_manifest (seq int PRIMARY KEY, kind text NOT NULL, tbl text NOT NULL, obj text NOT NULL, stmt text NOT NULL) ON COMMIT DROP;
INSERT INTO k862_z01_manifest (seq, kind, tbl, obj, stmt) VALUES
  (101, 'policy', 'meetups', 'meetups_select_visible', 'ALTER POLICY meetups_select_visible ON public.meetups USING (public.kan713_meetup_visible(event_id))'),
  (102, 'policy', 'meetup_attendees', 'meetup_attendees_select', 'ALTER POLICY meetup_attendees_select ON public.meetup_attendees USING (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND public.kan713_meetup_can_read_row(m.event_id)))'),
  (103, 'policy', 'meetup_attendees', 'meetup_attendees_select_visible', 'ALTER POLICY meetup_attendees_select_visible ON public.meetup_attendees USING ((auth.uid() = user_id) OR EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND public.kan713_meetup_attendee_visible(m.event_id)))'),
  (104, 'policy', 'meetup_attendees', 'meetup_attendees_write', 'ALTER POLICY meetup_attendees_write ON public.meetup_attendees USING (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND (public.kan713_meetup_can_write_row(m.event_id) OR auth.uid() = meetup_attendees.user_id))) WITH CHECK (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND (public.kan713_meetup_can_write_row(m.event_id) OR auth.uid() = meetup_attendees.user_id)))'),
  (201, 'publication', 'meetups', 'supabase_realtime', 'ALTER PUBLICATION supabase_realtime DROP TABLE ONLY public.meetups'),
  (202, 'publication', 'meetups', 'supabase_realtime', 'ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.meetups (id, vibe_key)'),
  (302, 'trigger', 'meetups', 'trg_kan711_meetups_mirror', 'DROP TRIGGER trg_kan711_meetups_mirror ON public.meetups'),
  (304, 'trigger', 'meetups', 'trg_zz_kan712_meetups_guard', 'DROP TRIGGER trg_zz_kan712_meetups_guard ON public.meetups'),
  (308, 'trigger', 'meetups', 'trg_kan713_meetups_a_location', 'DROP TRIGGER trg_kan713_meetups_a_location ON public.meetups'),
  (309, 'trigger', 'meetups', 'trg_kan713_meetups_b_joining', 'DROP TRIGGER trg_kan713_meetups_b_joining ON public.meetups'),
  (311, 'trigger', 'games', 'trg_games_search_tsv', 'DROP TRIGGER trg_games_search_tsv ON public.games'),
  (312, 'trigger', 'meetups', 'trg_meetups_search_tsv', 'DROP TRIGGER trg_meetups_search_tsv ON public.meetups'),
  (314, 'trigger', 'meetups', 'trg_meetups_touch', 'DROP TRIGGER trg_meetups_touch ON public.meetups'),
  (315, 'trigger', 'meetups', 'trg_meetups_updated', 'DROP TRIGGER trg_meetups_updated ON public.meetups'),
  (318, 'trigger', 'meetups', 'trg_meetups_inherit_geo', 'DROP TRIGGER trg_meetups_inherit_geo ON public.meetups'),
  (320, 'trigger', 'meetups', 'tr_meetups_activity_sync', 'DROP TRIGGER tr_meetups_activity_sync ON public.meetups'),
  (324, 'trigger', 'meetups', 'trg_meetups_cancel_notify', 'DROP TRIGGER trg_meetups_cancel_notify ON public.meetups'),
  (325, 'trigger', 'meetups', 'trg_meetups_outbox', 'DROP TRIGGER trg_meetups_outbox ON public.meetups'),
  (328, 'trigger', 'meetups', 'trg_meetups_stamp_request_id', 'DROP TRIGGER trg_meetups_stamp_request_id ON public.meetups'),
  (331, 'trigger', 'meetups', 'trg_meetups_enforce_solo_sport', 'DROP TRIGGER trg_meetups_enforce_solo_sport ON public.meetups'),
  (333, 'trigger', 'meetups', 'trg_meetups_sync_joining_rule', 'DROP TRIGGER trg_meetups_sync_joining_rule ON public.meetups'),
  (334, 'trigger', 'meetups', 'trg_meetups_sync_geo', 'DROP TRIGGER trg_meetups_sync_geo ON public.meetups'),
  (403, 'index', 'meetups', 'meetups_creator_request_id_key', 'DROP INDEX public.meetups_creator_request_id_key'),
  (409, 'index', 'games', 'idx_games_search_tsv', 'DROP INDEX public.idx_games_search_tsv'),
  (414, 'index', 'meetups', 'idx_meetups_owner', 'DROP INDEX public.idx_meetups_owner'),
  (415, 'index', 'meetups', 'idx_meetups_owner_time', 'DROP INDEX public.idx_meetups_owner_time'),
  (416, 'index', 'meetups', 'idx_meetups_search_tsv', 'DROP INDEX public.idx_meetups_search_tsv'),
  (516, 'constraint', 'meetups', 'chk_meetups_title_len', 'ALTER TABLE public.meetups DROP CONSTRAINT chk_meetups_title_len'),
  (517, 'constraint', 'meetups', 'meetups_area_id_fkey', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_area_id_fkey'),
  (518, 'constraint', 'meetups', 'meetups_capacity_check', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_capacity_check'),
  (519, 'constraint', 'meetups', 'meetups_cost_cover_check', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_cost_cover_check'),
  (520, 'constraint', 'meetups', 'meetups_cost_cover_logic', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_cost_cover_logic'),
  (521, 'constraint', 'meetups', 'meetups_owner_profile_id_fkey', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_owner_profile_id_fkey'),
  (522, 'constraint', 'meetups', 'meetups_geo_location_id_fkey', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_geo_location_id_fkey'),
  (523, 'constraint', 'meetups', 'meetups_joining_rule_check', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_joining_rule_check'),
  (524, 'constraint', 'meetups', 'meetups_listing_visibility_check', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_listing_visibility_check'),
  (525, 'constraint', 'meetups', 'meetups_rsvp_policy_check', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_rsvp_policy_check'),
  (526, 'constraint', 'meetups', 'meetups_sport_id_fkey', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_sport_id_fkey'),
  (527, 'constraint', 'meetups', 'meetups_title_check', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_title_check'),
  (528, 'constraint', 'meetups', 'meetups_venue_id_fkey', 'ALTER TABLE public.meetups DROP CONSTRAINT meetups_venue_id_fkey'),
  (616, 'column', 'games', 'search_tsv', 'ALTER TABLE public.games DROP COLUMN search_tsv'),
  (701, 'column', 'meetups', 'creator_profile_id', 'ALTER TABLE public.meetups DROP COLUMN creator_profile_id'),
  (702, 'column', 'meetups', 'creator_user_id', 'ALTER TABLE public.meetups DROP COLUMN creator_user_id'),
  (703, 'column', 'meetups', 'title', 'ALTER TABLE public.meetups DROP COLUMN title'),
  (704, 'column', 'meetups', 'listing_visibility', 'ALTER TABLE public.meetups DROP COLUMN listing_visibility'),
  (705, 'column', 'meetups', 'rsvp_policy', 'ALTER TABLE public.meetups DROP COLUMN rsvp_policy'),
  (706, 'column', 'meetups', 'capacity', 'ALTER TABLE public.meetups DROP COLUMN capacity'),
  (707, 'column', 'meetups', 'start_at', 'ALTER TABLE public.meetups DROP COLUMN start_at'),
  (708, 'column', 'meetups', 'end_at', 'ALTER TABLE public.meetups DROP COLUMN end_at'),
  (709, 'column', 'meetups', 'is_cancelled', 'ALTER TABLE public.meetups DROP COLUMN is_cancelled'),
  (710, 'column', 'meetups', 'created_at', 'ALTER TABLE public.meetups DROP COLUMN created_at'),
  (711, 'column', 'meetups', 'updated_at', 'ALTER TABLE public.meetups DROP COLUMN updated_at'),
  (712, 'column', 'meetups', 'search_tsv', 'ALTER TABLE public.meetups DROP COLUMN search_tsv'),
  (713, 'column', 'meetups', 'geo_location_id', 'ALTER TABLE public.meetups DROP COLUMN geo_location_id'),
  (714, 'column', 'meetups', 'sport_id', 'ALTER TABLE public.meetups DROP COLUMN sport_id'),
  (715, 'column', 'meetups', 'area_id', 'ALTER TABLE public.meetups DROP COLUMN area_id'),
  (716, 'column', 'meetups', 'venue_id', 'ALTER TABLE public.meetups DROP COLUMN venue_id'),
  (717, 'column', 'meetups', 'min_skill', 'ALTER TABLE public.meetups DROP COLUMN min_skill'),
  (718, 'column', 'meetups', 'max_skill', 'ALTER TABLE public.meetups DROP COLUMN max_skill'),
  (719, 'column', 'meetups', 'joining_rule', 'ALTER TABLE public.meetups DROP COLUMN joining_rule'),
  (720, 'column', 'meetups', 'cost_cover', 'ALTER TABLE public.meetups DROP COLUMN cost_cover'),
  (721, 'column', 'meetups', 'request_id', 'ALTER TABLE public.meetups DROP COLUMN request_id'),
  (803, 'function', 'games', 'getnearbygames(double precision,double precision,double precision)', 'DROP FUNCTION public.getnearbygames(double precision, double precision, double precision)'),
  (804, 'function', 'meetups', 'rpc_create_meetup_legacy_v1(text,uuid,uuid,text,text,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone,integer,text,text,boolean,integer,integer,text,jsonb)', 'DROP FUNCTION public.rpc_create_meetup_legacy_v1(text, uuid, uuid, text, text, uuid, text, uuid, uuid, timestamp with time zone, timestamp with time zone, integer, text, text, boolean, integer, integer, text, jsonb)');

DO $gate$
DECLARE
  fails text[] := '{}';
  x text;
  ok boolean;
  v_md5 text;
BEGIN
  -- G1
  SELECT md5(string_agg(stmt, E'\n' ORDER BY seq)) INTO v_md5 FROM k862_z01_manifest;
  IF v_md5 IS DISTINCT FROM '254f6202893607899592380ee724a79b' OR (SELECT count(*) FROM k862_z01_manifest) <> 64 THEN
    fails := fails || format('G1 manifest md5 %s / count %s is not the pinned 254f6202893607899592380ee724a79b / 64', v_md5, (SELECT count(*) FROM k862_z01_manifest));
  END IF;
  -- G2
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    fails := fails || format('G2 role %s does not bypass RLS', current_user);
  END IF;
  -- G3
  SELECT string_agg(DISTINCT m.seq || ' ' || m.kind || ' ' || m.tbl || '.' || m.obj, ', ') INTO x FROM k862_z01_manifest m
   WHERE NOT CASE m.kind
     WHEN 'policy'      THEN EXISTS (SELECT 1 FROM pg_policy WHERE polname = m.obj AND polrelid = ('public.' || m.tbl)::regclass)
     WHEN 'publication' THEN m.seq = 202 OR EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = m.obj AND schemaname = 'public' AND tablename = m.tbl)
     WHEN 'trigger'     THEN EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = ('public.' || m.tbl)::regclass AND tgname = m.obj AND NOT tgisinternal)
     WHEN 'index'       THEN EXISTS (SELECT 1 FROM pg_index WHERE indexrelid = to_regclass('public.' || m.obj) AND indrelid = ('public.' || m.tbl)::regclass)
     WHEN 'constraint'  THEN EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = ('public.' || m.tbl)::regclass AND conname = m.obj)
     WHEN 'column'      THEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = ('public.' || m.tbl)::regclass AND attname = m.obj AND NOT attisdropped)
     WHEN 'function'    THEN to_regprocedure('public.' || m.obj) IS NOT NULL
     ELSE false END;
  IF x IS NOT NULL THEN fails := fails || ('G3 manifest objects missing (regenerate the manifest for this database): ' || x); END IF;
  -- G4
  SELECT string_agg(t, ', ') INTO x FROM unnest(ARRAY['trg_events_search_tsv', 'trg_events_touch', 'trg_kan713_events_location',
                                                       'trg_kan718_events_series_occurrence']) t
   WHERE NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND tgname = t AND NOT tgisinternal);
  IF x IS NOT NULL THEN fails := fails || ('G4 events replacements missing: ' || x); END IF;
  -- G5 (kan718_d09_parity_precheck.sql section 2)
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
                         OR e.created_at IS DISTINCT FROM g.created_at OR e.updated_at IS DISTINCT FROM g.updated_at
                         OR e.search_tsv IS DISTINCT FROM g.search_tsv)
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
  IF NOT ok THEN fails := fails || 'G5 D09 parity fails: a subtype row differs from, or lacks, its events parent'::text; END IF;
  -- G6
  SELECT string_agg(DISTINCT k, ', ') INTO x FROM (
    SELECT CASE
             WHEN d.classid = 'pg_attrdef'::regclass THEN 'default'
             WHEN d.classid = 'pg_constraint'::regclass THEN 'constraint:' || (SELECT conname FROM pg_constraint WHERE oid = d.objid)
             WHEN d.classid = 'pg_class'::regclass AND (SELECT relkind FROM pg_class WHERE oid = d.objid) IN ('i', 'I')
               THEN 'index:' || (SELECT relname FROM pg_class WHERE oid = d.objid)
             WHEN d.classid = 'pg_trigger'::regclass THEN 'trigger:' || (SELECT tgname FROM pg_trigger WHERE oid = d.objid)
             WHEN d.classid = 'pg_policy'::regclass THEN 'policy:' || (SELECT polname FROM pg_policy WHERE oid = d.objid)
             WHEN d.classid = 'pg_publication_rel'::regclass THEN 'publication:supabase_realtime'
             ELSE 'other:' || pg_describe_object(d.classid, d.objid, d.objsubid) END AS k
      FROM pg_depend d
      JOIN k862_z01_manifest s ON s.kind = 'column' AND d.refclassid = 'pg_class'::regclass AND d.refobjid = ('public.' || s.tbl)::regclass
      JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid AND a.attname = s.obj
     WHERE NOT (d.classid = 'pg_class'::regclass AND d.objid = d.refobjid)) q
   WHERE k <> 'default' AND k NOT IN (SELECT kind || ':' || obj FROM k862_z01_manifest WHERE kind IN ('policy', 'trigger', 'index', 'constraint', 'publication'));
  IF x IS NOT NULL THEN fails := fails || ('G6 objects outside the manifest depend on a dropped column: ' || x); END IF;
  -- G7
  WITH sl AS (SELECT tbl, '(' || string_agg(obj, '|') || ')' r FROM k862_z01_manifest WHERE kind = 'column' GROUP BY tbl),
  f AS (SELECT p.oid, p.proname::text fn, p.prosrc s, sl.tbl, sl.r FROM pg_proc p JOIN sl ON p.prosrc ~* ('\m' || sl.tbl || '\M')
         WHERE p.pronamespace = 'public'::regnamespace),
  al AS (SELECT f.oid, f.tbl, lower(rm[1]) a FROM f, regexp_matches(f.s, 'public\.' || f.tbl || '\s+(?:as\s+)?([a-z_][a-z0-9_]*)', 'gi') rm
          WHERE lower(rm[1]) NOT IN ('where','on','join','set','for','left','inner','order','group','limit','using','values','returning','select','and','or')
         UNION SELECT f.oid, f.tbl, lower(rm[1]) FROM f, regexp_matches(f.s, '([a-z_][a-z0-9_]*)\s+public\.' || f.tbl || '%rowtype', 'gi') rm),
  hits AS (
    SELECT f.fn, NULL::text tg, 'alias ' || al.a || '.' || lower(h[1]) why FROM f JOIN al ON al.oid = f.oid AND al.tbl = f.tbl,
           regexp_matches(f.s, '\m' || al.a || '\.' || f.r || '\M', 'gi') h
    UNION SELECT f.fn, NULL, 'unqualified select ' || lower(h[1]) FROM f, regexp_matches(f.s, 'select\s+(?:[a-z_]+\.)?' || f.r || '\s+from\s+public\.' || f.tbl || '\s+where', 'gi') h
    UNION SELECT f.fn, NULL, 'where ' || lower(h[1]) FROM f, regexp_matches(f.s, 'from\s+public\.' || f.tbl || '\s+where\s+' || f.r || '\M', 'gi') h
    UNION SELECT f.fn, NULL, 'update set ' || lower(h[1]) FROM f, regexp_matches(f.s, 'update\s+public\.' || f.tbl || '\s+set[^;]*?\m' || f.r || '\s*=', 'gi') h
    UNION SELECT f.fn, NULL, 'insert ' || lower(h[1]) FROM f, regexp_matches(f.s, 'insert\s+into\s+public\.' || f.tbl || '\s*\([^)]*\m' || f.r || '\M', 'gi') h
    UNION SELECT p.proname::text, t.tgname::text, 'trigger NEW/OLD.' || lower(h[1])
      FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid JOIN sl ON t.tgrelid = ('public.' || sl.tbl)::regclass,
           regexp_matches(p.prosrc, '\m(?:new|old)\.' || sl.r || '\M', 'gi') h
     WHERE NOT t.tgisinternal AND p.pronamespace = 'public'::regnamespace)
  SELECT string_agg(DISTINCT h.fn || coalesce(' via ' || h.tg, '') || ' (' || h.why || ')', '; ') INTO x FROM hits h
   WHERE coalesce(h.tg, '') NOT IN (SELECT obj FROM k862_z01_manifest WHERE kind = 'trigger')
     AND h.fn NOT IN (SELECT split_part(obj, '(', 1) FROM k862_z01_manifest WHERE kind = 'function')
     AND h.fn NOT IN ('kan711_events_map_meetup', 'kan711_events_backfill_batch', 'kan711_meetups_mirror', 'kan711_events_backfill_run', 'kan711_events_validate_links');
  IF x IS NOT NULL THEN fails := fails || ('G7 function bodies read a dropped column: ' || x); END IF;

  IF cardinality(fails) > 0 THEN
    RAISE EXCEPTION 'KAN-862 Z01: removal refused, % unmet precondition(s): %', cardinality(fails), array_to_string(fails, ' | ');
  END IF;
END $gate$;

-- ===== the manifest, in seq order, exactly as G1 pinned it =====
DO $apply$
DECLARE r record;
BEGIN
  FOR r IN SELECT seq, stmt FROM k862_z01_manifest ORDER BY seq LOOP
    EXECUTE r.stmt;
  END LOOP;
END $apply$;

-- ===== post-condition =====
DO $post$
DECLARE x text;
BEGIN
  SELECT string_agg(c.relname || '.' || a.attname, ', ') INTO x
    FROM pg_class c JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
   WHERE c.oid = 'public.meetups'::regclass
     AND a.attname <> ALL ('{id,event_id,vibe_key,meta,host_actor_id,members_only,description,location_name,is_indoor}');
  IF x IS NOT NULL OR (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attnum > 0 AND NOT attisdropped) <> 9 THEN
    RAISE EXCEPTION 'KAN-862 Z01 post: meetups is not exactly the 9 retained columns (extra: %)', x;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'search_tsv' AND NOT attisdropped)
     OR (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attnum > 0 AND NOT attisdropped) <> 35 THEN
    RAISE EXCEPTION 'KAN-862 Z01 post: games is not the 35 retained columns';
  END IF;
  IF (SELECT count(*) FROM public.events) <> (SELECT count(*) FROM public.games) + (SELECT count(*) FROM public.meetups)
     OR (SELECT count(*) FROM public.meetups) <> (SELECT count(*) FROM public.events WHERE event_type = 'meetup')
     OR EXISTS (SELECT 1 FROM public.games WHERE event_id IS DISTINCT FROM id)
     OR EXISTS (SELECT 1 FROM public.meetups WHERE event_id IS DISTINCT FROM id) THEN
    RAISE EXCEPTION 'KAN-862 Z01 post: subtype/events linkage changed';
  END IF;
  IF (SELECT array_agg(tgname::text ORDER BY tgname) FROM pg_trigger WHERE tgrelid = 'public.meetups'::regclass AND NOT tgisinternal)
     IS DISTINCT FROM ARRAY['trg_kan711_meetups_assign_event_id', 'trg_meetups_event_link_check', 'trg_zz_kan712_meetups_after_delete'] THEN
    RAISE EXCEPTION 'KAN-862 Z01 post: meetups trigger set is not the 3 kept triggers';
  END IF;
  IF (SELECT attnames::text FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'meetups')
     IS DISTINCT FROM '{id,vibe_key}' THEN
    RAISE EXCEPTION 'KAN-862 Z01 post: meetups realtime column list is not (id, vibe_key)';
  END IF;
  IF to_regprocedure('public.getnearbygames(double precision,double precision,double precision)') IS NOT NULL
     OR EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_create_meetup_legacy_v1')
     OR to_regprocedure('public.get_nearby_games(double precision,double precision,double precision)') IS NULL
     OR to_regprocedure('public.get_nearby_games(double precision,double precision,integer)') IS NULL THEN
    RAISE EXCEPTION 'KAN-862 Z01 post: a retired function survived, or a client-called get_nearby_games is gone';
  END IF;
END $post$;
