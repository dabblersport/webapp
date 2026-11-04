-- KAN-800 (supporting KAN-772 / KAN-719; meetup twin of KAN-799): proof for
-- 20261104110700_kan800_d04_blockers_meetup_requests.sql.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
-- It COMMITS a fixture and seed rows into the throwaway database; every call under test runs inside a
-- subtransaction that is rolled back, so each phase starts from the same state.
--
-- The local chain has neither function (KAN718_D04_DISPOSITION.md rows 19/22). F installs the pre-images VERBATIM
-- (cut from 20260915120000_meetups_hardening.sql by sed, with their REVOKE/GRANT lines from the same file).
-- Their callees (auth.uid, is_admin, meetup_slots_left (KAN-714 B08), emit_event, the meetup_rsvps notify trigger)
-- are the chain's.
--
--   T0  the fixture pre-images md5(prosrc) equal the migration's pins (and KAN-714 part 2's independent pins)
--   T1  phase pre      : pre-image, legacy columns present            -> the reference results
--   T2  phase pre_z01  : pre-image, Z01 dry run (rolled back)          -> RED: the 10 cases that read a field of
--                                                                        the meetup fail 42703
--   T3  migration applied (its own BEGIN/COMMIT, pre/post-conditions)
--   T4  phase post     : new body, legacy columns present             -> identical to pre
--   T5  phase post_z01 : new body, Z01 dry run (rolled back)          -> identical to pre, no 42703
--   T6  C4: signature, result type, SECURITY, search_path, owner, ACL identical before vs after
--   T7  C3: in the new bodies, every meetups-table alias reads only id / event_id; no %rowtype of meetups remains
--
-- Z01 dry run: every statement of 20261105100000_kan719_z01_remove_replaced_columns.sql (`...;  -- <seq>` lines,
-- extracted as kan799 / kan719_z01_removal_test.sql do), each in its own savepoint, in file order; statements the
-- harness cannot run are skipped and listed. The test requires that meetups.creator_user_id and
-- meetups.is_cancelled (the two columns the pre-images read) are gone, and reports how many of the 24 went.
--
-- Cases (same inputs every phase):
--   decide_approve (host approves a pending request), decide_decline, decide_admin_approve (admin, not host),
--   decide_not_host, decide_cancelled (meetup_cancelled), decide_unknown (meetup_not_found),
--   decide_no_pending, decide_invalid (invalid_decision, before the meetup read),
--   remove_happy (host removes a going attendee), remove_not_host, remove_host (cannot_remove_host),
--   remove_not_attendee (attendee_not_found), remove_unknown (meetup_not_found).
--
-- Run (repository root) on a fresh cluster built by supabase/tests/events_p2/build_kan788.sh:
--   psql -X -h /tmp -p <port> -U postgres -d k788 -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan800_d04_meetup_requests_test.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-800: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k788|k800)' THEN
    RAISE EXCEPTION 'KAN-800: database % is not a throwaway k788/k800 database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-800: run as a superuser'; END IF;
  IF to_regprocedure('public.rpc_meetup_decide_request(uuid,uuid,text)') IS NOT NULL
     OR to_regprocedure('public.rpc_meetup_remove_attendee(uuid,uuid)') IS NOT NULL
     OR to_regclass('public.k800_res') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-800: functions or results already present; use a fresh DB';
  END IF;
END $g$;

-- ---------------------------------------------------------------------------------------------------------
-- F. Fixture: VERBATIM pre-images from 20260915120000_meetups_hardening.sql, with their grants.
-- ---------------------------------------------------------------------------------------------------------
\set fx `H=supabase/migrations/20260915120000_meetups_hardening.sql; for f in rpc_meetup_decide_request rpc_meetup_remove_attendee; do awk -v f="$f" 'index($0, "CREATE OR REPLACE FUNCTION public." f "(") == 1 {on=1} on {print} on && $0 == "$function$;" {on=0}' $H; grep -E "^(REVOKE|GRANT) [A-Z ]+ ON FUNCTION public.$f\(" $H; done`
:fx

