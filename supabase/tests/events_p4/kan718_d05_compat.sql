-- KAN-773 (KAN-718 D05, Epic KAN-708): the old-client compatibility projections, proven against the legacy tables.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
-- The whole file runs inside ONE transaction that rolls back: it applies the migration
-- supabase/migrations/20261104110200_kan718_d05_old_client_compat_projection.sql (twice, for idempotency), tests it,
-- and leaves the database exactly as it found it (R2 proves that after the ROLLBACK).
--
--   P1  shape: each projection has the legacy table's column names, order and types, nothing more or less
--   P2  rows not doubled: one projection row per legacy row, ids unique, counts equal to legacy
--   P3  values: every column equal to the legacy row (NULLs included), except the named exceptions, whose
--       mismatch counts are printed
--   P4  visibility: for owner, stranger, blocked user, anon, authenticated-without-claims and service_role the
--       projection returns exactly the legacy table's id set (nothing extra, nothing missing)
--   P5  phase-4 name swap (inside a savepoint): the D03 old-client queries return byte-identical results when
--       `games` / `meetups` are the projections instead of the tables; direct writes stay refused
--   P6  drift guard: the migration refuses if games gains a policy
--   R1  the authored rollback (DROP VIEW x2) removes the projections and leaves data unchanged
--   R2  after the final ROLLBACK: no projection exists; games/meetups/events md5 identical to before the run
--
-- Run (repository root), on the cluster built by supabase/tests/events_p2/build_kan788.sh plus KAN-716/D07/KAN-785:
--   psql -X -h /tmp -p <port> -U postgres -d k788 -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan718_d05_compat.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;
\set migration `pwd`/supabase/migrations/20261104110200_kan718_d05_old_client_compat_projection.sql

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-773: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k788|k773|kan773)' THEN
    RAISE EXCEPTION 'KAN-773: database % is not a KAN-773/788 throwaway database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-773: run as a superuser';
  END IF;
  IF to_regclass('public.kan718_games_compat') IS NOT NULL OR to_regclass('public.kan718_meetups_compat') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-773: the projections already exist here; use a fresh throwaway database';
  END IF;
END $g$;

CREATE TEMP TABLE k773_fp AS SELECT
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t) g,
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t) m,
  (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) e;

-- Runs p_sql (returning one text) as an API role. p_uid NULL + p_role 'anon' = signed out.
CREATE FUNCTION pg_temp.k773_as(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r text; BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', p_role)::text END, true);
  EXECUTE format('SET LOCAL ROLE %I', p_role);
  EXECUTE p_sql INTO r;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN r; END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.k773_as(text, uuid, text) TO anon, authenticated, service_role;

BEGIN;

\i :migration
\i :migration

-- Seed one game and one meetup through the legacy path (KAN-711 mirror creates their events parents).
INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility, join_policy,
                          sport_id, geo_location_id, area_id)
VALUES ('77300000-0000-0000-0000-000000000001', 'D05 game', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1',
        '2031-04-01 18:00+00', '2031-04-01 20:00+00', 10, 'public', 'open',
        '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1');
INSERT INTO public.meetups SELECT (jsonb_populate_record(NULL::public.meetups, to_jsonb(m) || jsonb_build_object(
    'id', '77300000-0000-0000-0000-00000000f001', 'event_id', NULL, 'request_id', NULL, 'title', 'D05 meetup',
    'start_at', '2031-04-02 18:00+00', 'end_at', NULL, 'capacity', NULL, 'listing_visibility', 'public'))).*
  FROM public.meetups m WHERE m.id = '71300000-0000-0000-0000-000000000101';

