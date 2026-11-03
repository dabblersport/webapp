-- KAN-801 (KAN-718 D04 blockers #23 rpc_meetup_rsvp, #24 rpc_meetup_set_attendee): both read their shared meetup
-- fields from public.events, so they keep working after KAN-719 Z01 removes the legacy meetups columns.
-- LOCAL THROWAWAY POSTGRES ONLY (database name k801*). NEVER RUN AGAINST SUPABASE.
--
-- Seams under test, called as `authenticated` with a JWT subject (auth.uid()), exactly as PostgREST calls them:
--   public.rpc_meetup_rsvp(p_meetup_id, p_action, p_profile_id => NULL, p_link_token)
--   public.rpc_meetup_set_attendee(p_meetup_id, p_target_actor, p_status)
-- Fixture (local chain): meetup M 71300000-..-0101 (open, public, future, creator a1), seeded meetup F 78100000-..-f001
-- (copy of M), users a1 (owner), a4 (not owner, not admin), a7 (no RSVP on M). Requires the k801 build
-- (clean801.sh: events chain + D04 + D05 + seed781 + harness801.sh pre-images).
--
-- Expected:
--   without 20261104110600_kan801 (pre-image), before or after Z01: A* FAIL with 42703 (m.owner_user_id does not
--     exist); after Z01 R* FAIL with 42703 as well.
--   with KAN-801, before Z01: every probe PASSes.
--   with KAN-801, after Z01: S*, A* PASS. R* are recorded honestly; see the KAN-801 report for their state.
-- One transaction, ROLLBACK at the end: nothing persists.
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
\set M  '''71300000-0000-0000-0000-000000000101'''
\set F  '''78100000-0000-0000-0000-00000000f001'''
\set a1 '''00000000-0000-0000-0000-0000000000a1'''
\set a4 '''00000000-0000-0000-0000-0000000000a4'''
\set a7 '''00000000-0000-0000-0000-0000000000a7'''
\set b7 '''00000000-0000-0000-0000-0000000000b7'''
\set TOK '''80100000-0000-0000-0000-0000000000aa'''

DO $g$ BEGIN
  IF current_database() NOT LIKE 'k801%' THEN
    RAISE EXCEPTION 'KAN-801 test: % is not a KAN-801 throwaway database; refusing', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-801 test: this looks like a Supabase database; refusing';
  END IF;
END $g$;

BEGIN;
CREATE TEMP TABLE k801_r (n serial, id text, ok boolean, expected text, actual text, name text);
GRANT ALL ON k801_r TO PUBLIC;
CREATE FUNCTION pg_temp.chk(p_id text, p_name text, p_expected text, p_actual text) RETURNS text
LANGUAGE sql AS $f$
  INSERT INTO k801_r(id, ok, expected, actual, name)
  VALUES (p_id, coalesce(p_actual, '<null>') = p_expected, p_expected, coalesce(p_actual, '<null>'), p_name)
  RETURNING 'KAN-801 ' || id || ' ' || CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END
            || ' expected=' || expected || ' actual=' || actual || ' | ' || name $f$;
-- One call as `authenticated`. Returns 'ret:<value>' or '<SQLSTATE>:<message>'.
CREATE FUNCTION pg_temp.rsvp(p_uid uuid, p_meetup uuid, p_action text, p_token uuid DEFAULT NULL) RETURNS text
LANGUAGE plpgsql AS $f$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    SET LOCAL ROLE authenticated;
    v := public.rpc_meetup_rsvp(p_meetup_id => p_meetup, p_action => p_action, p_profile_id => NULL, p_link_token => p_token);
    RESET ROLE;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    RETURN 'ret:' || coalesce(v, '<null>');
  EXCEPTION WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
  END;
END $f$;
CREATE FUNCTION pg_temp.setatt(p_uid uuid, p_meetup uuid, p_actor uuid, p_status text) RETURNS text
LANGUAGE plpgsql AS $f$
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    SET LOCAL ROLE authenticated;
    PERFORM public.rpc_meetup_set_attendee(p_meetup_id => p_meetup, p_target_actor => p_actor, p_status => p_status);
    RESET ROLE;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    RETURN 'ret:void';
  EXCEPTION WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
  END;
END $f$;
CREATE FUNCTION pg_temp.att(p_meetup uuid, p_actor uuid) RETURNS text LANGUAGE sql AS $f$
  SELECT coalesce((SELECT status || '|' || user_id FROM public.meetup_attendees
                    WHERE meetup_id = p_meetup AND actor_profile_id = p_actor), '<none>') $f$;

-- S: the bodies read no legacy meetups column; every meetups read joins its events parent.
SELECT pg_temp.chk('S1', 'neither body names meetups.rsvp_policy or the non-existent owner_user_id', 'false|false',
  (SELECT string_agg((prosrc ~ 'rsvp_policy|owner_user_id')::text, '|' ORDER BY proname) FROM pg_proc
    WHERE oid IN ('public.rpc_meetup_rsvp(uuid,text,uuid,uuid)'::regprocedure,
                  'public.rpc_meetup_set_attendee(uuid,uuid,text)'::regprocedure)));
SELECT pg_temp.chk('S2', 'each body: every "from public.meetups m" is joined to public.events on event_id + type', '1/1|1/1',
  (SELECT string_agg(
     (SELECT count(*) FROM regexp_matches(prosrc, 'from public\.meetups m join public\.events e on e\.id = m\.event_id and e\.event_type = ''meetup''', 'g'))::text
     || '/' || (SELECT count(*) FROM regexp_matches(prosrc, 'from public\.meetups', 'g'))::text, '|' ORDER BY proname)
     FROM pg_proc WHERE oid IN ('public.rpc_meetup_rsvp(uuid,text,uuid,uuid)'::regprocedure,
                                'public.rpc_meetup_set_attendee(uuid,uuid,text)'::regprocedure)));
SELECT pg_temp.chk('S3', 'grants: authenticated may EXECUTE both, anon neither', 'true|true|false|false',
  has_function_privilege('authenticated', 'public.rpc_meetup_rsvp(uuid,text,uuid,uuid)', 'EXECUTE')::text || '|'
  || has_function_privilege('authenticated', 'public.rpc_meetup_set_attendee(uuid,uuid,text)', 'EXECUTE')::text || '|'
  || has_function_privilege('anon', 'public.rpc_meetup_rsvp(uuid,text,uuid,uuid)', 'EXECUTE')::text || '|'
  || has_function_privilege('anon', 'public.rpc_meetup_set_attendee(uuid,uuid,text)', 'EXECUTE')::text);
SELECT pg_temp.chk('S4', 'fixture: M is open, public, future; its events creator is a1', 'open|public|true|' || :a1,
  (SELECT e.join_policy || '|' || e.listing_visibility || '|' || (e.start_at > now())::text || '|' || e.creator_user_id
     FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup' WHERE m.id = :M));

-- A: rpc_meetup_set_attendee -- owner gate now from events.creator_user_id; every refusal unchanged.
SELECT pg_temp.chk('A1', 'owner a1 sets b7 going', 'ret:void', pg_temp.setatt(:a1, :M, :b7, 'going'));
SELECT pg_temp.chk('A2', 'after A1: b7 attendee row going, user_id a7', 'going|' || :a7, pg_temp.att(:M, :b7));
SELECT pg_temp.chk('A3', 'owner a1 changes b7 to declined (upsert)', 'ret:void', pg_temp.setatt(:a1, :M, :b7, 'declined'));
SELECT pg_temp.chk('A4', 'after A3: b7 attendee row declined', 'declined|' || :a7, pg_temp.att(:M, :b7));
SELECT pg_temp.chk('A5', 'a4 (not owner, not admin) -> P0001 not_meetup_owner, row unchanged', 'P0001:not_meetup_owner|declined|' || :a7,
  pg_temp.setatt(:a4, :M, :b7, 'going') || '|' || pg_temp.att(:M, :b7));
SELECT pg_temp.chk('A6', 'unknown meetup -> P0001 meetup_not_found', 'P0001:meetup_not_found',
  pg_temp.setatt(:a1, '80100000-0000-0000-0000-0000000009ff', :b7, 'going'));
SELECT pg_temp.chk('A7', 'invalid status -> P0001 rsvp_status_invalid', 'P0001:rsvp_status_invalid',
  pg_temp.setatt(:a1, :M, :b7, 'maybe'));
SELECT pg_temp.chk('A8', 'no JWT subject -> P0001 not_authenticated', 'P0001:not_authenticated',
  pg_temp.setatt(NULL, :M, :b7, 'going'));

-- R: rpc_meetup_rsvp -- the link gate reads events.join_policy; KAN-786 leave behaviour unchanged.
SELECT pg_temp.chk('R1', 'a7 joins open M (gate sees join_policy open, no link consumption)', 'ret:going', pg_temp.rsvp(:a7, :M, 'going'));
SELECT pg_temp.chk('R2', 'a7 joining again -> P0001 already (unchanged)', 'P0001:already', pg_temp.rsvp(:a7, :M, 'going'));
SELECT pg_temp.chk('R3', 'a7 leaves (KAN-786) -> cancelled', 'ret:cancelled', pg_temp.rsvp(:a7, :M, 'cancel'));
SELECT pg_temp.chk('R4', 'a7 leaves again (KAN-786) -> P0001 not_attending', 'P0001:not_attending', pg_temp.rsvp(:a7, :M, 'cancel'));
-- Link policy on F, written to events (the write target; before Z01 the KAN-712 mirror carries it to meetups).
UPDATE public.events SET join_policy = 'link' WHERE id = (SELECT event_id FROM public.meetups WHERE id = :F);
INSERT INTO public.meetup_link_tokens (meetup_id, token, created_by, max_uses) VALUES (:F, :TOK, :a1, 5);
SELECT pg_temp.chk('R5', 'link meetup without a token -> P0001 link_required (unchanged)', 'P0001:link_required',
  pg_temp.rsvp(:a7, :F, 'going'));
SELECT pg_temp.chk('R6', 'link meetup with a valid token -> going', 'ret:going', pg_temp.rsvp(:a7, :F, 'going', :TOK));
SELECT pg_temp.chk('R7', 'the link gate (events.join_policy = link) consumed the token exactly once', '1',
  (SELECT used_count::text FROM public.meetup_link_tokens WHERE meetup_id = :F AND token = :TOK));

SELECT 'KAN-801 TOTAL pass=' || count(*) FILTER (WHERE ok) || ' fail=' || count(*) FILTER (WHERE NOT ok) FROM k801_r;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM k801_r WHERE NOT ok) THEN
    RAISE EXCEPTION 'KAN-801 test FAILED: %', (SELECT string_agg(id, ',' ORDER BY n) FROM k801_r WHERE NOT ok);
  END IF;
END $$;
ROLLBACK;
