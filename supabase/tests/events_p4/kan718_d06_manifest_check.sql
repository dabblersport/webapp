-- KAN-774 (KAN-718 D06, Epic KAN-708): the exact deletion manifest, checked against the catalogue.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
-- Companion: supabase/tests/events_p4/KAN718_DELETION_MANIFEST.md. The TEMP table k774_manifest below IS the
-- manifest; the .md mirrors it with the evidence for every entry. Nothing here is a migration and nothing is
-- applied: every statement is AUTHORED for phase 4 and runs here only inside a transaction that rolls back.
--
--   M1  slated columns = games/meetups columns minus the retained list (KAN-718 retained-subtype data, plus the
--       KAN-861 F8 re-scope under CTO ruling dreq-0f6e9434: every games column D03 lists as client-read, and
--       ruling 2's meetups description/location_name/is_indoor); the manifest has exactly one DROP COLUMN per
--       slated column, and every retained column exists. Measured on the local chain: 22 slated (games 1,
--       meetups 21), 44 retained (games 35, meetups 9)
--   M2  every object with a column-level pg_depend on a slated column (constraint, index, trigger, policy, view,
--       publication) has its own manifest entry: no object is left for CASCADE
--   M3  every non-internal trigger on games/meetups whose function reads a slated NEW./OLD. column, or maps the
--       whole row through a kan711_events_map_* function that reads a slated column, has a manifest entry
--   M4  no statement contains CASCADE or a wildcard; every manifest object present locally exists; every named
--       replacement object exists in the catalogue
--   M5  every entry is BLOCKED or has a cited replacement, and every BLOCKED entry names its D01/D02/D03 evidence
--   D1  dry run, inside BEGIN ... ROLLBACK: each statement in manifest order, in its own savepoint, no CASCADE.
--       Every statement must succeed except those the manifest marks hard-blocked, which must be refused
--   S1-S5  one game + one meetup through the legacy path: rows not doubled, counts equal legacy, legacy shapes
--       unchanged, a stranger / blocked user sees nothing extra, ROLLBACK leaves data and shapes byte-identical
--
-- Run (repository root), on the cluster built by supabase/tests/events_p2/build_kan788.sh plus KAN-716/D07/KAN-785
-- (KAN718_DELETION_MANIFEST.md section 6 has the exact commands):
--   psql -X -h /tmp -p <port> -U postgres -d k788 -v ON_ERROR_STOP=1 -P pager=off \
--        -f supabase/tests/events_p4/kan718_d06_manifest_check.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-774: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k788|k774|kan774)' THEN
    RAISE EXCEPTION 'KAN-774: database % is not a KAN-774/788 throwaway database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-774: run as a superuser (the dry run alters tables)';
  END IF;
END $g$;

-- ---------------------------------------------------------------------------------------------
-- The retained list. why = kan718: verbatim from KAN-718 PRODUCT CONTRACT "Retained subtype data".
-- why = d03: KAN-861 F8, CTO ruling dreq-0f6e9434 rule 1: every games column D03 lists as client-read
--       (KAN718_D03_OLD_CLIENT_MATRIX.md, the 22 KAN-711 mapping columns) stays; only games.search_tsv goes.
-- why = ruling2: CTO ruling 2 keeps meetups.description, location_name and is_indoor (no events column).
-- ---------------------------------------------------------------------------------------------
CREATE TEMP TABLE k774_retained(tbl text, col text, why text);
INSERT INTO k774_retained
SELECT 'games', unnest('{id,event_id,game_type,venue_space_id,sport_variant_id,allow_spectators,rules,squad_id,sport_specific_data,allows_waitlist,bench_slots,price_aed,series_id}'::text[]), 'kan718'
UNION ALL
SELECT 'games', unnest('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'::text[]), 'd03'
UNION ALL
SELECT 'meetups', unnest('{id,event_id,vibe_key,meta,host_actor_id,members_only}'::text[]), 'kan718'
UNION ALL
SELECT 'meetups', unnest('{description,location_name,is_indoor}'::text[]), 'ruling2';

-- ---------------------------------------------------------------------------------------------
-- THE MANIFEST. seq = phase-4 order. kind: policy | publication | trigger | index | constraint | column | function.
-- seq numbers are stable across the KAN-861 F8 re-scope: entries for kept games objects were removed, never renumbered.
-- status: blocked = a D01/D02/D03 consumer remains (evidence column); every entry is blocked today.
-- hard: the dry run must REFUSE this statement (a dependency only a not-yet-authored replacement removes).
-- local: false = defined in the repo baseline but absent from the local harness catalogue (verify in prod).
-- repl_obj: catalogue object that replaces it ('-' = retired with the column, nothing to replace).
-- ---------------------------------------------------------------------------------------------
CREATE TEMP TABLE k774_manifest(seq int PRIMARY KEY, kind text, tbl text, obj text, stmt text, repl text, repl_obj text,
                                evidence text, hard boolean DEFAULT false, local boolean DEFAULT true);

-- 100: RLS policies. Replacement = the KAN-713 events half each policy already ANDs in; the legacy half goes.
INSERT INTO k774_manifest(seq, kind, tbl, obj, stmt, repl, repl_obj, evidence) VALUES
(101,'policy','meetups','meetups_select_visible',
 $s$ALTER POLICY meetups_select_visible ON public.meetups USING (public.kan713_meetup_visible(event_id))$s$,
 'events half kept: kan713_meetup_visible(event_id)','function:kan713_meetup_visible','D01 s3 RLS; D02 s5.3'),
