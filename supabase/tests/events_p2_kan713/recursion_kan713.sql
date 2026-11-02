-- KAN-713 RLS RECURSION PROBE. LOCAL THROWAWAY POSTGRES ONLY. Run as postgres. One transaction, ROLLBACK.
--
-- R0 (control, must FAIL-DETECT): a deliberately mutually-recursive policy pair is planted inside a
--    subtransaction; the detector must report 42P17. A detector nobody has seen fire is not evidence.
-- R1 dynamic: every policy-bearing read and the attendee write, as anon, every authenticated actor and
--    service_role, on every fixture event: no 42P17 (infinite recursion in policy), no 54001 (stack depth).
-- R2 static: the four kan713_meetup_* helpers read public.events and no policy-bearing table; the
--    functions they call (can_view_owner, can_read_row, can_write_row, are_synced) never name meetups or
--    meetup_attendees; the helpers run as an owner that bypasses RLS (so their events read evaluates no policy).
-- Output lines PASS|id|... / FAIL|id|...; last line #SUMMARY|pass=n|fail=n.
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
BEGIN;
SET LOCAL search_path = public, pg_catalog;
CREATE TEMP TABLE res (n serial, id text, got text, want text);

CREATE FUNCTION pg_temp.try(p_role text, p_uid text, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; s text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE;
    RESET ROLE;
    IF NOT (s = 'P0001' AND SQLERRM = 'kan713_undo') THEN v := 'ERR ' || s; END IF;
  END;
  RETURN coalesce(v, 'ok');
END $$;

-- R0 control: plant recursion (meetups policy reads meetup_attendees, whose policies read meetups).
DO $$ DECLARE r text; BEGIN
  BEGIN
    CREATE POLICY kan713_probe_recursive ON public.meetups FOR SELECT TO anon
      USING (EXISTS (SELECT 1 FROM public.meetup_attendees a WHERE a.meetup_id = meetups.id));
    CREATE POLICY kan713_probe_recursive_a ON public.meetup_attendees FOR SELECT TO anon
      USING (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id));
    r := pg_temp.try('anon', NULL, 'SELECT count(*)::text FROM public.meetups');
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'kan713_undo';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'kan713_undo' THEN r := 'ERR ' || SQLSTATE; END IF; END;
  INSERT INTO res (id, got, want) VALUES ('R0 control: planted recursive policy pair is detected', r, 'ERR 42P17');
END $$;

-- R1 dynamic sweep.
CREATE TEMP TABLE actors (role text, uid text);
INSERT INTO actors VALUES ('anon', NULL), ('service_role', NULL),
  ('authenticated', '00000000-0000-0000-0000-0000000000a1'), ('authenticated', '00000000-0000-0000-0000-0000000000a2'),
  ('authenticated', '00000000-0000-0000-0000-0000000000a3'), ('authenticated', '00000000-0000-0000-0000-0000000000a4'),
  ('authenticated', '00000000-0000-0000-0000-0000000000a5'), ('authenticated', '00000000-0000-0000-0000-0000000000a6'),
  ('authenticated', '00000000-0000-0000-0000-0000000000a7'), ('authenticated', '00000000-0000-0000-0000-0000000000a9');
CREATE TEMP TABLE stmts (sql text);
INSERT INTO stmts VALUES
  ('SELECT count(*)::text FROM public.meetups'),
  ('SELECT count(*)::text FROM public.meetup_attendees'),
  ('SELECT count(*)::text FROM public.meetup_attendees a JOIN public.meetups m ON m.id = a.meetup_id'),
  ('WITH u AS (UPDATE public.meetup_attendees SET status = status RETURNING 1) SELECT count(*)::text FROM u'),
  ('SELECT count(*)::text FROM public.game_roster'),
  ('SELECT count(*)::text FROM public.game_waitlist'),
  ('SELECT count(*)::text FROM public.game_join_requests'),
  ('SELECT count(*)::text FROM public.games');
CREATE TEMP TABLE sweep AS
  SELECT a.role, a.uid, s.sql, pg_temp.try(a.role, a.uid, s.sql) AS v FROM actors a CROSS JOIN stmts s;
INSERT INTO res (id, got, want)
  SELECT 'R1 sweep: ' || (SELECT count(*) FROM sweep) || ' actor x statement cells, recursion/stack errors',
         (SELECT count(*) FROM sweep WHERE v IN ('ERR 42P17', 'ERR 54001'))::text, '0';
INSERT INTO res (id, got, want)
  SELECT 'R1 sweep: every error cell (only a no-grant 42501 is acceptable)',
         coalesce((SELECT string_agg(role || ':' || left(sql, 40) || ':' || v, ';') FROM sweep WHERE v LIKE 'ERR %'), '<none>'),
         'anon:WITH u AS (UPDATE public.meetup_attendee:ERR 42501';

-- R2 static.
INSERT INTO res (id, got, want)
  SELECT 'R2 helpers: name public.events, name no other public table',
         string_agg(p.proname || ':' ||
           (p.prosrc LIKE '%public.events %')::text || ':' ||
           (p.prosrc ~ 'public\.(meetups|meetup_attendees|games|game_roster|game_waitlist|game_join_requests)\M')::text, ',' ORDER BY p.proname),
         'kan713_meetup_attendee_visible:true:false,kan713_meetup_can_read_row:true:false,kan713_meetup_can_write_row:true:false,kan713_meetup_visible:true:false'
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname IN ('kan713_meetup_visible', 'kan713_meetup_can_read_row', 'kan713_meetup_attendee_visible', 'kan713_meetup_can_write_row');
INSERT INTO res (id, got, want)
  SELECT 'R2 callees never read meetups / meetup_attendees',
         string_agg(p.proname || ':' || (p.prosrc ~ '\m(meetups|meetup_attendees)\M')::text, ',' ORDER BY p.proname),
         'are_synced:false,can_read_row:false,can_view_owner:false,can_write_row:false'
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname IN ('can_view_owner', 'can_read_row', 'can_write_row', 'are_synced');
INSERT INTO res (id, got, want)
  SELECT 'R2 helpers: SECURITY DEFINER, owner bypasses RLS',
         string_agg(p.proname || ':' || p.prosecdef::text || ':' || (r.rolsuper OR r.rolbypassrls)::text, ',' ORDER BY p.proname),
         'kan713_meetup_attendee_visible:true:true,kan713_meetup_can_read_row:true:true,kan713_meetup_can_write_row:true:true,kan713_meetup_visible:true:true'
    FROM pg_proc p JOIN pg_roles r ON r.oid = p.proowner
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname IN ('kan713_meetup_visible', 'kan713_meetup_can_read_row', 'kan713_meetup_attendee_visible', 'kan713_meetup_can_write_row');

SELECT CASE WHEN got IS NOT DISTINCT FROM want THEN 'PASS|' || id || '|' || coalesce(got, '<null>')
            ELSE 'FAIL|' || id || '|observed=' || coalesce(got, '<null>') || ' want=' || want END FROM res ORDER BY n;
SELECT '#SUMMARY|pass=' || count(*) FILTER (WHERE got IS NOT DISTINCT FROM want) || '|fail=' || count(*) FILTER (WHERE got IS DISTINCT FROM want) FROM res;
ROLLBACK;