-- T0
DO $t0$
DECLARE x text; n int;
BEGIN
  SELECT count(*), string_agg(f || '=' || md5(p.prosrc), ', ') FILTER (WHERE md5(p.prosrc) <> t.want) INTO n, x
    FROM (VALUES ('public.rpc_meetup_decide_request(uuid,uuid,text)', 'd8c60f06cbc35e6b1e579a266863ba14'),
                 ('public.rpc_meetup_remove_attendee(uuid,uuid)', '7fec2761af25e3e0fd414922b7d07e6d')) t(f, want)
    JOIN pg_proc p ON p.oid = to_regprocedure(t.f);
  IF n <> 2 OR x IS NOT NULL THEN RAISE EXCEPTION 'KAN-800 T0 FAIL: fixture pre-image missing or differs from the pin: %', x; END IF;
  RAISE NOTICE 'KAN-800 T0 PASS: fixture pre-images match the migration pins d8c60f06.. / 7fec2761..';
END $t0$;

-- ---------------------------------------------------------------------------------------------------------
-- Seed (committed, throwaway DB). M1: first open harness meetup with a host that is not a harness admin;
-- M2: first cancelled meetup. Test users T (pending on M1 and M2), W (going on M1), N (nothing).
-- ---------------------------------------------------------------------------------------------------------
CREATE TABLE public.k800_ids AS
SELECT (SELECT m.id FROM public.meetups m WHERE NOT m.is_cancelled
          AND NOT EXISTS (SELECT 1 FROM public.harness_admins a WHERE a.admin_uid = m.creator_user_id) ORDER BY m.id LIMIT 1) AS m1,
       (SELECT m.id FROM public.meetups m WHERE m.is_cancelled ORDER BY m.id LIMIT 1) AS m2,
       (SELECT admin_uid FROM public.harness_admins ORDER BY 1 LIMIT 1) AS adm,
       '00000000-0000-0000-0000-0000000080a1'::uuid AS u_t,
       '00000000-0000-0000-0000-0000000080a2'::uuid AS u_w,
       '00000000-0000-0000-0000-0000000080a3'::uuid AS u_n;
ALTER TABLE public.k800_ids ADD COLUMN host1 uuid, ADD COLUMN host2 uuid;
UPDATE public.k800_ids SET host1 = (SELECT creator_user_id FROM public.meetups WHERE id = m1),
                           host2 = (SELECT creator_user_id FROM public.meetups WHERE id = m2);
INSERT INTO public.meetup_rsvps (meetup_id, user_id, status)
SELECT m1, u_t, 'pending' FROM public.k800_ids
UNION ALL SELECT m1, u_w, 'going' FROM public.k800_ids
UNION ALL SELECT m2, u_t, 'pending' FROM public.k800_ids;
SELECT 'seed' AS k, m1, m2, host1, host2, adm, public.meetup_slots_left(m1) AS m1_slots_left FROM public.k800_ids;

-- Z01 statements, file order.
\set z01text `cat supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql`
CREATE TABLE public.k800_z01 AS
  SELECT ord, x[1] AS stmt, x[2]::int AS seq
    FROM (SELECT :'z01text'::text AS src) s, regexp_matches(src, '\n((?:ALTER|DROP) [^\n]*?);  -- (\d+)', 'g') WITH ORDINALITY AS r(x, ord);
SELECT 'z01 statements' AS k, count(*) AS n, count(*) FILTER (WHERE seq BETWEEN 701 AND 724) AS meetups_drop_columns FROM public.k800_z01;
\echo '== Z01 meetups column list (seq 701-724)'
SELECT seq, substring(stmt FROM 'DROP COLUMN ([a-z_]+)') AS meetups_column FROM public.k800_z01 WHERE seq BETWEEN 701 AND 724 ORDER BY seq;

CREATE TABLE public.k800_res (phase text, case_name text, outcome jsonb, PRIMARY KEY (phase, case_name));