(102,'policy','meetups','meetup_attendees_select ON meetup_attendees',
 $s$ALTER POLICY meetup_attendees_select ON public.meetup_attendees USING (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND public.kan713_meetup_can_read_row(m.event_id)))$s$,
 'events half kept: kan713_meetup_can_read_row(m.event_id)','function:kan713_meetup_can_read_row','D01 s3 RLS; D02 A1/A5'),
(103,'policy','meetups','meetup_attendees_select_visible ON meetup_attendees',
 $s$ALTER POLICY meetup_attendees_select_visible ON public.meetup_attendees USING ((auth.uid() = user_id) OR EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND public.kan713_meetup_attendee_visible(m.event_id)))$s$,
 'events half kept: kan713_meetup_attendee_visible(m.event_id)','function:kan713_meetup_attendee_visible','D01 s3 RLS; D02 A1/A5'),
(104,'policy','meetups','meetup_attendees_write ON meetup_attendees',
 $s$ALTER POLICY meetup_attendees_write ON public.meetup_attendees USING (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND (public.kan713_meetup_can_write_row(m.event_id) OR auth.uid() = meetup_attendees.user_id))) WITH CHECK (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND (public.kan713_meetup_can_write_row(m.event_id) OR auth.uid() = meetup_attendees.user_id)))$s$,
 'events half kept: kan713_meetup_can_write_row(m.event_id)','function:kan713_meetup_can_write_row','D01 s3 RLS; D02 A1/A5');

-- 200: KAN-716 realtime column lists. meetups keeps only retained columns. NO events-side replacement exists:
-- after the mirror retires a meetups row no longer changes when its event does. 201 (games) is gone in the F8
-- re-scope: the games publication list holds no slated column (search_tsv is not published), and the games
-- branch of the compat mirror stays, so games realtime is unchanged.
INSERT INTO k774_manifest(seq, kind, tbl, obj, stmt, repl, repl_obj, evidence) VALUES
(202,'publication','meetups','supabase_realtime',
 $s$ALTER PUBLICATION supabase_realtime SET TABLE ONLY public.meetups (id, vibe_key)$s$,
 'NOT AUTHORED: change signal for meetups listeners (D03 2d) needs a decision','-','D01 s3 KAN-716; D03 2d');

-- 300: triggers on games/meetups that read slated NEW./OLD. columns or the whole row. F8 re-scope: games triggers
-- on kept columns stay (CTO rule 3); only trg_games_search_tsv (311) reads the one slated games column.
INSERT INTO k774_manifest(seq, kind, tbl, obj, stmt, repl, repl_obj, evidence) VALUES
(302,'trigger','meetups','trg_kan711_meetups_mirror',$s$DROP TRIGGER trg_kan711_meetups_mirror ON public.meetups$s$,'infra: retired with the columns, same migration','-','D01 s3 KAN-711; D02 s5.4'),
(304,'trigger','meetups','trg_zz_kan712_meetups_guard',$s$DROP TRIGGER trg_zz_kan712_meetups_guard ON public.meetups$s$,'infra: retired with the columns, same migration','-','D01 s3 KAN-712; D02 s5.4'),
(308,'trigger','meetups','trg_kan713_meetups_a_location',$s$DROP TRIGGER trg_kan713_meetups_a_location ON public.meetups$s$,'infra; events side kept: trg_kan713_events_location','trigger:events.trg_kan713_events_location','D01 s3 KAN-713; D02 s5.4'),
(309,'trigger','meetups','trg_kan713_meetups_b_joining',$s$DROP TRIGGER trg_kan713_meetups_b_joining ON public.meetups$s$,'infra: retired with the columns, same migration','-','D01 s3 KAN-713; D02 s5.4'),
(311,'trigger','games','trg_games_search_tsv',$s$DROP TRIGGER trg_games_search_tsv ON public.games$s$,'trg_events_search_tsv','trigger:events.trg_events_search_tsv','D01 games.search_tsv; D02 A4'),
(312,'trigger','meetups','trg_meetups_search_tsv',$s$DROP TRIGGER trg_meetups_search_tsv ON public.meetups$s$,'trg_events_search_tsv','trigger:events.trg_events_search_tsv','D01 meetups.search_tsv; D02 A4'),
(314,'trigger','meetups','trg_meetups_touch',$s$DROP TRIGGER trg_meetups_touch ON public.meetups$s$,'trg_events_touch','trigger:events.trg_events_touch','D02 A4'),
(315,'trigger','meetups','trg_meetups_updated',$s$DROP TRIGGER trg_meetups_updated ON public.meetups$s$,'trg_events_touch','trigger:events.trg_events_touch','D02 A4'),
(318,'trigger','meetups','trg_meetups_inherit_geo',$s$DROP TRIGGER trg_meetups_inherit_geo ON public.meetups$s$,'trg_kan713_events_location (equivalence not proven here)','trigger:events.trg_kan713_events_location','D01 meetups.venue_id; D02 A4'),
(320,'trigger','meetups','tr_meetups_activity_sync',$s$DROP TRIGGER tr_meetups_activity_sync ON public.meetups$s$,'NOT AUTHORED: no events-side activity sync','-','D02 A2 trigger fn_meetups_activity_sync'),
(324,'trigger','meetups','trg_meetups_cancel_notify',$s$DROP TRIGGER trg_meetups_cancel_notify ON public.meetups$s$,'NOT AUTHORED: cancel notification on events.is_cancelled','-','D01 meetups.is_cancelled; D02 A4'),
(325,'trigger','meetups','trg_meetups_outbox',$s$DROP TRIGGER trg_meetups_outbox ON public.meetups$s$,'NOT AUTHORED: outbox reads creator_user_id/is_cancelled/start_at','-','D02 A4'),
(328,'trigger','meetups','trg_meetups_stamp_request_id',$s$DROP TRIGGER trg_meetups_stamp_request_id ON public.meetups$s$,'NOT AUTHORED: kan611_stamp_request_id has no events trigger','-','D01 s4 kan611_stamp_request_id'),
(331,'trigger','meetups','trg_meetups_enforce_solo_sport',$s$DROP TRIGGER trg_meetups_enforce_solo_sport ON public.meetups$s$,'NOT AUTHORED: solo sport rule on events.sport_id','-','D01 meetups.sport_id; D02 A2 trigger'),
(333,'trigger','meetups','trg_meetups_sync_joining_rule',$s$DROP TRIGGER trg_meetups_sync_joining_rule ON public.meetups$s$,'NOT AUTHORED: joining-rule sync on events (known conflict: Venue vs Space ids)','-','D01 meetups.venue_id; D02 A4');