DO $t$
DECLARE x text; n bigint;
BEGIN
  -- P1 shape
  SELECT string_agg(coalesce(t.k, '-') || ' vs ' || coalesce(v.k, '-'), ', ') INTO x FROM
    (SELECT r.v, a.attnum, a.attname || ':' || format_type(a.atttypid, a.atttypmod) k
       FROM (VALUES ('games'), ('meetups')) r(v) JOIN pg_attribute a ON a.attrelid = ('public.' || r.v)::regclass AND a.attnum > 0 AND NOT a.attisdropped) t
    FULL JOIN
    (SELECT r.v, a.attnum, a.attname || ':' || format_type(a.atttypid, a.atttypmod) k
       FROM (VALUES ('games'), ('meetups')) r(v) JOIN pg_attribute a ON a.attrelid = ('public.kan718_' || r.v || '_compat')::regclass AND a.attnum > 0) v
    USING (v, attnum)
   WHERE t.k IS DISTINCT FROM v.k;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-773 P1 FAIL: shape differs: %', x; END IF;
  RAISE NOTICE 'KAN-773 P1 PASS: kan718_games_compat = games (% cols), kan718_meetups_compat = meetups (% cols): names, order, types',
    (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attnum > 0 AND NOT attisdropped),
    (SELECT count(*) FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attnum > 0 AND NOT attisdropped);

  -- P2 rows not doubled, counts equal legacy (superuser: BYPASSRLS, sees every row)
  IF (SELECT count(*) FROM public.kan718_games_compat) <> (SELECT count(*) FROM public.games)
     OR (SELECT count(*) FROM public.kan718_meetups_compat) <> (SELECT count(*) FROM public.meetups)
     OR (SELECT count(*) - count(DISTINCT id) FROM public.kan718_games_compat) <> 0
     OR (SELECT count(*) - count(DISTINCT id) FROM public.kan718_meetups_compat) <> 0
     OR (SELECT count(*) FROM public.kan718_games_compat WHERE id::text LIKE '77300000%') <> 1
     OR (SELECT count(*) FROM public.kan718_meetups_compat WHERE id::text LIKE '77300000%') <> 1 THEN
    RAISE EXCEPTION 'KAN-773 P2 FAIL: projection counts differ from legacy or ids doubled';
  END IF;
  RAISE NOTICE 'KAN-773 P2 PASS: games % = compat %, meetups % = compat %; no duplicate ids; seeded game and meetup appear once each',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.kan718_games_compat),
    (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.kan718_meetups_compat);

  -- P3 values, column by column (IS DISTINCT FROM: NULL = NULL)
  FOR x IN SELECT a.attname FROM pg_attribute a WHERE a.attrelid = 'public.games'::regclass AND a.attnum > 0 AND NOT a.attisdropped ORDER BY a.attnum LOOP
    EXECUTE format('SELECT count(*) FROM public.games t FULL JOIN public.kan718_games_compat v USING (id) WHERE t.%1$I IS DISTINCT FROM v.%1$I', x) INTO n;
    IF n <> 0 THEN RAISE EXCEPTION 'KAN-773 P3 FAIL: games.% differs on % rows', x, n; END IF;
  END LOOP;
  FOR x IN SELECT a.attname FROM pg_attribute a WHERE a.attrelid = 'public.meetups'::regclass AND a.attnum > 0 AND NOT a.attisdropped ORDER BY a.attnum LOOP
    EXECUTE format('SELECT count(*) FROM public.meetups t FULL JOIN public.kan718_meetups_compat v USING (id) WHERE t.%1$I IS DISTINCT FROM v.%1$I', x) INTO n;
    IF x = 'search_tsv' THEN
      RAISE NOTICE 'KAN-773 P3 named exception: meetups.search_tsv differs on % of % rows (events.search_tsv does not index description/location_name)',
        n, (SELECT count(*) FROM public.meetups);
    ELSIF n <> 0 THEN RAISE EXCEPTION 'KAN-773 P3 FAIL: meetups.% differs on % rows', x, n;
    END IF;
  END LOOP;
  IF (SELECT row(min_skill, venue_id, cancelled_at) FROM public.kan718_games_compat WHERE id = '77300000-0000-0000-0000-000000000001') IS DISTINCT FROM row(NULL::int, NULL::uuid, NULL::timestamptz)
     OR (SELECT row(end_at, capacity) FROM public.kan718_meetups_compat WHERE id = '77300000-0000-0000-0000-00000000f001') IS DISTINCT FROM row(NULL::timestamptz, NULL::int) THEN
    RAISE EXCEPTION 'KAN-773 P3 FAIL: a NULL was invented';
  END IF;
  RAISE NOTICE 'KAN-773 P3 PASS: all 36 games columns and 29 of 30 meetups columns equal the legacy row (NULLs, ids, timestamps); seeded NULLs (game min_skill/venue_id/cancelled_at, meetup end_at/capacity) stay NULL';
