-- SUPERSEDED 2026-11-13 by KAN-718 (20261113052351_kan718_writers_update.sql): the inner this file pins was rewritten to
-- sync events itself, so the pre-image twin rebuilt from the live functiondef is no longer the KAN-912 pre-image (T0 pin
-- 4529d87f...). Point-in-time proof of its own migration; the current proof is kan718_writers_equality_live_test.sql.
-- KAN-912 live proof for supabase/migrations/20261111121400_kan714_w_rpc_update_game.sql
-- (public.rpc_update_game_kan712_inner, 17 arguments). Runs on the hosted project as postgres (Supabase execute_sql or
-- psql) inside BEGIN ... ROLLBACK: every call's writes are undone in a subtransaction and the final ROLLBACK drops the
-- twins. Nothing persists.
--
-- TWINS. pg_temp.k912_pre is built from the live pg_get_functiondef by undoing the KAN-912 edit (each replace is a no-op
-- on the pre-image, so the same text works before and after the apply); T0 proves it is byte-exact (md5(prosrc)
-- 4529d87f...). pg_temp.k912_mutant is the twin without the admin branch.
-- SCENARIOS. Every future game, the first 12 past games by id, one missing id; callers creator, admin, an active roster
-- member who is neither, a user with no relation, anon; parameter sets N (all optional null: the coalesce fallbacks),
-- V (explicit values, empty title, max_players below the roster), C (clear skill and venue), X1 (end before start),
-- X2 (no price). Captured per call: result or ERR sqlstate message, and the games and events rows (updated_at dropped).
--   T0 twin = pre-image; mutant = twin minus the admin branch
--   T1 the live inner reads none of the 22 games columns through g.        RED before KAN-912, GREEN after
--   T2 live capture = twin capture on every scenario
--   T3 negative control: the mutant differs from the twin
--   T4 capture not trivial ('updated' and each error present)
--   T5 inner and wrapper attributes / ACL as recorded before KAN-912
-- Pre-apply equality proof: run  BEGIN; <migration>; <this file>  in one call (the inner BEGIN only warns).
BEGIN;
CREATE TEMP TABLE k912_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k912_cap (fn text, k text, v jsonb) ON COMMIT DROP;

DO $mk$
DECLARE d text := pg_get_functiondef('public.rpc_update_game_kan712_inner(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure);
BEGIN
  d := replace(d, 'public.rpc_update_game_kan712_inner(', 'pg_temp.k912_pre(');
  d := replace(d, E'  from public.events e\n  where e.id = g.event_id\n    and e.event_type = ''game''\n    and g.id = p_game_id\n    and e.is_cancelled = false\n    and e.end_at > now()\n    and (e.creator_user_id = auth.uid()',
                  E'  where g.id = p_game_id\n    and g.is_cancelled = false\n    and g.end_at > now()\n    and (g.creator_user_id = auth.uid()');
  d := replace(d, E'\n  -- KAN-912: shared facts read from events e (authoritative); game-only columns from g; SET targets unchanged.\n', E'\n');
  d := replace(d, 'coalesce(p_max_players, e.capacity)', 'coalesce(p_max_players, g.capacity)');
  d := replace(d, 'coalesce(p_max_skill, e.max_skill)', 'coalesce(p_max_skill, g.max_skill)');
  d := replace(d, 'coalesce(p_min_skill, e.min_skill)', 'coalesce(p_min_skill, g.min_skill)');
  d := replace(d, 'coalesce(p_join_policy, e.join_policy)', 'coalesce(p_join_policy, g.join_policy)');
  d := replace(d, 'coalesce(p_listing_visibility, e.listing_visibility)', 'coalesce(p_listing_visibility, g.listing_visibility)');
  d := replace(d, 'coalesce(nullif(p_title, ''''), e.title)', 'coalesce(nullif(p_title, ''''), g.title)');
  EXECUTE d;
  EXECUTE replace(replace(d, 'pg_temp.k912_pre(', 'pg_temp.k912_mutant('), ' or public.is_admin(auth.uid()))', ')');
END
$mk$;

CREATE TEMP TABLE k912_case ON COMMIT DROP AS
WITH gs AS (
  (SELECT g.id, e.creator_user_id FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
    WHERE e.end_at > now() AND NOT e.is_cancelled)
  UNION ALL
  (SELECT g.id, e.creator_user_id FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
    WHERE e.end_at <= now() ORDER BY g.id LIMIT 12))
SELECT gs.id AS gid, 'creator' AS who, gs.creator_user_id AS uid FROM gs
UNION ALL SELECT gs.id, 'admin', (SELECT min(u.id::text)::uuid FROM auth.users u WHERE public.is_admin(u.id)) FROM gs
UNION ALL SELECT gs.id, 'member',
       (SELECT min(gr.user_id::text)::uuid FROM public.game_roster gr
         WHERE gr.game_id = gs.id AND gr.status = 'active' AND gr.user_id IS DISTINCT FROM gs.creator_user_id
           AND NOT public.is_admin(gr.user_id)) FROM gs
UNION ALL SELECT gs.id, 'stranger',
       (SELECT min(u.id::text)::uuid FROM auth.users u
         WHERE u.id IS DISTINCT FROM gs.creator_user_id AND NOT public.is_admin(u.id)
           AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.game_id = gs.id AND gr.user_id = u.id)) FROM gs