-- 400: indexes (not constraint-backed). Replacements are the KAN-710 / B05 indexes on events. F8 re-scope: only
-- the games index on search_tsv (409) goes; the other games indexes cover kept columns.
INSERT INTO k774_manifest(seq, kind, tbl, obj, stmt, repl, repl_obj, evidence, local) VALUES
(403,'index','meetups','meetups_creator_user_request_id_key',$s$DROP INDEX public.meetups_creator_user_request_id_key$s$,'events_type_creator_request_id_key (contract scope: event_type + creator_profile_id)','index:events_type_creator_request_id_key','D01 meetups.request_id',true),
(409,'index','games','idx_games_search_tsv',$s$DROP INDEX public.idx_games_search_tsv$s$,'events_search_tsv_idx, events_game_public_search_tsv_idx','index:events_game_public_search_tsv_idx','B05 header I1; baseline',false),
(414,'index','meetups','idx_meetups_owner',$s$DROP INDEX public.idx_meetups_owner$s$,'events_creator_user_start_idx','index:events_creator_user_start_idx','B05 header I5; baseline',false),
(415,'index','meetups','idx_meetups_owner_time',$s$DROP INDEX public.idx_meetups_owner_time$s$,'events_creator_user_start_idx','index:events_creator_user_start_idx','B05 header I5; baseline',false),
(416,'index','meetups','idx_meetups_search_tsv',$s$DROP INDEX public.idx_meetups_search_tsv$s$,'events_search_tsv_idx','index:events_search_tsv_idx','B05 header I4; baseline',false);

-- 500: constraints. Replacements are the per-type KAN-710 checks and FKs on events (no union widening).
INSERT INTO k774_manifest(seq, kind, tbl, obj, stmt, repl, repl_obj, evidence)
SELECT seq, 'constraint', t, c,
       format('ALTER TABLE public.%I DROP CONSTRAINT %I', t, c), r, 'constraint:' || split_part(r, ' ', 1), 'D01 s3 constraints'
FROM (SELECT 500 + row_number() OVER (ORDER BY t, c) AS seq, * FROM (VALUES
 ('games','games_area_id_fkey','events_area_id_fkey'),
 ('games','games_capacity_check','events_game_capacity_check'),
 ('games','games_cost_cover_check','events_cost_cover_check'),
 ('games','games_cost_cover_logic','events_cost_cover_logic'),
 ('games','games_creator_profile_id_fkey','events_creator_profile_id_fkey'),
 ('games','games_geo_location_id_fkey','events_geo_location_id_fkey'),
 ('games','games_join_policy_check','events_game_join_policy_check'),
 ('games','games_join_policy_chk','events_game_join_policy_check'),
 ('games','games_joining_rule_check','events_joining_rule_check'),
 ('games','games_listing_visibility_check','events_game_visibility_check'),
 ('games','games_location_required','events_game_area_required + events_game_geo_required (verify equal or stricter)'),
 ('games','games_max_skill_check','events_game_skill_check'),
 ('games','games_min_skill_check','events_game_skill_check'),
 ('games','games_sport_id_fkey','events_sport_id_fkey'),
 ('games','games_venue_id_fkey','events_venue_id_fkey'),
 ('meetups','chk_meetups_title_len','events_meetup_title_check'),
 ('meetups','meetups_area_id_fkey','events_area_id_fkey'),
 ('meetups','meetups_capacity_check','events_meetup_capacity_check'),
 ('meetups','meetups_cost_cover_check','events_cost_cover_check'),
 ('meetups','meetups_cost_cover_logic','events_cost_cover_logic'),
 ('meetups','meetups_creator_profile_id_fkey','events_creator_profile_id_fkey'),
 ('meetups','meetups_geo_location_id_fkey','events_geo_location_id_fkey'),
 ('meetups','meetups_joining_rule_check','events_joining_rule_check'),
 ('meetups','meetups_listing_visibility_check','events_meetup_visibility_check'),
 ('meetups','meetups_rsvp_policy_check','events_meetup_join_policy_check (known conflict: rsvp_policy vs join_policy)'),
 ('meetups','meetups_sport_id_fkey','events_sport_id_fkey'),
 ('meetups','meetups_title_check','events_meetup_title_check'),
 ('meetups','meetups_venue_id_fkey','events_venue_id_fkey')) v(t, c, r)) n