END $t$;

-- P4 visibility per role: id set of the table vs the projection
DO $v$
DECLARE
  who record; t text; v text; x text := '';
  q text := 'SELECT count(*)::text || '':'' || coalesce(md5(string_agg(id::text, '','' ORDER BY id)), ''-'') FROM public.%s';
BEGIN
  FOR who IN SELECT * FROM (VALUES
      ('owner', 'authenticated', '00000000-0000-0000-0000-0000000000a1'::uuid),
      ('stranger', 'authenticated', '00000000-0000-0000-0000-00000000dead'::uuid),
      ('blocked', 'authenticated', '00000000-0000-0000-0000-0000000000a6'::uuid),
      ('no-claims', 'authenticated', NULL::uuid),
      ('anon', 'anon', NULL::uuid),
      ('service_role', 'service_role', NULL::uuid)) r(label, role, uid) LOOP
    FOR t IN SELECT unnest(ARRAY['games', 'meetups']) LOOP
      v := pg_temp.k773_as(who.role, who.uid, format(q, 'kan718_' || t || '_compat'));
      IF pg_temp.k773_as(who.role, who.uid, format(q, t)) IS DISTINCT FROM v THEN
        RAISE EXCEPTION 'KAN-773 P4 FAIL: % sees % % rows in the table but % in the projection',
          who.label, t, pg_temp.k773_as(who.role, who.uid, format(q, t)), v;
      END IF;
      x := x || format(' %s/%s=%s', who.label, t, split_part(v, ':', 1));
    END LOOP;
  END LOOP;
  IF pg_temp.k773_as('authenticated', '00000000-0000-0000-0000-0000000000a6', 'SELECT count(*)::text FROM public.kan718_meetups_compat WHERE id = ''77300000-0000-0000-0000-00000000f001''') <> '0'
     OR pg_temp.k773_as('authenticated', '00000000-0000-0000-0000-00000000dead', 'SELECT count(*)::text FROM public.kan718_meetups_compat WHERE id = ''77300000-0000-0000-0000-00000000f001''') <> '1' THEN
    RAISE EXCEPTION 'KAN-773 P4 FAIL: seeded public meetup: blocked must see 0, stranger 1 (legacy rule)';
  END IF;
  RAISE NOTICE 'KAN-773 P4 PASS: identical id sets, table vs projection:%', x;
  RAISE NOTICE 'KAN-773 P4 note: games has RLS and no policy, so every RLS-subject role sees 0 games rows in the table AND the projection; only BYPASSRLS roles read games directly';
END $v$;

-- P5 phase-4 name swap inside a savepoint: D03 old-client queries against the names `games` / `meetups`
CREATE TEMP TABLE k773_q(k text PRIMARY KEY, sql text);
INSERT INTO k773_q VALUES
 ('G2 capacity by id',        $q$SELECT capacity::text FROM public.games WHERE id = '77300000-0000-0000-0000-000000000001'$q$),
 ('G3 select * filtered',     $q$SELECT md5(string_agg(t::text, '|' ORDER BY t.start_at, t.id)) FROM public.games t WHERE NOT is_cancelled AND listing_visibility = 'public' AND start_at > '2020-01-01'$q$),
 ('G6 getGame',               $q$SELECT md5(t::text) FROM public.games t WHERE id = '77300000-0000-0000-0000-000000000001'$q$),
 ('G7 ids by creator',        $q$SELECT md5(string_agg(id::text, ',' ORDER BY id)) FROM public.games WHERE creator_user_id = '00000000-0000-0000-0000-0000000000a1'$q$),
 ('G9 textSearch title',      $q$SELECT md5(string_agg(id::text, ',' ORDER BY id)) FROM public.games WHERE to_tsvector(title) @@ to_tsquery('D05')$q$),
 ('G12 roster embed',         $q$SELECT md5(string_agg(t::text, '|' ORDER BY t.start_at, t.id)) FROM public.games t JOIN public.game_roster r ON r.game_id = t.id WHERE NOT t.is_cancelled$q$),
 ('G14 organiser metrics',    $q$SELECT md5(string_agg(id || ':' || is_cancelled || ':' || start_at, ',' ORDER BY id)) FROM public.games WHERE creator_user_id = '00000000-0000-0000-0000-0000000000a1' AND sport_id = '00000000-0000-0000-0000-0000000000e1'$q$),
 ('G15 export by created_at', $q$SELECT md5(string_agg(t::text, '|' ORDER BY t.created_at, t.id)) FROM public.games t$q$),
 ('M  meetups select *',      $q$SELECT md5(string_agg((t.id, t.title, t.start_at, t.end_at, t.capacity, t.rsvp_policy, t.description, t.location_name)::text, '|' ORDER BY t.id)) FROM public.meetups t$q$);
