-- KAN-913 live proof for supabase/migrations/20261111121500_kan714_w_rpc_cancel_game_kan712_inner.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK: every
-- call's writes are undone in a subtransaction, and the final ROLLBACK drops the twins. Nothing persists.
--
-- METHOD. pg_temp.k913_pre is the live pre-image body (md5(prosrc) 0b5bd8bbda5cfac206e75b262503c0cf, reads
-- games.creator_user_id). For the first 40 games (by id) x 5 callers (creator, admin, an active roster member who is
-- not the creator, a user with no relation to the game, anon) each function is called twice (cancel, then repeat),
-- each scenario in its own subtransaction; captured per scenario: both results (or ERR sqlstate message) and the full
-- games and events rows afterwards. The live inner and the twin must give identical captures.
--   T1 the live inner reads none of the 22 games columns (no g./games. qualified mention; no bare mention outside
--      the unchanged SET list)                    -> RED before the migration is applied, GREEN after
--   T2 live inner capture = pre-image twin capture, both ways (count of differing scenarios = 0)
--   T3 the comparison has teeth: a mutant (admin branch removed) differs from the twin on > 0 scenarios
--   T4 the capture is not trivial: >= 150 scenarios, both 'cancelled' and ERR P0001 results present
--   T5 attributes of the inner and wrapper as recorded before KAN-913 (owner, ACL, SECURITY DEFINER, search_path)
-- Pre-apply equality proof: run  BEGIN; <migration>; <this file>  in one call (the inner BEGIN only warns).
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k913_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k913_cap (fn text, k text, v jsonb) ON COMMIT DROP;

CREATE FUNCTION pg_temp.k913_pre(p_game_id uuid, p_reason text DEFAULT NULL::text) RETURNS text
LANGUAGE plpgsql SET search_path TO 'public' AS $function$
BEGIN
  UPDATE public.games
  SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
  WHERE id = p_game_id
    AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()));
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  RETURN 'cancelled';
END$function$;

CREATE FUNCTION pg_temp.k913_mutant(p_game_id uuid, p_reason text DEFAULT NULL::text) RETURNS text
LANGUAGE plpgsql SET search_path TO 'public' AS $function$
BEGIN
  UPDATE public.games
  SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
  WHERE id = p_game_id
    AND event_id IN (SELECT e.id FROM public.events e WHERE e.event_type = 'game' AND e.creator_user_id = auth.uid());
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  RETURN 'cancelled';
END$function$;

CREATE TEMP TABLE k913_case ON COMMIT DROP AS
WITH gs AS (SELECT g.id, e.creator_user_id FROM public.games g
              JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game' ORDER BY g.id LIMIT 40),
     adm AS (SELECT min(user_id::text)::uuid AS uid FROM public.role_grants WHERE role IN ('admin', 'super_admin'))
SELECT gs.id AS gid, 'creator' AS who, gs.creator_user_id AS uid FROM gs
UNION ALL SELECT gs.id, 'admin', (SELECT uid FROM adm) FROM gs
UNION ALL SELECT gs.id, 'member',
       (SELECT min(gr.user_id::text)::uuid FROM public.game_roster gr
         WHERE gr.game_id = gs.id AND gr.status = 'active' AND gr.user_id IS DISTINCT FROM gs.creator_user_id
           AND NOT public.is_admin(gr.user_id)) FROM gs
UNION ALL SELECT gs.id, 'stranger',
       (SELECT min(u.id::text)::uuid FROM auth.users u
         WHERE u.id IS DISTINCT FROM gs.creator_user_id AND NOT public.is_admin(u.id)
           AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.game_id = gs.id AND gr.user_id = u.id)) FROM gs
UNION ALL SELECT gs.id, 'anon', NULL::uuid FROM gs
UNION ALL SELECT '71300000-0000-0000-0000-0000000000ff'::uuid, 'missing', (SELECT creator_user_id FROM gs LIMIT 1);
DELETE FROM k913_case WHERE who = 'member' AND uid IS NULL;

DO $run$
DECLARE
  fn text; r record; r1 text; r2 text; acc jsonb;