-- F8 re-scope: the games constraints (501-515) are on kept columns and stay (CTO rule 3); numbering unchanged.
WHERE n.t = 'meetups';

-- 600/700: one DROP COLUMN per slated column; replacement = the same events column through event_id.
-- Evidence: D01 per-column row (40 pairs), D02 A2/A4, D03 G1-G17 (games only). seq = 600/700 + the column's rank
-- among the columns outside the KAN-718 list (attnum order), so the numbers are the ones the pre-F8 manifest used.
-- F8 re-scope (CTO ruling dreq-0f6e9434): the D03 client-read games columns and ruling 2's three meetups columns
-- are retained, so the slated set is games.search_tsv (616) plus the 21 meetups columns. Nothing is hard-blocked.
-- meetups.rsvp_policy lands on events.join_policy. KAN-716-listed columns are no longer blocked after 202.
INSERT INTO k774_manifest(seq, kind, tbl, obj, stmt, repl, repl_obj, evidence)
SELECT n.seq, 'column', n.t, n.attname,
       format('ALTER TABLE public.%I DROP COLUMN %I', n.t, n.attname),
       CASE WHEN n.attname = 'rsvp_policy' THEN 'events.join_policy via event_id (renamed; known value conflict)'
            ELSE 'events.' || n.attname || ' via event_id' END,
       CASE WHEN n.attname = 'rsvp_policy' THEN 'column:events.join_policy' ELSE 'column:events.' || n.attname END,
       CASE
         WHEN n.attname = 'search_tsv' THEN 'D01 ' || n.t || '.search_tsv; not in the D02/D03 slated sets'
         WHEN n.attname IN ('created_at','updated_at') THEN 'D02 s0 / D03 s1 (not in D01''s 40 pairs)'
         ELSE 'D01 meetups.' || n.attname || '; D02 A2/A4; D03 2c (no direct client read)'
       END
FROM (SELECT v.t, a.attname, CASE v.t WHEN 'games' THEN 600 ELSE 700 END + row_number() OVER (PARTITION BY v.t ORDER BY a.attnum) AS seq
        FROM (VALUES ('games'), ('meetups')) v(t)
        JOIN pg_attribute a ON a.attrelid = ('public.' || v.t)::regclass AND a.attnum > 0 AND NOT a.attisdropped
       WHERE NOT EXISTS (SELECT 1 FROM k774_retained r WHERE r.tbl = v.t AND r.col = a.attname AND r.why = 'kan718')) n
WHERE NOT EXISTS (SELECT 1 FROM k774_retained r WHERE r.tbl = n.t AND r.col = n.attname);

-- 800: retired RPCs (CTO ruling dreq-0f6e9434 rule 4). F1/F2 (KAN-718) retired them from the client; getnearbymeetups
-- was converted (F3) and stays. Baseline-only: the repo baseline defines them, the local harness does not, so the
-- Z01 test loads the baseline pre-images before it runs them. No CASCADE: the pg_depend and pg_proc body scans
-- (KAN-861 step c) show no dependants.
INSERT INTO k774_manifest(seq, kind, tbl, obj, stmt, repl, repl_obj, evidence, local) VALUES
(801,'function','games','get_nearby_games(double precision,double precision,double precision)',
 $s$DROP FUNCTION public.get_nearby_games(double precision, double precision, double precision)$s$,
 'retired by F1 (KAN-718): no client caller','-','F1 20261104112500_kan718_f1_get_nearby_games.sql; baseline',false),
(802,'function','games','get_nearby_games(double precision,double precision,integer)',
 $s$DROP FUNCTION public.get_nearby_games(double precision, double precision, integer)$s$,
 'retired by F1 (KAN-718): no client caller','-','F1 20261104112500_kan718_f1_get_nearby_games.sql; baseline',false),
(803,'function','games','getnearbygames(double precision,double precision,double precision)',
 $s$DROP FUNCTION public.getnearbygames(double precision, double precision, double precision)$s$,
 'retired by F2 (KAN-718): no client caller','-','F2 20261104112300_kan718_f2_getnearbygames.sql; baseline',false);

