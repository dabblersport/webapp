-- KAN-786 (Events P3, KAN-717 D1): a joined member can leave a meetup exactly once.
-- LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
--
-- Seam under test: public.rpc_meetup_rsvp(p_meetup_id, p_action, p_profile_id, p_link_token), called as the
-- `authenticated` role with a JWT subject, with exactly the params the app sends
-- (lib/features/meetups/data/datasources/meetup_datasource.dart MeetupRpcParams.rsvp: p_meetup_id, p_action,
-- p_profile_id=null; RsvpAction.cancel.rpcValue = 'cancel').
--
-- Chosen second-leave behaviour (also stated in the migration header): a leave by a caller who holds no
-- active RSVP (going / interested / pending) raises SQLSTATE P0001 with message 'not_attending' -- the
-- same SQLSTATE every other rpc_meetup_rsvp refusal uses (PostgREST -> HTTP 400), a distinct message,
-- never 'already', no row change, no second 'meetup.rsvp_cancelled' event.
--
-- Expected: on 43cbc365 (no KAN-786 migration) L3 FAILs with P0001:already (the defect) and the file exits 3.
--           With 20261104110500_kan786_meetup_leave.sql every probe PASSes and the last line is
--           'KAN-786 TOTAL pass=N fail=0'. One transaction, ROLLBACK at the end: nothing persists.
-- Requires: the local events chain (as clean785.sh) plus the rpc_meetup_rsvp pre-image harness
-- (clean786.sh installs it verbatim from 20260912190747_kan180 + 20260915120000:740-741 grants).
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
\set M  '''71300000-0000-0000-0000-000000000101'''
\set a3 '''00000000-0000-0000-0000-0000000000a3'''
\set a4 '''00000000-0000-0000-0000-0000000000a4'''

BEGIN;
CREATE TEMP TABLE k786_r (n serial, id text, ok boolean, expected text, actual text, name text);
GRANT ALL ON k786_r TO PUBLIC;
CREATE FUNCTION pg_temp.chk(p_id text, p_name text, p_expected text, p_actual text) RETURNS text
LANGUAGE sql AS $f$
  INSERT INTO k786_r(id, ok, expected, actual, name)
  VALUES (p_id, coalesce(p_actual, '<null>') = p_expected, p_expected, coalesce(p_actual, '<null>'), p_name)
  RETURNING 'KAN-786 ' || id || ' ' || CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END
            || ' expected=' || expected || ' actual=' || actual || ' | ' || name $f$;
-- rsvp(uid, meetup, action): one call as `authenticated` with the app's params.
-- Returns 'ret:<value>' or '<SQLSTATE>:<message>'.
CREATE FUNCTION pg_temp.rsvp(p_uid uuid, p_meetup uuid, p_action text) RETURNS text
LANGUAGE plpgsql AS $f$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    SET LOCAL ROLE authenticated;
    v := public.rpc_meetup_rsvp(p_meetup_id => p_meetup, p_action => p_action, p_profile_id => NULL);
    RESET ROLE;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    RETURN 'ret:' || coalesce(v, '<null>');
  EXCEPTION WHEN OTHERS THEN
    RETURN SQLSTATE || ':' || SQLERRM;
  END;
END $f$;
CREATE FUNCTION pg_temp.state(p_uid uuid, p_meetup uuid) RETURNS text LANGUAGE sql AS $f$
  SELECT (SELECT going FROM public.meetup_counts(p_meetup)) || '|'
      || coalesce((SELECT status FROM public.meetup_rsvps WHERE meetup_id = p_meetup AND user_id = p_uid), '<none>') || '|'
      || (SELECT count(*) FROM public.event_outbox WHERE entity_id = p_meetup AND event_key = 'meetup.rsvp_cancelled') $f$;

-- Fixture sanity: an open, public, future meetup, a3 holds no RSVP, nobody going, no prior cancel event.
SELECT pg_temp.chk('L0', 'fixture: open/public/future meetup; a3 no RSVP; 0 going; 0 cancel events',
  'open|public|true|0|<none>|0',
  (SELECT m.rsvp_policy || '|' || m.listing_visibility || '|' || (m.start_at > now())::text
     FROM public.meetups m WHERE m.id = :M) || '|' || pg_temp.state(:a3, :M));