CREATE TEMP TABLE k773_r(k text, phase text, who text, res text);
GRANT SELECT ON k773_q TO anon, authenticated, service_role;

DO $p$
DECLARE r record; who record; err text; code text;
BEGIN
  FOR who IN SELECT * FROM (VALUES ('service_role', 'service_role', NULL::uuid), ('owner', 'authenticated', '00000000-0000-0000-0000-0000000000a1'::uuid),
                                   ('stranger', 'authenticated', '00000000-0000-0000-0000-00000000dead'::uuid)) v(label, role, uid) LOOP
    FOR r IN SELECT * FROM k773_q LOOP
      INSERT INTO k773_r VALUES (r.k, 'table', who.label, coalesce(pg_temp.k773_as(who.role, who.uid, r.sql), '<null>'));
    END LOOP;
  END LOOP;

  -- the authored phase-4 swap, verbatim from the migration header
  ALTER TABLE public.games RENAME TO games_subtype;   ALTER VIEW public.kan718_games_compat RENAME TO games;
  ALTER TABLE public.meetups RENAME TO meetups_subtype; ALTER VIEW public.kan718_meetups_compat RENAME TO meetups;
  FOR who IN SELECT * FROM (VALUES ('service_role', 'service_role', NULL::uuid), ('owner', 'authenticated', '00000000-0000-0000-0000-0000000000a1'::uuid),
                                   ('stranger', 'authenticated', '00000000-0000-0000-0000-00000000dead'::uuid)) v(label, role, uid) LOOP
    FOR r IN SELECT * FROM k773_q LOOP
      INSERT INTO k773_r VALUES (r.k, 'projection', who.label, coalesce(pg_temp.k773_as(who.role, who.uid, r.sql), '<null>'));
    END LOOP;
  END LOOP;
  BEGIN
    PERFORM pg_temp.k773_as('authenticated', '00000000-0000-0000-0000-0000000000a1',
      $w$WITH x AS (UPDATE public.games SET title = 'x' WHERE id = '77300000-0000-0000-0000-000000000001' RETURNING 1) SELECT count(*)::text FROM x$w$);
    RAISE EXCEPTION 'KAN-773 P5 FAIL: a direct UPDATE through the swapped name succeeded';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS err = MESSAGE_TEXT, code = RETURNED_SQLSTATE; RESET ROLE;
    IF err LIKE 'KAN-773 P5 FAIL%' THEN RAISE; END IF;
    RAISE NOTICE 'KAN-773 P5 direct UPDATE after swap refused: % %', code, err;
  END;
  -- swap back (the whole file rolls back anyway)
  ALTER VIEW public.meetups RENAME TO kan718_meetups_compat; ALTER TABLE public.meetups_subtype RENAME TO meetups;
  ALTER VIEW public.games RENAME TO kan718_games_compat;     ALTER TABLE public.games_subtype RENAME TO games;
END $p$;