-- ---------------------------------------------------------------------------------------------
-- M1-M5: the manifest against the catalogue.
-- ---------------------------------------------------------------------------------------------
BEGIN TRANSACTION READ ONLY;
DO $m$
DECLARE x text; n int;
BEGIN
  -- M1
  SELECT string_agg(r.tbl || '.' || r.col, ', ') INTO x FROM k774_retained r
   WHERE NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = ('public.' || r.tbl)::regclass AND a.attname = r.col AND NOT a.attisdropped);
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-774 M1 FAIL: retained column(s) missing: %', x; END IF;
  SELECT count(*) INTO n FROM k774_manifest WHERE kind = 'column';
  -- F8 measured counts (KAN-861, CTO ruling dreq-0f6e9434): 22 slated (games 1, meetups 21), 44 retained (games 35, meetups 9)
  IF n <> 22 OR (SELECT count(*) FROM k774_manifest WHERE kind = 'column' AND tbl = 'games') <> 1
     OR (SELECT count(*) FROM k774_retained) <> 44 OR (SELECT count(*) FROM k774_retained WHERE tbl = 'games') <> 35
     OR EXISTS (SELECT 1 FROM k774_manifest WHERE kind = 'column' AND tbl = 'games' AND obj <> 'search_tsv') THEN
    RAISE EXCEPTION 'KAN-774 M1 FAIL: expected 22 slated (games: search_tsv only) / 44 retained (games 35, meetups 9), got % slated / % retained', n, (SELECT count(*) FROM k774_retained);
  END IF;
  IF (SELECT count(*) FROM k774_retained r JOIN pg_attribute a ON a.attrelid = ('public.' || r.tbl)::regclass AND a.attname = r.col AND NOT a.attisdropped)
     + n <> (SELECT count(*) FROM pg_attribute WHERE attrelid IN ('public.games'::regclass, 'public.meetups'::regclass) AND attnum > 0 AND NOT attisdropped) THEN
    RAISE EXCEPTION 'KAN-774 M1 FAIL: retained + slated does not partition the games/meetups columns';
  END IF;
  RAISE NOTICE 'KAN-774 M1 PASS: % DROP COLUMN entries (games %, meetups %); all % retained columns present (games %, meetups %)',
    n, (SELECT count(*) FROM k774_manifest WHERE kind = 'column' AND tbl = 'games'),
    (SELECT count(*) FROM k774_manifest WHERE kind = 'column' AND tbl = 'meetups'), (SELECT count(*) FROM k774_retained),
    (SELECT count(*) FROM k774_retained WHERE tbl = 'games'), (SELECT count(*) FROM k774_retained WHERE tbl = 'meetups');

  -- M2: every column-level dependent of a slated column has its own entry
  WITH sl AS (SELECT ('public.' || tbl)::regclass relid, tbl, obj col FROM k774_manifest WHERE kind = 'column'),
  dep AS (
    SELECT DISTINCT CASE d.classid
             WHEN 'pg_constraint'::regclass THEN 'constraint:' || (SELECT conname FROM pg_constraint WHERE oid = d.objid)
             WHEN 'pg_class'::regclass THEN 'index:' || (SELECT relname FROM pg_class WHERE oid = d.objid)
             WHEN 'pg_trigger'::regclass THEN 'trigger:' || (SELECT tgname FROM pg_trigger WHERE oid = d.objid)
             WHEN 'pg_policy'::regclass THEN 'policy:' || (SELECT polname FROM pg_policy WHERE oid = d.objid)
             WHEN 'pg_rewrite'::regclass THEN 'view:' || (SELECT ev_class::regclass::text FROM pg_rewrite WHERE oid = d.objid)
             WHEN 'pg_publication_rel'::regclass THEN 'publication:' || s.tbl
             WHEN 'pg_attrdef'::regclass THEN 'default'
             ELSE 'other:' || d.classid::regclass::text END AS o
      FROM pg_depend d JOIN sl s ON d.refclassid = 'pg_class'::regclass AND d.refobjid = s.relid
      JOIN pg_attribute a ON a.attrelid = s.relid AND a.attnum = d.refobjsubid AND a.attname = s.col
     WHERE NOT (d.classid = 'pg_class'::regclass AND EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conindid = d.objid)))
  SELECT string_agg(o, ', ' ORDER BY o) INTO x FROM dep
   WHERE o <> 'default'                                        -- column defaults go with their column
     AND NOT EXISTS (SELECT 1 FROM k774_manifest m
                      WHERE m.kind || ':' || CASE WHEN m.kind = 'publication' THEN m.tbl ELSE split_part(m.obj, ' ', 1) END = dep.o);
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-774 M2 FAIL: column-level dependent(s) with no manifest entry: %', x; END IF;
  RAISE NOTICE 'KAN-774 M2 PASS: every column-level dependent (constraint, index, trigger, policy, view, publication) has an entry; no exclusions';

  -- M3: every trigger reading slated NEW./OLD. columns or the whole row (the KAN-711 mirrors) has an entry
  SELECT string_agg(c.relname || '.' || t.tgname, ', ' ORDER BY 1) INTO x
    FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_proc p ON p.oid = t.tgfoid
   WHERE c.oid IN ('public.games'::regclass, 'public.meetups'::regclass) AND NOT t.tgisinternal
     AND p.proname <> 'harness_host_actor_stub'                -- local harness object, absent in production
     AND (EXISTS (SELECT 1 FROM pg_proc mp JOIN k774_manifest m ON m.kind = 'column' AND m.tbl = c.relname
                   WHERE mp.pronamespace = 'public'::regnamespace AND mp.proname ~ '^kan711_events_map_'
                     AND p.prosrc ~* ('\m' || mp.proname || '\M') AND mp.prosrc ~* ('\m' || m.obj || '\M'))
          OR EXISTS (SELECT 1 FROM k774_manifest m WHERE m.kind = 'column' AND m.tbl = c.relname
                      AND p.prosrc ~* ('\m(new|old)\.' || m.obj || '\M')))
     AND NOT EXISTS (SELECT 1 FROM k774_manifest m WHERE m.kind = 'trigger' AND m.obj = t.tgname);
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-774 M3 FAIL: trigger(s) reading slated columns with no entry: %', x; END IF;
  RAISE NOTICE 'KAN-774 M3 PASS: % trigger entries cover every trigger reading a slated column or the whole row',
    (SELECT count(*) FROM k774_manifest WHERE kind = 'trigger');

  -- M4: no CASCADE / wildcard; local objects exist; replacements exist
  SELECT string_agg(seq::text, ', ') INTO x FROM k774_manifest WHERE stmt ~* '\mcascade\M' OR stmt ~ '[*%]' OR stmt ~* '\mif exists\M';
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-774 M4 FAIL: CASCADE / wildcard / IF EXISTS in entries %', x; END IF;
  SELECT string_agg(seq || ' ' || obj, ', ') INTO x FROM k774_manifest m WHERE m.local AND NOT CASE m.kind
      WHEN 'trigger' THEN EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = ('public.' || m.tbl)::regclass AND tgname = m.obj)
      WHEN 'index' THEN to_regclass('public.' || m.obj) IS NOT NULL
      WHEN 'constraint' THEN EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = ('public.' || m.tbl)::regclass AND conname = m.obj)
      WHEN 'policy' THEN EXISTS (SELECT 1 FROM pg_policy WHERE polname = split_part(m.obj, ' ', 1))
      WHEN 'publication' THEN EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = m.obj AND tablename = m.tbl)
      WHEN 'function' THEN to_regprocedure('public.' || m.obj) IS NOT NULL
      ELSE true END;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-774 M4 FAIL: manifest object(s) absent locally: %', x; END IF;
  SELECT string_agg(seq || ' ' || repl_obj, ', ') INTO x FROM k774_manifest m WHERE repl_obj <> '-' AND NOT CASE split_part(repl_obj, ':', 1)
      WHEN 'function' THEN EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = split_part(repl_obj, ':', 2))
      WHEN 'trigger' THEN EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND tgname = split_part(split_part(repl_obj, ':', 2), '.', 2))
      WHEN 'index' THEN to_regclass('public.' || split_part(repl_obj, ':', 2)) IS NOT NULL
      WHEN 'constraint' THEN EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.events'::regclass AND conname = split_part(repl_obj, ':', 2))
      WHEN 'column' THEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.events'::regclass AND NOT attisdropped AND attname = split_part(repl_obj, '.', 2))
      ELSE false END;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-774 M4 FAIL: named replacement(s) missing from the catalogue: %', x; END IF;
  RAISE NOTICE 'KAN-774 M4 PASS: % statements, no CASCADE/wildcard/IF EXISTS; % local objects exist (% baseline-only, verify in production); % named replacements exist',
    (SELECT count(*) FROM k774_manifest), (SELECT count(*) FROM k774_manifest WHERE local),
    (SELECT count(*) FROM k774_manifest WHERE NOT local), (SELECT count(*) FROM k774_manifest WHERE repl_obj <> '-');

  -- M5: every entry carries evidence; the gate is still shut
  SELECT string_agg(seq::text, ', ') INTO x FROM k774_manifest WHERE coalesce(evidence, '') = '' OR coalesce(repl, '') = '';
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-774 M5 FAIL: entries without evidence or replacement text: %', x; END IF;
  RAISE NOTICE 'KAN-774 M5 PASS: every entry cites evidence; % entries have NO authored replacement; deletion stays BLOCKED (D01 40/40 pending, D02 BLOCKED, D03 BLOCKED)',
    (SELECT count(*) FROM k774_manifest WHERE repl LIKE 'NOT AUTHORED%' OR repl LIKE 'NO HOME%');
