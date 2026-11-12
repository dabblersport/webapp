-- KAN-917 live proof for supabase/migrations/20261111121900_kan714_w_rpc_edit_game_series_occurrence_kan712_inner.sql
-- (public.rpc_edit_game_series_occurrence_kan712_inner, 6 arguments). Runs on the hosted project as postgres inside
-- BEGIN ... ROLLBACK: every call's writes are undone in a subtransaction and the final ROLLBACK drops the fixture and
-- the twins. Nothing persists.
--
-- TWINS. pg_temp.k917_pre is built from the live pg_get_functiondef by undoing the KAN-917 edit (each replace is a no-op
-- on the pre-image, so the same text works before and after the apply); T0 proves it byte-exact (md5(prosrc)
-- 37c172cd...). pg_temp.k917_mutant is the twin without the owner check (AND e.creator_user_id = v_uid).
-- FIXTURE. Live has no game_series rows and no series games (2026-11-13), so each future, uncancelled game gets its own
-- game_series row (copied from its events parent) and games.series_id set, with kan712.contract on.
-- SCENARIOS. Every fixture game and one missing id; callers creator, a user with no relation, anon; parameter sets
-- N (all null: the title / capacity fallbacks), T (title + capacity 10), S (start moved 1 day, end derived),
-- X (capacity 1: invalid), P (start in the past: invalid). Captured per call: result or ERR sqlstate message, and the
-- games and events rows (updated_at dropped).
--   T0 twin = pre-image; mutant differs
--   T1 the live inner reads title / capacity from events (no bare games fallback)   RED before KAN-917, GREEN after
--   T2 live capture = twin capture on every scenario
--   T3 negative control: the mutant differs from the twin
--   T4 capture not trivial (a success, not_host_or_not_found, occurrence_capacity_invalid, occurrence_time_invalid)
--   T5 inner and wrapper attributes / ACL unchanged
BEGIN;
CREATE TEMP TABLE k917_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k917_cap (fn text, k text, v jsonb) ON COMMIT DROP;

DO $mk$
DECLARE d text := pg_get_functiondef('public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)'::regprocedure);
BEGIN
  d := replace(d, 'public.rpc_edit_game_series_occurrence_kan712_inner(', 'pg_temp.k917_pre(');
  d := replace(d, E'    -- KAN-917: the title / capacity fallbacks read the events parent e (authoritative); SET targets unchanged.\n', '');
  d := replace(d, E'UPDATE public.games g1\n', E'UPDATE public.games\n');
  d := replace(d, 'COALESCE(p_title, e.title)', 'COALESCE(p_title, title)');
  d := replace(d, 'COALESCE(p_capacity, e.capacity)', 'COALESCE(p_capacity, capacity)');
  d := replace(d, E'      FROM public.events e\n     WHERE e.id = g1.event_id AND e.event_type = ''game''\n       AND g1.id = g.id;',
                  E'     WHERE id = g.id;');
  EXECUTE d;
  EXECUTE replace(replace(d, 'pg_temp.k917_pre(', 'pg_temp.k917_mutant('), ' AND e.creator_user_id = v_uid', '');
END
$mk$;

SELECT set_config('kan712.contract', 'on', true);
CREATE TEMP TABLE k917_fx ON COMMIT DROP AS
SELECT g.id AS gid, gen_random_uuid() AS sid, e.* FROM public.games g
  JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
 WHERE e.start_at > now() + interval '1 hour' AND NOT e.is_cancelled;
INSERT INTO public.game_series (id, creator_user_id, creator_profile_id, sport_id, venue_id, geo_location_id, area_id, title,
       capacity, listing_visibility, join_policy, start_time_local, duration_minutes, rrule, timezone, starts_on, status)
SELECT f.sid, f.creator_user_id, f.creator_profile_id, f.sport_id, f.venue_id, f.geo_location_id, f.area_id, f.title,
       f.capacity, f.listing_visibility, f.join_policy, (f.start_at AT TIME ZONE 'Asia/Dubai')::time,
       greatest(15, (extract(epoch FROM f.end_at - f.start_at) / 60)::int), 'FREQ=WEEKLY', 'Asia/Dubai',
       (f.start_at AT TIME ZONE 'Asia/Dubai')::date, 'paused'
  FROM k917_fx f;
UPDATE public.games g SET series_id = f.sid FROM k917_fx f WHERE g.id = f.gid;

CREATE TEMP TABLE k917_case ON COMMIT DROP AS
SELECT f.gid, 'creator' AS who, f.creator_user_id AS uid FROM k917_fx f
UNION ALL SELECT f.gid, 'stranger', (SELECT min(u.id::text)::uuid FROM auth.users u WHERE u.id IS DISTINCT FROM f.creator_user_id
       AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.game_id = f.gid AND gr.user_id = u.id)) FROM k917_fx f
UNION ALL SELECT f.gid, 'anon', NULL::uuid FROM k917_fx f
UNION ALL SELECT '71200000-0000-0000-0000-0000000000ff'::uuid, 'missing', (SELECT creator_user_id FROM k917_fx LIMIT 1);

CREATE TEMP TABLE k917_param ON COMMIT DROP AS SELECT * FROM (VALUES
  ('N', NULL::text, NULL::interval, NULL::int),
  ('T', 'k917 title', NULL, 10),
  ('S', NULL, interval '1 day', NULL),
  ('X', NULL, NULL, 1),
  ('P', NULL, interval '-30 days', NULL)
) v(pk, title, shift, cap);

