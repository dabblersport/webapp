-- KAN-906 part 2 live proof for supabase/migrations/20261111120800_kan714_r_rpc_get_nearby_games_kan712_inner.sql
-- (the 6-argument public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)).
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK. The one
-- fixture write (phase 'fixture') is undone in a subtransaction, and the final ROLLBACK drops the twins.
--
-- METHOD. pg_temp.k906_pre is the live pre-image (games-side AND events-side visibility; T0 proves its md5(prosrc) is
-- b96323a71f8726e0ce6ab8ccc1a1dc69, the live body before KAN-906). pg_temp.k906_mutant has no visibility predicate. Each of the three functions (live, twin, mutant) is
-- called for 8 callers (the 4 creators of future games, the user who blocks one of them, an admin, a user with no
-- relation, anon) x 9 points (each future game's location, and 0,0) x radius {50 000 km, 3 km} x sort {distance,
-- price} x sport {any, one}, in two phases: 'live' (data as it is) and 'fixture' (future game 0eb7c9e2 made private
-- through its events row; the KAN-712 mirror carries it to games). Each call's full ordered result set is captured.
--   T0 the twin is the true pre-image (md5(prosrc) b96323a7...)
--   T1 the live function reads none of the 22 games columns through g.            -> RED before, GREEN after
--   T2 live capture = twin capture on every scenario
--   T3 the comparison has teeth: a mutant with no visibility predicate differs from the twin
--   T4 the capture is not trivial (scenario count, non-empty results, the blocked user excluded somewhere)
--   T5 the fixture took effect on both rows (parity kept) in phase 'fixture'
--   T6 attributes and ACL of the 6-arg as recorded before KAN-906
-- Pre-apply equality proof: run  BEGIN; <migration>; <this file>  in one call (the inner BEGIN only warns).
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k906_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k906_cap (fn text, k text, v jsonb) ON COMMIT DROP;
CREATE TEMP TABLE k906_fix (ok boolean, detail text) ON COMMIT DROP;

-- The twin and the mutant are built from the live definition (so this file needs no body copy): the games-side block
-- is re-inserted before the events-side block when absent, and the comment set back. T0 then proves the twin is
-- byte-exact against the pre-image md5, whichever side of the migration the catalogue is on.
DO $mk$
DECLARE
  c_g text := E'    and  (\n           (g.listing_visibility = ''public'' and not public.is_blocked(auth.uid(), g.creator_user_id))\n'
           || E'           or g.creator_user_id = auth.uid()\n           or public.can_view_with_scope(\n'
           || E'                auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id\n              )\n         )\n';
  c_e text := E'    and  (\n           (e.listing_visibility = ''public'' and not public.is_blocked(auth.uid(), e.creator_user_id))\n'
           || E'           or e.creator_user_id = auth.uid()\n           or public.can_view_with_scope(\n'
           || E'                auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id\n              )\n         )\n';
  v_def text;
BEGIN
  v_def := pg_get_functiondef('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'::regprocedure);
  v_def := replace(v_def, 'FUNCTION public.rpc_get_nearby_games(', 'FUNCTION pg_temp.k906_pre(');
  v_def := replace(v_def, 'access from events (KAN-807).', 'access intersected.');
  IF position(c_g IN v_def) = 0 THEN
    v_def := replace(v_def, c_e, c_g || c_e);
  END IF;
  EXECUTE v_def;
  -- mutant: no visibility predicate at all
  EXECUTE replace(replace(replace(v_def, 'FUNCTION pg_temp.k906_pre(', 'FUNCTION pg_temp.k906_mutant('), c_g, ''), c_e, '');
END
$mk$;