END $m$;
ROLLBACK;

-- ---------------------------------------------------------------------------------------------
-- Fingerprint for S5 / D1 (data and column shape of the three tables, plus the dependent-object census).
-- ---------------------------------------------------------------------------------------------
CREATE TEMP TABLE k774_fp AS SELECT
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t) g,
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t) m,
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) e,
  (SELECT md5(string_agg(attrelid::regclass || '.' || attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attrelid::regclass::text, attnum))
     FROM pg_attribute WHERE attrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND attnum > 0 AND NOT attisdropped) shape,
  (SELECT md5(coalesce((SELECT string_agg(tgname, ',' ORDER BY tgname) FROM pg_trigger WHERE tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass)), '')
            || coalesce((SELECT string_agg(conname, ',' ORDER BY conname) FROM pg_constraint WHERE conrelid IN ('public.games'::regclass, 'public.meetups'::regclass)), '')
            || coalesce((SELECT string_agg(polname || pg_get_expr(polqual, polrelid), ',' ORDER BY polname) FROM pg_policy WHERE polrelid IN ('public.meetups'::regclass, 'public.meetup_attendees'::regclass)), '')
            || coalesce((SELECT string_agg(tablename || attnames::text, ',' ORDER BY tablename) FROM pg_publication_tables WHERE pubname = 'supabase_realtime'), ''))) objs;

