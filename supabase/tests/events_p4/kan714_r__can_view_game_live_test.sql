-- KAN-903 live proof for supabase/migrations/20261111122000_kan714_r__can_view_game.sql (public._can_view_game(uuid)).
-- Runs on the hosted project as postgres inside BEGIN ... ROLLBACK; the fixture writes and the twins are undone.
--
-- TWINS. pg_temp.k903_pre is built from the live pg_get_functiondef by putting the games copy of the predicate back
-- (a no-op on the pre-image, so the same text works before and after the apply); T0 proves it byte-exact
-- (md5(prosrc) 7ee01526...). pg_temp.k903_mutant is the twin with listing_visibility ignored (read as 'public').
-- SCENARIOS. Every game (all 254) and one missing id, for callers creator, admin, an active roster member, a waitlisted
-- user, a user with no relation, anon, and the user 95743e37 (who blocks 1dbe85a1). Phase 'live' uses the data as it is;
-- phase 'fixture' sets six game events to private / followers with kan712.contract on (mirrored to games, parity kept).
--   T0 twin = pre-image; mutant differs from the twin
--   T1 the live body reads none of the 22 games columns through g.        RED before KAN-903, GREEN after
--   T2 live = twin on every scenario
--   T3 negative control: the mutant differs from the twin
--   T4 capture not trivial (true and false present, >= 6 caller kinds: game_waitlist is empty on 2026-11-12, so no
--      waitlisted caller exists; the waitlist branch is the same text in both copies)
--   T5 attributes / ACL unchanged
-- Pre-apply equality proof: run  BEGIN; <migration>; <this file>  in one call (the inner BEGIN only warns).
BEGIN;
CREATE TEMP TABLE k903_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k903_cap (fn text, k text, v boolean) ON COMMIT DROP;

DO $mk$
DECLARE d text := pg_get_functiondef('public._can_view_game(uuid)'::regprocedure);
BEGIN
  d := replace(d, 'public._can_view_game(', 'pg_temp.k903_pre(');
  d := replace(d, E'      -- KAN-903 (KAN-714): the predicate reads the shared facts from events only.\n',
    E'      and (\n        g.creator_user_id = auth.uid()\n        or public.is_admin(auth.uid())\n        or exists (\n'
    || E'             select 1 from public.game_roster gr\n             where gr.game_id = g.id\n'
    || E'               and gr.user_id = auth.uid()\n               and gr.status = ''active''\n           )\n'
    || E'        or exists (\n             select 1 from public.game_waitlist gw\n             where gw.game_id = g.id\n'
    || E'               and gw.user_id = auth.uid()\n           )\n        or public.can_view_with_scope(\n'
    || E'             auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id\n           )\n      )\n'
    || E'      -- KAN-713: the same predicate on the events fields; intersection, never wider.\n');
  EXECUTE d;
  EXECUTE replace(replace(replace(d, 'pg_temp.k903_pre(', 'pg_temp.k903_mutant('),
          'g.listing_visibility', '''public'''), 'e.listing_visibility', '''public''');
END
$mk$;

CREATE TEMP TABLE k903_case ON COMMIT DROP AS
WITH gs AS (SELECT g.id, e.creator_user_id FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
            UNION ALL SELECT '71200000-0000-0000-0000-0000000000ff'::uuid, NULL::uuid)
SELECT gs.id AS gid, 'creator' AS who, gs.creator_user_id AS uid FROM gs
UNION ALL SELECT gs.id, 'admin', (SELECT min(u.id::text)::uuid FROM auth.users u WHERE public.is_admin(u.id)) FROM gs
UNION ALL SELECT gs.id, 'member', (SELECT min(gr.user_id::text)::uuid FROM public.game_roster gr WHERE gr.game_id = gs.id
       AND gr.status = 'active' AND gr.user_id IS DISTINCT FROM gs.creator_user_id AND NOT public.is_admin(gr.user_id)) FROM gs
UNION ALL SELECT gs.id, 'waitlist', (SELECT min(gw.user_id::text)::uuid FROM public.game_waitlist gw WHERE gw.game_id = gs.id
       AND gw.user_id IS DISTINCT FROM gs.creator_user_id AND NOT public.is_admin(gw.user_id)) FROM gs
UNION ALL SELECT gs.id, 'stranger', (SELECT min(u.id::text)::uuid FROM auth.users u WHERE u.id IS DISTINCT FROM gs.creator_user_id
       AND NOT public.is_admin(u.id) AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.game_id = gs.id AND gr.user_id = u.id)
       AND NOT EXISTS (SELECT 1 FROM public.game_waitlist gw WHERE gw.game_id = gs.id AND gw.user_id = u.id)) FROM gs