CREATE TEMP TABLE k906_user ON COMMIT DROP AS
WITH adm AS (SELECT min(user_id::text)::uuid AS uid FROM public.role_grants WHERE role IN ('admin', 'super_admin'))
SELECT * FROM (VALUES
  ('creator_9a93', '9a93bdf4-a293-485c-a9a9-3cd8844433c8'::uuid),
  ('creator_8c77', '8c7758ce-9367-4710-81ed-98d9a83e566a'::uuid),
  ('creator_6f7d', '6f7d9bcc-8371-4495-a78e-86f27d6dfe25'::uuid),
  ('creator_1dbe', '1dbe85a1-51bc-4e91-9000-1780a9dc3a22'::uuid),
  ('blocker_9574', '95743e37-9b52-495c-8c57-a0f935d3fd12'::uuid),
  ('anon', NULL::uuid)) v(who, uid)
UNION ALL SELECT 'admin', uid FROM adm
UNION ALL SELECT 'stranger', (SELECT min(u.id::text)::uuid FROM auth.users u
   WHERE NOT public.is_admin(u.id)
     AND NOT EXISTS (SELECT 1 FROM public.events e WHERE e.creator_user_id = u.id)
     AND NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE u.id IN (b.blocker_user_id, b.blocked_user_id))
     AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.user_id = u.id));

CREATE TEMP TABLE k906_param ON COMMIT DROP AS
WITH pts AS (
  SELECT DISTINCT st_y(gl.location::geometry) AS lat, st_x(gl.location::geometry) AS lng
    FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
    JOIN public.geo_locations gl ON gl.id = e.geo_location_id
   WHERE e.start_at > now() AND NOT e.is_cancelled
  UNION SELECT 0::float8, 0::float8)
SELECT pts.lat, pts.lng, r.radius, s.sort, sp.sport
  FROM pts,
       (VALUES (50000000), (3000)) r(radius),
       (VALUES ('distance'), ('price')) s(sort),
       (VALUES (NULL::uuid), ('2502490a-0339-436c-8b5e-5ac1514606c9'::uuid)) sp(sport);

DO $run$
DECLARE
  ph text; fn text; u record; p record; res jsonb; acc jsonb; v_g text; v_e text;
BEGIN
  FOREACH ph IN ARRAY ARRAY['live', 'fixture'] LOOP
    BEGIN
      acc := '{}'::jsonb;
      IF ph = 'fixture' THEN
        PERFORM set_config('kan712.contract', 'on', true);
        UPDATE public.events SET listing_visibility = 'private' WHERE id = '0eb7c9e2-4c6d-4b13-8592-6dfaa32b360d';
        SELECT g.listing_visibility, e.listing_visibility INTO v_g, v_e
          FROM public.games g JOIN public.events e ON e.id = g.event_id
         WHERE g.id = '0eb7c9e2-4c6d-4b13-8592-6dfaa32b360d';
      END IF;
      FOREACH fn IN ARRAY ARRAY['public.rpc_get_nearby_games', 'pg_temp.k906_pre', 'pg_temp.k906_mutant'] LOOP
        FOR u IN SELECT * FROM pg_temp.k906_user LOOP
          PERFORM set_config('request.jwt.claim.sub', coalesce(u.uid::text, ''), true);
          PERFORM set_config('request.jwt.claims', '', true);
          FOR p IN SELECT * FROM pg_temp.k906_param LOOP
            EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.ordinality), ''[]''::jsonb)'
                           ' FROM %s($1, $2, $3, $4, $5, NULL::numeric) WITH ORDINALITY t', fn)
              INTO res USING p.lat, p.lng, p.radius, p.sport, p.sort;
            acc := acc || jsonb_build_object(fn || '|' || ph || '|' || u.who || '|' || p.lat || ',' || p.lng || '|'
                                             || p.radius || '|' || p.sort || '|' || coalesce(p.sport::text, '-'), res);
          END LOOP;
        END LOOP;
      END LOOP;
      RAISE EXCEPTION 'k906_undo';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM <> 'k906_undo' THEN RAISE; END IF;
    END;
    -- after the undo: variables survive the subtransaction rollback, rows written inside it do not
    INSERT INTO pg_temp.k906_cap
      SELECT split_part(j.key, '|', 1), substr(j.key, length(split_part(j.key, '|', 1)) + 2), j.value FROM jsonb_each(acc) j;
    IF ph = 'fixture' THEN
      INSERT INTO pg_temp.k906_fix VALUES (v_g = 'private' AND v_e = 'private', 'games=' || coalesce(v_g, '?') || ' events=' || coalesce(v_e, '?'));
    END IF;
  END LOOP;