-- ---------------------------------------------------------------------------------------------
-- D1: dry run of the manifest in order, inside one transaction that rolls back. No CASCADE anywhere.
-- ---------------------------------------------------------------------------------------------
BEGIN;
DO $d$
DECLARE r record; ok int := 0; refused int := 0; skipped int := 0; bad text := ''; err text; det text;
BEGIN
  FOR r IN SELECT * FROM k774_manifest ORDER BY seq LOOP
    IF NOT r.local THEN skipped := skipped + 1; CONTINUE; END IF;
    BEGIN
      EXECUTE r.stmt;
      IF r.hard THEN bad := bad || format(' %s(%s.%s ran but is marked hard-blocked)', r.seq, r.tbl, r.obj); END IF;
      ok := ok + 1;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS err = MESSAGE_TEXT, det = PG_EXCEPTION_DETAIL;
      IF r.hard AND coalesce(det, '') ~ 'v_meetup_list' THEN
        refused := refused + 1;
        RAISE NOTICE 'KAN-774 D1 refused as expected: % %.% -> % (%)', r.seq, r.tbl, r.obj, err, replace(det, E'\n', '; ');
      ELSE
        bad := bad || format(' %s(%s.%s: %s)', r.seq, r.tbl, r.obj, err);
      END IF;
    END;
  END LOOP;
  IF bad <> '' THEN RAISE EXCEPTION 'KAN-774 D1 FAIL:%', bad; END IF;
  IF EXISTS (SELECT 1 FROM pg_attribute a JOIN k774_manifest m ON m.kind = 'column' AND NOT m.hard
              AND a.attrelid = ('public.' || m.tbl)::regclass AND a.attname = m.obj AND NOT a.attisdropped) THEN
    RAISE EXCEPTION 'KAN-774 D1 FAIL: a non-blocked slated column survived its DROP';
  END IF;
  RAISE NOTICE 'KAN-774 D1 PASS: % statements ran without CASCADE, % refused exactly where marked hard (v_meetup_list), % baseline-only skipped',
    ok, refused, skipped;
END $d$;
ROLLBACK;

DO $r$ BEGIN
  IF (SELECT shape FROM k774_fp) IS DISTINCT FROM (SELECT md5(string_agg(attrelid::regclass || '.' || attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attrelid::regclass::text, attnum))
        FROM pg_attribute WHERE attrelid IN ('public.games'::regclass, 'public.meetups'::regclass, 'public.events'::regclass) AND attnum > 0 AND NOT attisdropped)
     OR (SELECT objs FROM k774_fp) IS DISTINCT FROM (SELECT md5(coalesce((SELECT string_agg(tgname, ',' ORDER BY tgname) FROM pg_trigger WHERE tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass)), '')
            || coalesce((SELECT string_agg(conname, ',' ORDER BY conname) FROM pg_constraint WHERE conrelid IN ('public.games'::regclass, 'public.meetups'::regclass)), '')
            || coalesce((SELECT string_agg(polname || pg_get_expr(polqual, polrelid), ',' ORDER BY polname) FROM pg_policy WHERE polrelid IN ('public.meetups'::regclass, 'public.meetup_attendees'::regclass)), '')
            || coalesce((SELECT string_agg(tablename || attnames::text, ',' ORDER BY tablename) FROM pg_publication_tables WHERE pubname = 'supabase_realtime'), ''))) THEN
    RAISE EXCEPTION 'KAN-774 D1 FAIL: column shape or dependent objects changed after the dry-run ROLLBACK';
  END IF;
  RAISE NOTICE 'KAN-774 D1 rollback PASS: columns, triggers, constraints, policies and publication lists identical after ROLLBACK';
END $r$;

-- ---------------------------------------------------------------------------------------------
-- S1-S5: scenario on the intact schema. One game + one meetup through the legacy path; all rolls back.
-- ---------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.k774_as(p_uid uuid, p_sql text) RETURNS bigint LANGUAGE plpgsql AS $f$
DECLARE n bigint; BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', 'authenticated')::text END, true);
  EXECUTE 'SET LOCAL ROLE ' || CASE WHEN p_uid IS NULL THEN 'anon' ELSE 'authenticated' END;
  EXECUTE p_sql INTO n;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN n; END $f$;

BEGIN;
DO $s$
DECLARE
  owner    uuid := '00000000-0000-0000-0000-0000000000a1';
  stranger uuid := '00000000-0000-0000-0000-00000000dead';
  blocked  uuid := '00000000-0000-0000-0000-0000000000a6';   -- blocked by the owner (KAN-713 harness)
  q_g text := $q$SELECT count(*) FROM public.games WHERE id::text LIKE '77400000%'$q$;
  q_m text := $q$SELECT count(*) FROM public.meetups WHERE id::text LIKE '77400000%'$q$;
  q_e text := $q$SELECT count(*) FROM public.events WHERE id::text LIKE '77400000%'$q$;
  shape0 text; n_g0 bigint; n_m0 bigint; n_e0 bigint; x bigint; leak text := '';