SELECT pg_temp.chk('L0b', 'grant path: authenticated may EXECUTE, anon may not',
  'true|false', has_function_privilege('authenticated', 'public.rpc_meetup_rsvp(uuid,text,uuid,uuid)', 'EXECUTE')::text
  || '|' || has_function_privilege('anon', 'public.rpc_meetup_rsvp(uuid,text,uuid,uuid)', 'EXECUTE')::text);

-- Join through the legit path.
SELECT pg_temp.chk('L1', 'a3 joins (going)', 'ret:going', pg_temp.rsvp(:a3, :M, 'going'));
SELECT pg_temp.chk('L2', 'after join: 1 going, a3 row going, 0 cancel events', '1|going|0', pg_temp.state(:a3, :M));
SELECT pg_temp.chk('L2b', 'a joined member asking to join again is still refused P0001 already (unchanged)',
  'P0001:already', pg_temp.rsvp(:a3, :M, 'going'));

-- C2: the leave succeeds.
SELECT pg_temp.chk('L3', 'a3 leaves (cancel) -> cancelled (defect on 43cbc365: P0001 already)', 'ret:cancelled',
  pg_temp.rsvp(:a3, :M, 'cancel'));
SELECT pg_temp.chk('L4', 'after leave: 0 going (decremented), a3 row cancelled, exactly 1 cancel event', '0|cancelled|1',
  pg_temp.state(:a3, :M));

-- C3: the second leave is a clear, distinct refusal that changes nothing.
SELECT pg_temp.chk('L5', 'a3 leaves again -> P0001 not_attending (never already)', 'P0001:not_attending',
  pg_temp.rsvp(:a3, :M, 'cancel'));
SELECT pg_temp.chk('L6', 'after second leave: unchanged, still exactly 1 cancel event', '0|cancelled|1', pg_temp.state(:a3, :M));
SELECT pg_temp.chk('L7', 'a4 (interested, not going) leaves -> cancelled: every active status can leave',
  'ret:cancelled', pg_temp.rsvp(:a4, :M, 'cancel'));
SELECT pg_temp.chk('L8', 'rejoin after leaving works (going)', 'ret:going', pg_temp.rsvp(:a3, :M, 'going'));
SELECT pg_temp.chk('L9', 'no JWT subject -> P0001 auth_required (unchanged)', 'P0001:auth_required',
  (SELECT pg_temp.rsvp(NULL, :M, 'cancel')));

-- Waitlist: capacity 1 (a normal events write, mirrored to meetups). a3 holds the one slot; a7 is waitlisted
-- (interested); a3 leaves and the slot frees; a7 can then go.
UPDATE public.events SET capacity = 1 WHERE id = (SELECT event_id FROM public.meetups WHERE id = :M);
SELECT pg_temp.chk('W1', 'capacity 1, a3 going: 0 slots left', '0', public.meetup_slots_left(:M)::text);
SELECT pg_temp.chk('W2', 'meetup full: a7 going -> waitlisted as interested (unchanged)', 'ret:interested',
  pg_temp.rsvp('00000000-0000-0000-0000-0000000000a7', :M, 'going'));
SELECT pg_temp.chk('W3', 'a3 leaves the full meetup -> cancelled', 'ret:cancelled', pg_temp.rsvp(:a3, :M, 'cancel'));
SELECT pg_temp.chk('W3b', 'after a3 left: 1 slot left (separate statement: a STABLE read sees its own statement snapshot)', '1',
  public.meetup_slots_left(:M)::text);
SELECT pg_temp.chk('W4', 'waitlisted a7 leaves the waitlist -> cancelled', 'ret:cancelled',
  pg_temp.rsvp('00000000-0000-0000-0000-0000000000a7', :M, 'cancel'));
SELECT pg_temp.chk('W5', 'a7 rejoins into the freed slot -> going', 'ret:going',
  pg_temp.rsvp('00000000-0000-0000-0000-0000000000a7', :M, 'going'));

SELECT 'KAN-786 TOTAL pass=' || count(*) FILTER (WHERE ok) || ' fail=' || count(*) FILTER (WHERE NOT ok) FROM k786_r;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM k786_r WHERE NOT ok) THEN
    RAISE EXCEPTION 'KAN-786 test FAILED: %', (SELECT string_agg(id, ',' ORDER BY n) FROM k786_r WHERE NOT ok);
  END IF;
END $$;
ROLLBACK;