UNION ALL SELECT gs.id, 'anon', NULL::uuid FROM gs;
DELETE FROM k903_case WHERE who IN ('member', 'waitlist', 'creator') AND uid IS NULL;
INSERT INTO k903_case SELECT gid, 'blocker_9574', u.id FROM (SELECT DISTINCT gid FROM k903_case) c,
  auth.users u WHERE u.id::text LIKE '95743e37%';

DO $run$
DECLARE fn text; r record; ph text; acc jsonb; v boolean;
BEGIN
  FOREACH ph IN ARRAY ARRAY['live', 'fixture'] LOOP
    IF ph = 'fixture' THEN
      PERFORM set_config('kan712.contract', 'on', true);
      UPDATE public.events e SET listing_visibility = CASE WHEN s.rn <= 3 THEN 'private' ELSE 'followers' END
        FROM (SELECT g.event_id, row_number() OVER (ORDER BY g.id) rn FROM public.games g JOIN public.events e2
                ON e2.id = g.event_id AND e2.event_type = 'game' WHERE e2.listing_visibility = 'public' ORDER BY g.id LIMIT 6) s
       WHERE e.id = s.event_id;
    END IF;
    FOREACH fn IN ARRAY ARRAY['public._can_view_game', 'pg_temp.k903_pre', 'pg_temp.k903_mutant'] LOOP
      acc := '{}';
      FOR r IN SELECT * FROM pg_temp.k903_case LOOP
        PERFORM set_config('request.jwt.claim.sub', coalesce(r.uid::text, ''), true);
        PERFORM set_config('request.jwt.claims', '', true);
        EXECUTE format('SELECT %s($1)', fn) INTO v USING r.gid;
        acc := acc || jsonb_build_object(ph || '|' || r.who || '|' || r.gid, v);
      END LOOP;
      INSERT INTO pg_temp.k903_cap SELECT fn, j.key, j.value::boolean FROM jsonb_each_text(acc) j;
    END LOOP;
  END LOOP;
END
$run$;

INSERT INTO k903_tap SELECT 0, md5(p.prosrc) = '7ee01526ff64e59691ada52fa77474ce' AND p.prosrc <> m.prosrc,
  'twin = pre-image; mutant differs', 'twin md5(prosrc) ' || md5(p.prosrc)
  FROM pg_proc p, pg_proc m WHERE p.proname = 'k903_pre' AND m.proname = 'k903_mutant'
   AND p.pronamespace = pg_my_temp_schema() AND m.pronamespace = pg_my_temp_schema();

INSERT INTO k903_tap SELECT 1,
  NOT (prosrc ~* '\mg\.(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M'),
  '_can_view_game reads none of the 22 games columns', 'md5(prosrc) ' || md5(prosrc)
  FROM pg_proc WHERE oid = 'public._can_view_game(uuid)'::regprocedure;

WITH a AS (SELECT k, v FROM k903_cap WHERE fn = 'public._can_view_game'),
     b AS (SELECT k, v FROM k903_cap WHERE fn = 'pg_temp.k903_pre')
INSERT INTO k903_tap SELECT 2, count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) = 0 AND count(*) > 0,
  'live = pre-image twin on every scenario',
  count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) || ' differing of ' || count(*) FROM a FULL JOIN b USING (k);

WITH a AS (SELECT k, v FROM k903_cap WHERE fn = 'pg_temp.k903_mutant'),
     b AS (SELECT k, v FROM k903_cap WHERE fn = 'pg_temp.k903_pre')
INSERT INTO k903_tap SELECT 3, count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) > 0,
  'negative control: mutant (visibility ignored) differs from twin',
  count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) || ' differing (live ' || count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v AND k LIKE 'live|%')
  || ', fixture ' || count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v AND k LIKE 'fixture|%') || ')'
  FROM a FULL JOIN b USING (k);

INSERT INTO k903_tap SELECT 4,
  count(*) >= 2500 AND bool_or(v) AND bool_or(NOT v) AND count(DISTINCT split_part(k, '|', 2)) >= 6
  AND bool_or(k LIKE 'fixture|stranger|%' AND NOT v),
  'capture not trivial', count(*) || ' scenarios; true=' || count(*) FILTER (WHERE v) || ' false=' || count(*) FILTER (WHERE NOT v)
  || ' callers=' || count(DISTINCT split_part(k, '|', 2))
  FROM k903_cap WHERE fn = 'pg_temp.k903_pre';

INSERT INTO k903_tap SELECT 5,
  p.proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
  AND p.prosecdef AND p.provolatile = 's' AND p.proconfig = '{search_path=public}' AND p.proowner = 'postgres'::regrole
  AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'sql'),
  'attributes / ACL unchanged', p.proacl::text
  FROM pg_proc p WHERE p.oid = 'public._can_view_game(uuid)'::regprocedure;

SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', ''), E'\n' ORDER BY n) AS tap
  FROM k903_tap;
ROLLBACK;