END
$run$;

INSERT INTO k906_tap SELECT 0, md5(p.prosrc) = 'b96323a71f8726e0ce6ab8ccc1a1dc69' AND m.prosrc !~ 'listing_visibility = ''public'' and not',
  'twin is the live pre-image; mutant has no visibility predicate', 'twin md5(prosrc) ' || md5(p.prosrc)
  FROM pg_proc p, pg_proc m
 WHERE p.oid = 'pg_temp.k906_pre(double precision,double precision,integer,uuid,text,numeric)'::regprocedure
   AND m.oid = 'pg_temp.k906_mutant(double precision,double precision,integer,uuid,text,numeric)'::regprocedure;

INSERT INTO k906_tap SELECT 1,
  NOT (prosrc ~* '\mg\.(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M'),
  '6-arg reads none of the 22 games columns', 'md5(prosrc) ' || md5(prosrc)
  FROM pg_proc WHERE oid = 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'::regprocedure;

WITH a AS (SELECT k, v FROM k906_cap WHERE fn = 'public.rpc_get_nearby_games'),
     b AS (SELECT k, v FROM k906_cap WHERE fn = 'pg_temp.k906_pre'),
     d AS (SELECT k FROM a FULL JOIN b USING (k) WHERE a.v IS DISTINCT FROM b.v)
INSERT INTO k906_tap SELECT 2, count(*) = 0 AND (SELECT count(*) FROM a) > 0, 'live = pre-image twin on every scenario',
  count(*) || ' differing of ' || (SELECT count(*) FROM a) FROM d;

WITH a AS (SELECT k, v FROM k906_cap WHERE fn = 'pg_temp.k906_mutant'),
     b AS (SELECT k, v FROM k906_cap WHERE fn = 'pg_temp.k906_pre'),
     d AS (SELECT k FROM a FULL JOIN b USING (k) WHERE a.v IS DISTINCT FROM b.v)
INSERT INTO k906_tap SELECT 3, count(*) > 0, 'negative control: mutant (no visibility) differs from twin',
  count(*) || ' differing (live phase ' || count(*) FILTER (WHERE k LIKE 'live|%') || ', fixture phase '
  || count(*) FILTER (WHERE k LIKE 'fixture|%') || ')' FROM d;

INSERT INTO k906_tap SELECT 4,
  count(*) >= 500 AND count(*) FILTER (WHERE jsonb_array_length(v) > 0) > 0
  AND bool_or(k LIKE 'live|blocker_9574|%' AND v @> '[{"id":"e36de0ab-38e0-4139-aae6-af392bc8e0c5"}]') IS NOT TRUE
  AND bool_or(k LIKE 'live|stranger|%' AND v @> '[{"id":"e36de0ab-38e0-4139-aae6-af392bc8e0c5"}]'),
  'capture not trivial; blocked creator''s game hidden from the blocker, shown to a stranger',
  count(*) || ' scenarios; non-empty ' || count(*) FILTER (WHERE jsonb_array_length(v) > 0)
  || '; max rows ' || max(jsonb_array_length(v))
  FROM k906_cap WHERE fn = 'pg_temp.k906_pre';

INSERT INTO k906_tap SELECT 5, coalesce(bool_and(ok), false), 'fixture (private) reached both rows', string_agg(detail, '; ')
  FROM k906_fix;

INSERT INTO k906_tap SELECT 6,
  p.proacl::text = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres,anon=X/postgres}'
  AND p.prosecdef AND p.provolatile = 's' AND p.proconfig = '{"search_path=public, pg_temp"}'
  AND p.proowner = 'postgres'::regrole,
  '6-arg attributes / ACL unchanged', p.proacl::text
  FROM pg_proc p WHERE p.oid = 'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)'::regprocedure;

SELECT CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
  FROM k906_tap ORDER BY n;
ROLLBACK;