BEGIN
  FOREACH fn IN ARRAY ARRAY['public.rpc_cancel_game_kan712_inner', 'pg_temp.k913_pre', 'pg_temp.k913_mutant'] LOOP
    acc := '{}'::jsonb;
    FOR r IN SELECT * FROM pg_temp.k913_case ORDER BY gid, who LOOP
      BEGIN
        PERFORM set_config('request.jwt.claim.sub', coalesce(r.uid::text, ''), true);
        PERFORM set_config('request.jwt.claims', '', true);
        PERFORM set_config('kan712.contract', 'on', true);
        BEGIN EXECUTE format('SELECT %s($1, $2)', fn) INTO r1 USING r.gid, 'k913-a';
        EXCEPTION WHEN OTHERS THEN r1 := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END;
        BEGIN EXECUTE format('SELECT %s($1, $2)', fn) INTO r2 USING r.gid, 'k913-b';
        EXCEPTION WHEN OTHERS THEN r2 := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END;
        acc := acc || jsonb_build_object(r.gid || '/' || r.who, jsonb_build_object(
          'r1', r1, 'r2', r2,
          'g', (SELECT to_jsonb(g) FROM public.games g WHERE g.id = r.gid),
          'e', (SELECT to_jsonb(e) FROM public.events e WHERE e.id = r.gid)));
        RAISE EXCEPTION 'k913_undo';
      EXCEPTION WHEN raise_exception THEN
        IF SQLERRM <> 'k913_undo' THEN RAISE; END IF;
      END;
    END LOOP;
    INSERT INTO pg_temp.k913_cap SELECT fn, j.key, j.value FROM jsonb_each(acc) j;
  END LOOP;
END
$run$;

WITH src AS (SELECT prosrc FROM pg_proc WHERE oid = 'public.rpc_cancel_game_kan712_inner(uuid,text)'::regprocedure)
INSERT INTO k913_tap SELECT 1,
  NOT (prosrc ~* '(\mg|\mgames)\.(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M'
       OR regexp_replace(replace(prosrc, 'SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason', ''), '--[^\n]*', '', 'g')
          ~* '(^|[^.a-z0-9_])(creator_profile_id|creator_user_id|title|start_at|end_at|capacity|listing_visibility|join_policy|is_cancelled|cancelled_at|cancelled_reason|sport_id|area_id|geo_location_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id|created_at|updated_at)\M'),
  'inner reads none of the 22 games columns', 'md5(prosrc) ' || md5(prosrc) FROM src;

WITH a AS (SELECT k, v FROM k913_cap WHERE fn = 'public.rpc_cancel_game_kan712_inner'),
     b AS (SELECT k, v FROM k913_cap WHERE fn = 'pg_temp.k913_pre'),
     d AS (SELECT k FROM a FULL JOIN b USING (k) WHERE a.v IS DISTINCT FROM b.v)
INSERT INTO k913_tap SELECT 2, count(*) = 0, 'live inner = pre-image twin on every scenario',
  count(*) || ' differing of ' || (SELECT count(*) FROM a) FROM d;

WITH a AS (SELECT k, v FROM k913_cap WHERE fn = 'pg_temp.k913_mutant'),
     b AS (SELECT k, v FROM k913_cap WHERE fn = 'pg_temp.k913_pre'),
     d AS (SELECT k FROM a FULL JOIN b USING (k) WHERE a.v IS DISTINCT FROM b.v)
INSERT INTO k913_tap SELECT 3, count(*) > 0, 'negative control: mutant differs from twin', count(*) || ' differing' FROM d;

INSERT INTO k913_tap SELECT 4,
  count(*) >= 150 AND bool_or(v->>'r1' = 'cancelled') AND bool_or(v->>'r1' LIKE 'ERR P0001%'),
  'capture not trivial',
  count(*) || ' scenarios; r1 cancelled=' || count(*) FILTER (WHERE v->>'r1' = 'cancelled')
  || ' err=' || count(*) FILTER (WHERE v->>'r1' LIKE 'ERR%')
  || '; r2 cancelled=' || count(*) FILTER (WHERE v->>'r2' = 'cancelled')
  FROM k913_cap WHERE fn = 'pg_temp.k913_pre';

INSERT INTO k913_tap SELECT 5,
  (SELECT p.proacl::text = '{postgres=X/postgres}' AND p.prosecdef AND p.proconfig = '{search_path=public}'
          AND p.proowner = 'postgres'::regrole
     FROM pg_proc p WHERE p.oid = 'public.rpc_cancel_game_kan712_inner(uuid,text)'::regprocedure)
  AND (SELECT p.proacl::text = '{postgres=X/postgres,=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
          AND p.prosecdef AND md5(pg_get_functiondef(p.oid)) = '8d12b2b734153a7b45759f027f012927'
     FROM pg_proc p WHERE p.oid = 'public.rpc_cancel_game(uuid,text)'::regprocedure),
  'inner and wrapper attributes / ACL unchanged', NULL;

SELECT CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', '') AS tap
  FROM k913_tap ORDER BY n;
ROLLBACK;