UNION ALL SELECT gs.id, 'anon', NULL::uuid FROM gs
UNION ALL SELECT '71200000-0000-0000-0000-0000000000ff'::uuid, 'missing', (SELECT creator_user_id FROM gs LIMIT 1);
DELETE FROM k912_case WHERE who = 'member' AND uid IS NULL;

CREATE TEMP TABLE k912_param ON COMMIT DROP AS SELECT * FROM (VALUES
  ('N',  interval '2 days', interval '2 days 2 hours', NULL::text, NULL::uuid, false, NULL::text, NULL::text, NULL::boolean, NULL::boolean, NULL::int, NULL::int, false, NULL::jsonb, NULL::int, NULL::int, 10::numeric),
  ('V',  interval '3 days', interval '3 days 1 hour', '', NULL, false, 'followers', NULL, true, false, 2, 4, false, '{"k912":1}'::jsonb, 1, 1, 12.345),
  ('C',  interval '4 days', interval '4 days 3 hours', 'k912 title', NULL, true, 'public', NULL, NULL, true, NULL, NULL, true, NULL, NULL, 20, 0),
  ('X1', interval '2 days', interval '1 day', NULL, NULL, false, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, 10),
  ('X2', interval '2 days', interval '2 days 2 hours', NULL, NULL, false, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL)
) v(pk, ds, de, title, venue, cv, vis, jp, spec, wl, mins, maxs, cs, rules, minp, maxp, price);

DO $run$
DECLARE fn text; r record; p record; r1 text; acc jsonb;
BEGIN
  FOREACH fn IN ARRAY ARRAY['public.rpc_update_game_kan712_inner', 'pg_temp.k912_pre', 'pg_temp.k912_mutant'] LOOP
    acc := '{}';
    FOR r IN SELECT * FROM pg_temp.k912_case LOOP
      FOR p IN SELECT * FROM pg_temp.k912_param LOOP
        BEGIN
          PERFORM set_config('request.jwt.claim.sub', coalesce(r.uid::text, ''), true);
          PERFORM set_config('request.jwt.claims', '', true);
          PERFORM set_config('kan712.contract', 'on', true);
          BEGIN
            EXECUTE format('SELECT %s($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)', fn) INTO r1
              USING r.gid, now() + p.ds, now() + p.de, p.title, p.venue, p.cv, p.vis, p.jp, p.spec, p.wl,
                    p.mins, p.maxs, p.cs, p.rules, p.minp, p.maxp, p.price;
          EXCEPTION WHEN OTHERS THEN r1 := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END;
          acc := acc || jsonb_build_object(r.gid || '/' || r.who || '/' || p.pk, jsonb_build_object('r', r1,
            'g', (SELECT to_jsonb(g) - 'updated_at' FROM public.games g WHERE g.id = r.gid),
            'e', (SELECT to_jsonb(e) - 'updated_at' FROM public.events e JOIN public.games g ON g.event_id = e.id WHERE g.id = r.gid)));
          RAISE EXCEPTION 'k912_undo';
        EXCEPTION WHEN raise_exception THEN
          IF SQLERRM <> 'k912_undo' THEN RAISE; END IF;
        END;
      END LOOP;
    END LOOP;
    INSERT INTO pg_temp.k912_cap SELECT fn, j.key, j.value FROM jsonb_each(acc) j;
  END LOOP;