DO $run$
DECLARE fn text; r record; p record; r1 text; acc jsonb; v_s timestamptz;
BEGIN
  FOREACH fn IN ARRAY ARRAY['public.rpc_edit_game_series_occurrence_kan712_inner', 'pg_temp.k917_pre', 'pg_temp.k917_mutant'] LOOP
    acc := '{}';
    FOR r IN SELECT * FROM pg_temp.k917_case LOOP
      FOR p IN SELECT * FROM pg_temp.k917_param LOOP
        BEGIN
          PERFORM set_config('request.jwt.claim.sub', coalesce(r.uid::text, ''), true);
          PERFORM set_config('request.jwt.claims', '', true);
          PERFORM set_config('kan712.contract', 'on', true);
          SELECT f.start_at + p.shift INTO v_s FROM pg_temp.k917_fx f WHERE f.gid = r.gid;
          BEGIN
            EXECUTE format('SELECT %s($1,$2,$3,$4,$5,$6)::text', fn) INTO r1
              USING r.gid, p.title, v_s, NULL::timestamptz, p.cap, NULL::uuid;
          EXCEPTION WHEN OTHERS THEN r1 := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END;
          acc := acc || jsonb_build_object(r.gid || '/' || r.who || '/' || p.pk, jsonb_build_object('r', r1,
            'g', (SELECT to_jsonb(g) - 'updated_at' FROM public.games g WHERE g.id = r.gid),
            'e', (SELECT to_jsonb(e) - 'updated_at' FROM public.events e JOIN public.games g ON g.event_id = e.id WHERE g.id = r.gid)));
          RAISE EXCEPTION 'k917_undo';
        EXCEPTION WHEN raise_exception THEN
          IF SQLERRM <> 'k917_undo' THEN RAISE; END IF;
        END;
      END LOOP;
    END LOOP;
    INSERT INTO pg_temp.k917_cap SELECT fn, j.key, j.value FROM jsonb_each(acc) j;
  END LOOP;
END
$run$;

INSERT INTO k917_tap SELECT 0, md5(p.prosrc) = '37c172cd1396ae272c4dd0555e883cf9' AND p.prosrc <> m.prosrc,
  'twin = pre-image; mutant differs', 'twin md5(prosrc) ' || md5(p.prosrc)
  FROM pg_proc p, pg_proc m WHERE p.proname = 'k917_pre' AND m.proname = 'k917_mutant'
   AND p.pronamespace = pg_my_temp_schema() AND m.pronamespace = pg_my_temp_schema();

INSERT INTO k917_tap SELECT 1,
  prosrc LIKE '%COALESCE(p_title, e.title)%' AND prosrc LIKE '%COALESCE(p_capacity, e.capacity)%'
  AND prosrc NOT LIKE '%COALESCE(p_title, title)%' AND prosrc NOT LIKE '%COALESCE(p_capacity, capacity)%',
  'inner reads title / capacity from events', 'md5(prosrc) ' || md5(prosrc)
  FROM pg_proc WHERE oid = 'public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)'::regprocedure;

WITH a AS (SELECT k, v FROM k917_cap WHERE fn = 'public.rpc_edit_game_series_occurrence_kan712_inner'),
     b AS (SELECT k, v FROM k917_cap WHERE fn = 'pg_temp.k917_pre')
INSERT INTO k917_tap SELECT 2, count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) = 0 AND count(*) > 0,
  'live inner = pre-image twin on every scenario',
  count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) || ' differing of ' || count(*) FROM a FULL JOIN b USING (k);

WITH a AS (SELECT k, v FROM k917_cap WHERE fn = 'pg_temp.k917_mutant'),
     b AS (SELECT k, v FROM k917_cap WHERE fn = 'pg_temp.k917_pre')
INSERT INTO k917_tap SELECT 3, count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) > 0,
  'negative control: mutant differs from twin', count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) || ' differing'
  FROM a FULL JOIN b USING (k);

INSERT INTO k917_tap SELECT 4,
  count(*) >= 50 AND bool_or(v->>'r' LIKE '{%') AND bool_or(v->>'r' LIKE '%not_host_or_not_found%')
  AND bool_or(v->>'r' LIKE '%occurrence_capacity_invalid%') AND bool_or(v->>'r' LIKE '%occurrence_time_invalid%'),
  'capture not trivial',
  count(*) || ' scenarios; ok=' || count(*) FILTER (WHERE v->>'r' LIKE '{%')
  || ' not_found=' || count(*) FILTER (WHERE v->>'r' LIKE '%not_host_or_not_found%')
  || ' not_auth=' || count(*) FILTER (WHERE v->>'r' LIKE '%not_authenticated%')
  || ' cap_invalid=' || count(*) FILTER (WHERE v->>'r' LIKE '%occurrence_capacity_invalid%')
  || ' time_invalid=' || count(*) FILTER (WHERE v->>'r' LIKE '%occurrence_time_invalid%')
  || ' other_err=' || count(*) FILTER (WHERE v->>'r' LIKE 'ERR%' AND v->>'r' !~ '(not_host_or_not_found|not_authenticated|occurrence_capacity_invalid|occurrence_time_invalid)')
  FROM k917_cap WHERE fn = 'pg_temp.k917_pre';

INSERT INTO k917_tap SELECT 5,
  (SELECT p.proacl::text = '{postgres=X/postgres}' AND p.prosecdef AND p.proconfig = '{"search_path=public, pg_temp"}'
          AND p.proowner = 'postgres'::regrole
     FROM pg_proc p WHERE p.oid = 'public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamptz,timestamptz,integer,uuid)'::regprocedure)
  AND (SELECT p.proacl::text = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
          AND md5(pg_get_functiondef(p.oid)) = 'be3938f0b159dc143078453459882869'
     FROM pg_proc p WHERE p.oid = 'public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid)'::regprocedure),
  'inner and wrapper attributes / ACL unchanged', NULL;

SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', ''), E'\n' ORDER BY n) AS tap
  FROM k917_tap;
ROLLBACK;