-- One case, as the given user. Returns the result or error plus the state it leaves (caller rolls back).
CREATE FUNCTION public.k800_case(p_case text) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE i public.k800_ids; res text; st jsonb; err jsonb := NULL;
BEGIN
  SELECT * INTO i FROM public.k800_ids;
  PERFORM set_config('request.jwt.claim.sub',
    (CASE p_case WHEN 'decide_admin_approve' THEN i.adm WHEN 'decide_not_host' THEN i.u_n
                 WHEN 'decide_cancelled' THEN i.host2 WHEN 'remove_not_host' THEN i.u_n
                 ELSE i.host1 END)::text, true);
  BEGIN
    res := CASE p_case
      WHEN 'decide_approve'       THEN public.rpc_meetup_decide_request(i.m1, i.u_t, 'approve')
      WHEN 'decide_decline'       THEN public.rpc_meetup_decide_request(i.m1, i.u_t, 'decline')
      WHEN 'decide_admin_approve' THEN public.rpc_meetup_decide_request(i.m1, i.u_t, 'approve')
      WHEN 'decide_not_host'      THEN public.rpc_meetup_decide_request(i.m1, i.u_t, 'approve')
      WHEN 'decide_cancelled'     THEN public.rpc_meetup_decide_request(i.m2, i.u_t, 'approve')
      WHEN 'decide_unknown'       THEN public.rpc_meetup_decide_request('00000000-0000-0000-0000-00000000dead', i.u_t, 'approve')
      WHEN 'decide_no_pending'    THEN public.rpc_meetup_decide_request(i.m1, i.u_w, 'approve')
      WHEN 'decide_invalid'       THEN public.rpc_meetup_decide_request(i.m1, i.u_t, 'maybe')
      WHEN 'remove_happy'         THEN public.rpc_meetup_remove_attendee(i.m1, i.u_w)
      WHEN 'remove_not_host'      THEN public.rpc_meetup_remove_attendee(i.m1, i.u_w)
      WHEN 'remove_host'          THEN public.rpc_meetup_remove_attendee(i.m1, i.host1)
      WHEN 'remove_not_attendee'  THEN public.rpc_meetup_remove_attendee(i.m1, i.u_n)
      WHEN 'remove_unknown'       THEN public.rpc_meetup_remove_attendee('00000000-0000-0000-0000-00000000dead', i.u_w)
    END;
  EXCEPTION WHEN OTHERS THEN
    err := jsonb_build_object('sqlstate', SQLSTATE, 'message', SQLERRM);
  END;
  SELECT jsonb_build_object(
    'rsvps',  (SELECT jsonb_agg(jsonb_build_array(r.meetup_id = i.m1, r.user_id, r.status) ORDER BY r.meetup_id, r.user_id)
                 FROM public.meetup_rsvps r WHERE r.meetup_id IN (i.m1, i.m2) AND r.user_id IN (i.u_t, i.u_w, i.u_n)),
    'outbox', (SELECT jsonb_agg(jsonb_build_array(o.event_key, o.entity_id = i.m1) ORDER BY o.id)
                 FROM public.event_outbox o WHERE o.entity_id IN (i.m1, i.m2) AND o.event_key IN
                   ('meetup.request_approved', 'meetup.request_declined', 'meetup.attendee_removed')),
    'notif',  (SELECT jsonb_agg(to_jsonb(n) - 'id' - 'created_at' ORDER BY n.user_id, n.kind)
                 FROM public.notifications n WHERE n.entity_id IN (i.m1, i.m2) AND n.user_id IN (i.u_t, i.u_w, i.u_n)))
  INTO st;
  RETURN jsonb_build_object('result', res, 'error', err, 'state', st);
END $f$;

-- One phase: every case in its own rolled-back subtransaction, optionally after a Z01 dry run.
CREATE FUNCTION public.k800_phase(p_phase text, p_z01 boolean) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE c text; s record; r jsonb; d text; skipped text[]; gone int;
BEGIN
  FOREACH c IN ARRAY ARRAY['decide_approve', 'decide_decline', 'decide_admin_approve', 'decide_not_host',
                           'decide_cancelled', 'decide_unknown', 'decide_no_pending', 'decide_invalid',
                           'remove_happy', 'remove_not_host', 'remove_host', 'remove_not_attendee', 'remove_unknown'] LOOP
    skipped := '{}';
    BEGIN
      IF p_z01 THEN
        FOR s IN SELECT seq, stmt FROM public.k800_z01 ORDER BY ord LOOP
          BEGIN EXECUTE s.stmt; EXCEPTION WHEN OTHERS THEN skipped := skipped || (s.seq || ':' || SQLSTATE); END;
        END LOOP;
        IF EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = 'public.meetups'::regclass AND NOT a.attisdropped
                    AND a.attname IN ('creator_user_id', 'is_cancelled')) THEN
          RAISE EXCEPTION 'KAN-800: Z01 dry run left meetups.creator_user_id / is_cancelled in place';
        END IF;
        SELECT count(*) INTO gone FROM public.k800_z01 z WHERE z.seq BETWEEN 701 AND 724
           AND NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = 'public.meetups'::regclass AND NOT a.attisdropped
                            AND a.attname = substring(z.stmt FROM 'DROP COLUMN ([a-z_]+)'));
      END IF;
      r := public.k800_case(c);
      RAISE EXCEPTION 'k800_rollback' USING DETAIL = jsonb_build_object('r', r, 'skipped', to_jsonb(skipped), 'gone', gone)::text;
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'k800_rollback' THEN RAISE; END IF;
      GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL;
    END;
    INSERT INTO public.k800_res VALUES (p_phase, c, (d::jsonb)->'r');
    IF p_z01 AND c = 'decide_approve' THEN
      RAISE NOTICE 'KAN-800 % Z01 dry run: meetups columns removed %/24 (creator_user_id and is_cancelled gone); harness-skipped statements (seq:sqlstate): %',
        p_phase, (d::jsonb)->>'gone', (d::jsonb)->'skipped';
    END IF;
  END LOOP;