BEGIN
  SELECT count(*) INTO n_g0 FROM public.games;
  SELECT count(*) INTO n_m0 FROM public.meetups;
  SELECT count(*) INTO n_e0 FROM public.events;

  INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                            sport_id, geo_location_id, area_id)
  VALUES ('77400000-0000-0000-0000-000000000001', 'D06 game', '00000000-0000-0000-0000-0000000000b1', owner,
          '2031-03-01 18:00+00', '2031-03-01 19:00+00', 10, 'public', 'open',
          '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');
  INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(m) || jsonb_build_object(
      'id', '77400000-0000-0000-0000-00000000f001', 'event_id', NULL, 'request_id', NULL, 'title', 'D06 meetup',
      'start_at', '2031-03-02 18:00+00', 'end_at', NULL, 'capacity', NULL, 'listing_visibility', 'public'))).*
    FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';

  -- S1 rows not doubled
  SELECT count(*) INTO x FROM public.events WHERE id::text LIKE '77400000%';
  IF x <> 2 OR (SELECT count(*) - count(DISTINCT id) FROM public.events) <> 0
     OR EXISTS (SELECT 1 FROM public.games WHERE id::text LIKE '77400000%' AND event_id IS DISTINCT FROM id)
     OR EXISTS (SELECT 1 FROM public.meetups WHERE id::text LIKE '77400000%' AND event_id IS DISTINCT FROM id) THEN
    RAISE EXCEPTION 'KAN-774 S1 FAIL: expected 2 events parents with event_id = id and no duplicate ids, got %', x;
  END IF;
  RAISE NOTICE 'KAN-774 S1 PASS: 1 game + 1 meetup seeded; one events parent each, id kept, no duplicate events ids';

  -- S2 counts equal legacy
  IF (SELECT count(*) FROM public.games) <> n_g0 + 1 OR (SELECT count(*) FROM public.meetups) <> n_m0 + 1
     OR (SELECT count(*) FROM public.events) <> n_e0 + 2
     OR (SELECT count(*) FROM public.games) <> (SELECT count(*) FROM public.events WHERE event_type = 'game')
     OR (SELECT count(*) FROM public.meetups) <> (SELECT count(*) FROM public.events WHERE event_type = 'meetup') THEN
    RAISE EXCEPTION 'KAN-774 S2 FAIL: counts diverge';
  END IF;
  RAISE NOTICE 'KAN-774 S2 PASS: games % = game events, meetups % = meetup events, events % = sum',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events);

  -- S3 legacy shapes unchanged: every manifest column still exists with its type, and the seeded legacy rows
  -- equal their events parent on the slated values (NULL end_at/capacity preserved, not invented)
  IF EXISTS (SELECT 1 FROM k774_manifest m WHERE m.kind = 'column' AND NOT EXISTS (
        SELECT 1 FROM pg_attribute a WHERE a.attrelid = ('public.' || m.tbl)::regclass AND a.attname = m.obj AND NOT a.attisdropped))
     OR (SELECT row(title, start_at, end_at, capacity, listing_visibility, join_policy, is_cancelled)::text FROM public.games WHERE id = '77400000-0000-0000-0000-000000000001')
        IS DISTINCT FROM (SELECT row(title, start_at, end_at, capacity, listing_visibility, join_policy, is_cancelled)::text FROM public.events WHERE id = '77400000-0000-0000-0000-000000000001')
     OR (SELECT row(title, start_at, end_at, capacity, listing_visibility)::text FROM public.meetups WHERE id = '77400000-0000-0000-0000-00000000f001')
        IS DISTINCT FROM (SELECT row(title, start_at, end_at, capacity, listing_visibility)::text FROM public.events WHERE id = '77400000-0000-0000-0000-00000000f001')
     OR (SELECT end_at IS NOT NULL OR capacity IS NOT NULL FROM public.events WHERE id = '77400000-0000-0000-0000-00000000f001') THEN
    RAISE EXCEPTION 'KAN-774 S3 FAIL: a manifest column is missing, a legacy row disagrees with its parent, or a NULL was invented';
  END IF;
  RAISE NOTICE 'KAN-774 S3 PASS: all % manifest columns still present (nothing deleted); legacy rows equal their events parent; NULLs preserved',
    (SELECT count(*) FROM k774_manifest WHERE kind = 'column');

  -- S4 a stranger / blocked user sees nothing extra
  IF pg_temp.k774_as(stranger, q_g) <> 0 OR pg_temp.k774_as(blocked, q_g) <> 0 THEN leak := leak || ' games'; END IF;
  BEGIN
    IF pg_temp.k774_as(stranger, q_e) <> 0 OR pg_temp.k774_as(blocked, q_e) <> 0 THEN leak := leak || ' events'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN RESET ROLE; RAISE NOTICE 'KAN-774 S4: events refused to API roles (42501), as designed';
  END;
  IF pg_temp.k774_as(blocked, q_m) <> 0 THEN leak := leak || ' meetups(blocked)'; END IF;
  IF pg_temp.k774_as(stranger, q_m) <> 1 THEN leak := leak || ' meetups(stranger<>1)'; END IF;
  PERFORM set_config('request.jwt.claim.sub', blocked::text, true);
  IF public._can_view_game('77400000-0000-0000-0000-000000000001') THEN leak := leak || ' _can_view_game(blocked)'; END IF;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  IF leak <> '' THEN RAISE EXCEPTION 'KAN-774 S4 FAIL: extra visibility:%', leak; END IF;
  RAISE NOTICE 'KAN-774 S4 PASS: stranger and blocked see 0 new games/events; stranger sees the public meetup (legacy), blocked sees 0';
END $s$;
ROLLBACK;

-- S5 rollback leaves data and shapes intact
DO $r$ BEGIN
  IF (SELECT g FROM k774_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t)
     OR (SELECT m FROM k774_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t)
     OR (SELECT e FROM k774_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) THEN
    RAISE EXCEPTION 'KAN-774 S5 FAIL: games/meetups/events data changed after ROLLBACK';
  END IF;
  RAISE NOTICE 'KAN-774 S5 PASS: md5 of games %, meetups %, events % identical after ROLLBACK',
    left((SELECT g FROM k774_fp), 8), left((SELECT m FROM k774_fp), 8), left((SELECT e FROM k774_fp), 8);
  RAISE NOTICE 'KAN-774 PASS: manifest matches the catalogue; deletion remains BLOCKED';
END $r$;