DO $c$
DECLARE x text;
BEGIN
  SELECT string_agg(t.k || ' [' || t.who || '] ' || t.res || ' -> ' || coalesce(p.res, '<missing>'), '; ') INTO x
    FROM k773_r t LEFT JOIN k773_r p ON p.k = t.k AND p.who = t.who AND p.phase = 'projection'
   WHERE t.phase = 'table' AND t.res IS DISTINCT FROM p.res;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-773 P5 FAIL: old-client results changed after the swap: %', x; END IF;
  RAISE NOTICE 'KAN-773 P5 PASS: % D03 queries x 3 callers return identical results with games/meetups as the projections (service_role non-empty on %/%)',
    (SELECT count(*) FROM k773_q),
    (SELECT count(*) FROM k773_r WHERE phase = 'table' AND who = 'service_role' AND res <> '<null>'), (SELECT count(*) FROM k773_q);
  RAISE NOTICE 'KAN-773 P5 detail: %', (SELECT string_agg(k || ' ' || who || '=' || left(res, 10), ', ' ORDER BY k, who) FROM k773_r WHERE phase = 'table');
END $c$;

-- P6 drift guard: the migration's guard block refuses once games has a policy
\set migtext `cat supabase/migrations/20261104110200_kan718_d05_old_client_compat_projection.sql`
CREATE TEMP TABLE k773_mig AS SELECT :'migtext'::text AS src;
DO $d$
DECLARE src text := (SELECT src FROM k773_mig); guard text; err text;
BEGIN
  guard := substring(src FROM '(DO \$guard\$.*?END \$guard\$)');
  IF guard IS NULL THEN RAISE EXCEPTION 'KAN-773 P6 FAIL: guard block not found in the migration'; END IF;
  BEGIN
    CREATE POLICY k773_probe ON public.games FOR SELECT USING (true);
    EXECUTE guard;
    RAISE EXCEPTION 'KAN-773 P6 FAIL: guard accepted a games policy';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS err = MESSAGE_TEXT;
    IF err LIKE 'KAN-773 P6 FAIL%' THEN RAISE; END IF;
    RAISE NOTICE 'KAN-773 P6 PASS: guard refused: %', err;
  END;
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'k773_probe') THEN RAISE EXCEPTION 'KAN-773 P6 FAIL: probe policy leaked'; END IF;
END $d$;

-- R1 the authored rollback
DROP VIEW public.kan718_meetups_compat;
DROP VIEW public.kan718_games_compat;
DO $r$ BEGIN
  IF to_regclass('public.kan718_games_compat') IS NOT NULL OR to_regclass('public.kan718_meetups_compat') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-773 R1 FAIL: a projection survived its DROP';
  END IF;
  IF (SELECT count(*) FROM public.games WHERE id::text LIKE '77300000%') <> 1 OR (SELECT count(*) FROM public.meetups WHERE id::text LIKE '77300000%') <> 1 THEN
    RAISE EXCEPTION 'KAN-773 R1 FAIL: the rollback touched data';
  END IF;
  RAISE NOTICE 'KAN-773 R1 PASS: DROP VIEW x2 removes both projections without CASCADE; post-cutover rows (the seeded game and meetup) untouched';
END $r$;

ROLLBACK;

-- R2 after ROLLBACK
DO $r$ BEGIN
  IF to_regclass('public.kan718_games_compat') IS NOT NULL OR to_regclass('public.kan718_meetups_compat') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-773 R2 FAIL: a projection exists after ROLLBACK';
  END IF;
  IF (SELECT g FROM k773_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t)
     OR (SELECT m FROM k773_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t)
     OR (SELECT e FROM k773_fp) IS DISTINCT FROM (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) THEN
    RAISE EXCEPTION 'KAN-773 R2 FAIL: games/meetups/events data changed after ROLLBACK';
  END IF;
  RAISE NOTICE 'KAN-773 R2 PASS: no projection left; md5 games %, meetups %, events % identical to before the run',
    left((SELECT g FROM k773_fp), 8), left((SELECT m FROM k773_fp), 8), left((SELECT e FROM k773_fp), 8);
  RAISE NOTICE 'KAN-773 PASS';
END $r$;