END $f$;

-- T1 / T2
SELECT public.k800_phase('pre', false);
SELECT public.k800_phase('pre_z01', true);
\echo '== T1 pre (pre-image, before Z01) and T2 pre_z01 (pre-image after Z01: must be RED)'
SELECT phase, case_name, outcome->>'result' AS result, outcome->'error'->>'sqlstate' AS sqlstate, outcome->'error'->>'message' AS message
  FROM public.k800_res ORDER BY phase, case_name;
DO $t2$ BEGIN
  -- decide_invalid raises before the meetup read, and the two *_unknown cases find no row, so neither reaches a
  -- field of m: those three are the cases Z01 cannot break. The other 10 must fail 42703.
  IF EXISTS (SELECT 1 FROM public.k800_res WHERE phase = 'pre' AND outcome->'error'->>'sqlstate' = '42703')
     OR EXISTS (SELECT 1 FROM public.k800_res WHERE phase = 'pre_z01' AND case_name NOT IN ('decide_invalid', 'decide_unknown', 'remove_unknown')
                  AND outcome->'error'->>'sqlstate' IS DISTINCT FROM '42703')
     OR (SELECT count(*) FROM public.k800_res WHERE phase = 'pre_z01' AND outcome->'error'->>'sqlstate' = '42703') <> 10 THEN
    RAISE EXCEPTION 'KAN-800 T2 FAIL: expected pre clean and the 10 field-reading pre_z01 cases 42703';
  END IF;
  RAISE NOTICE 'KAN-800 T2 PASS (RED shown): the pre-image fails 42703 in all 10 cases that read a field of the meetup once Z01 has run';
END $t2$;

-- C4 before
CREATE TABLE public.k800_acl AS
SELECT 'before'::text AS k, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prorettype::regtype::text AS rettype,
       p.prosecdef, p.provolatile, p.proconfig::text AS proconfig, p.proacl::text AS proacl, p.proowner::regrole::text AS owner
  FROM pg_proc p WHERE p.oid IN ('public.rpc_meetup_decide_request(uuid,uuid,text)'::regprocedure, 'public.rpc_meetup_remove_attendee(uuid,uuid)'::regprocedure);

-- T3
\echo '== T3 apply 20261104110700_kan800_d04_blockers_meetup_requests.sql'
\i supabase/migrations/20261104110700_kan800_d04_blockers_meetup_requests.sql

INSERT INTO public.k800_acl
SELECT 'after', p.proname, pg_get_function_identity_arguments(p.oid), p.prorettype::regtype::text,
       p.prosecdef, p.provolatile, p.proconfig::text, p.proacl::text, p.proowner::regrole::text
  FROM pg_proc p WHERE p.oid IN ('public.rpc_meetup_decide_request(uuid,uuid,text)'::regprocedure, 'public.rpc_meetup_remove_attendee(uuid,uuid)'::regprocedure);

-- T4 / T5
SELECT public.k800_phase('post', false);
SELECT public.k800_phase('post_z01', true);
\echo '== T4 post (new body, before Z01) and T5 post_z01 (new body after Z01)'
SELECT phase, case_name, outcome->>'result' AS result, outcome->'error'->>'sqlstate' AS sqlstate, outcome->'error'->>'message' AS message
  FROM public.k800_res WHERE phase IN ('post', 'post_z01') ORDER BY phase, case_name;