END
$run$;

INSERT INTO k912_tap SELECT 0, md5(p.prosrc) = '4529d87f1cbb5b5ff856fa39f33bb75f'
  AND replace(p.prosrc, ' or public.is_admin(auth.uid()))', ')') = m.prosrc AND p.prosrc <> m.prosrc,
  'twin = pre-image; mutant = twin minus the admin branch', 'twin md5(prosrc) ' || md5(p.prosrc)
  FROM pg_proc p, pg_proc m WHERE p.proname = 'k912_pre' AND m.proname = 'k912_mutant'
   AND p.pronamespace = pg_my_temp_schema() AND m.pronamespace = pg_my_temp_schema();

INSERT INTO k912_tap SELECT 1,
  NOT (prosrc ~* '\mg\.(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M'),
  'inner reads none of the 22 games columns', 'md5(prosrc) ' || md5(prosrc)
  FROM pg_proc WHERE oid = 'public.rpc_update_game_kan712_inner(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure;

WITH a AS (SELECT k, v FROM k912_cap WHERE fn = 'public.rpc_update_game_kan712_inner'),
     b AS (SELECT k, v FROM k912_cap WHERE fn = 'pg_temp.k912_pre')
INSERT INTO k912_tap SELECT 2, count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) = 0 AND count(*) > 0,
  'live inner = pre-image twin on every scenario',
  count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) || ' differing of ' || count(*) FROM a FULL JOIN b USING (k);

WITH a AS (SELECT k, v FROM k912_cap WHERE fn = 'pg_temp.k912_mutant'),
     b AS (SELECT k, v FROM k912_cap WHERE fn = 'pg_temp.k912_pre')
INSERT INTO k912_tap SELECT 3, count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) > 0,
  'negative control: mutant differs from twin', count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) || ' differing'
  FROM a FULL JOIN b USING (k);

INSERT INTO k912_tap SELECT 4,
  count(*) >= 300 AND bool_or(v->>'r' = 'updated') AND bool_or(v->>'r' LIKE '%not_host_or_not_found%')
  AND bool_or(v->>'r' LIKE '%invalid_time_range%') AND bool_or(v->>'r' LIKE '%price_required%'),
  'capture not trivial',
  count(*) || ' scenarios; updated=' || count(*) FILTER (WHERE v->>'r' = 'updated')
  || ' not_found=' || count(*) FILTER (WHERE v->>'r' LIKE '%not_host_or_not_found%')
  || ' invalid_time_range=' || count(*) FILTER (WHERE v->>'r' LIKE '%invalid_time_range%')
  || ' price_required=' || count(*) FILTER (WHERE v->>'r' LIKE '%price_required%')
  FROM k912_cap WHERE fn = 'pg_temp.k912_pre';

INSERT INTO k912_tap SELECT 5,
  (SELECT p.proacl::text = '{postgres=X/postgres}' AND p.prosecdef AND p.proconfig = '{search_path=public}'
          AND p.proowner = 'postgres'::regrole
     FROM pg_proc p WHERE p.oid = 'public.rpc_update_game_kan712_inner(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure)
  AND (SELECT p.proacl::text = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
          AND md5(pg_get_functiondef(p.oid)) = 'e15cf3599f498204b3f12b92f9f0131d'
     FROM pg_proc p WHERE p.oid = 'public.rpc_update_game(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure),
  'inner and wrapper attributes / ACL unchanged', NULL;

SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', ''), E'\n' ORDER BY n) AS tap
  FROM k912_tap;
ROLLBACK;