\echo '== full outcome per case: pre vs post / post_z01 (state after the call, rolled back)'
SELECT a.case_name, a.outcome AS pre, (a.outcome = b.outcome) AS post_equal, (a.outcome = c.outcome) AS post_z01_equal
  FROM public.k800_res a JOIN public.k800_res b ON b.case_name = a.case_name AND b.phase = 'post'
  JOIN public.k800_res c ON c.case_name = a.case_name AND c.phase = 'post_z01'
 WHERE a.phase = 'pre' ORDER BY a.case_name;
DO $t5$ DECLARE x text; BEGIN
  SELECT string_agg(a.case_name || '/' || b.phase, ', ') INTO x
    FROM public.k800_res a JOIN public.k800_res b ON b.case_name = a.case_name AND b.phase IN ('post', 'post_z01')
   WHERE a.phase = 'pre' AND a.outcome IS DISTINCT FROM b.outcome;
  IF x IS NOT NULL OR (SELECT count(*) FROM public.k800_res WHERE phase IN ('post', 'post_z01')) <> 26 THEN
    RAISE EXCEPTION 'KAN-800 T4/T5 FAIL: outcome differs from the pre-image: %', x;
  END IF;
  RAISE NOTICE 'KAN-800 T4/T5 PASS (GREEN): all 13 cases identical to the pre-image, before and after Z01';
END $t5$;

-- T6 (C4)
\echo '== T6 / C4 pg_proc before vs after'
SELECT * FROM public.k800_acl ORDER BY proname, k DESC;
DO $t6$ BEGIN
  IF (SELECT count(DISTINCT (proname, args, rettype, prosecdef, provolatile, proconfig, proacl, owner)) FROM public.k800_acl) <> 2
     OR (SELECT count(*) FROM public.k800_acl) <> 4 THEN
    RAISE EXCEPTION 'KAN-800 T6 FAIL: attributes changed';
  END IF;
  RAISE NOTICE 'KAN-800 T6 PASS: signature, return type, SECURITY DEFINER, volatility, search_path, ACL, owner unchanged';
END $t6$;

-- T7 (C3): the meetups-table alias in the new bodies is mt; no meetups%rowtype, no select * from meetups.
\echo '== T7 / C3 meetups-alias column references in pg_get_functiondef'
SELECT p.proname, m[1] || '.' || m[2] AS ref, count(*)
  FROM pg_proc p, regexp_matches(pg_get_functiondef(p.oid), '\m(mt)\.([a-z_]+)', 'g') m
 WHERE p.oid IN ('public.rpc_meetup_decide_request(uuid,uuid,text)'::regprocedure, 'public.rpc_meetup_remove_attendee(uuid,uuid)'::regprocedure)
 GROUP BY 1, 2 ORDER BY 1, 2;
DO $t7$ DECLARE x text; BEGIN
  SELECT string_agg(p.proname || ':' || m[2], ', ') INTO x
    FROM pg_proc p, regexp_matches(pg_get_functiondef(p.oid), '\m(mt)\.([a-z_]+)', 'g') m
   WHERE p.oid IN ('public.rpc_meetup_decide_request(uuid,uuid,text)'::regprocedure, 'public.rpc_meetup_remove_attendee(uuid,uuid)'::regprocedure)
     AND m[2] IN (SELECT substring(stmt FROM 'DROP COLUMN ([a-z_]+)') FROM public.k800_z01 WHERE seq BETWEEN 701 AND 724);
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-800 T7 FAIL: new body reads Z01-removed meetups column(s): %', x; END IF;
  SELECT string_agg(p.proname, ', ') INTO x FROM pg_proc p
   WHERE p.oid IN ('public.rpc_meetup_decide_request(uuid,uuid,text)'::regprocedure, 'public.rpc_meetup_remove_attendee(uuid,uuid)'::regprocedure)
     AND pg_get_functiondef(p.oid) ~* '(meetups%rowtype|select \* into m from public\.meetups)';
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-800 T7 FAIL: whole-row meetups read remains in: %', x; END IF;
  RAISE NOTICE 'KAN-800 T7 PASS: no meetups-alias reference to any of the 24 Z01-removed columns; no whole-row meetups read';
END $t7$;

\echo 'KAN-800: ALL PASS'
