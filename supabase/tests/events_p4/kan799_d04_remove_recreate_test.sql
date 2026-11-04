-- KAN-799 (supporting KAN-772 / KAN-719): proof for 20261104110600_kan799_d04_blockers_remove_recreate.sql.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
-- It COMMITS a fixture and seed rows into the throwaway database; every call under test runs inside a
-- subtransaction that is rolled back, so each phase starts from the same state.
--
-- The local chain has neither function (KAN718_D04_DISPOSITION.md rows 27/28, "baseline only"). F installs the
-- baseline pre-images VERBATIM (cut from 20260829080500_baseline_schema.sql by sed, with their baseline GRANTs), plus
-- their two baseline helpers (_next_week_same_time, rpc_draft_create, verbatim) and two marked local stand-in tables
-- (content_drafts, content_draft_events: baseline columns and checks, no sequence/ownership/comment).
--
--   T0  the fixture pre-images md5(prosrc) equal the migration's pins (and KAN-714 part 2's independent pins)
--   T1  phase pre      : pre-image, legacy columns present            -> the reference results
--   T2  phase pre_z01  : pre-image, Z01 dry run (rolled back)          -> RED: every case fails 42703
--   T3  migration applied (its own BEGIN/COMMIT, pre/post-conditions)
--   T4  phase post     : new body, legacy columns present             -> identical to pre
--   T5  phase post_z01 : new body, Z01 dry run (rolled back)          -> identical to pre, no 42703
--   T6  C4: signature, result type, SECURITY, search_path, owner, ACL identical before vs after
--   T7  C3: in the new bodies, every games-table alias reads only id / event_id / venue_space_id
--
-- Z01 dry run: every statement of 20261105100000_kan719_z01_remove_replaced_columns.sql (`...;  -- <seq>` lines,
-- extracted the same way kan719_z01_removal_test.sql does), each in its own savepoint, in file order; statements the
-- harness cannot run are skipped and listed. The test requires that all 23 games DROP COLUMNs (601-623) succeed.
--
-- Cases (same inputs every phase): remove_happy (host removes a player, waitlist promoted), remove_not_host,
-- remove_cancelled (game_not_found), recreate_happy (shift week), recreate_noshift, recreate_not_authorized,
-- recreate_unknown (game_not_found).
--
-- Run (repository root) on a fresh cluster built by supabase/tests/events_p2/build_kan788.sh:
--   psql -X -h /tmp -p <port> -U postgres -d k788 -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan799_d04_remove_recreate_test.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-799: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k788|k799)' THEN
    RAISE EXCEPTION 'KAN-799: database % is not a throwaway k788/k799 database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-799: run as a superuser'; END IF;
  IF to_regprocedure('public.rpc_remove_player(uuid,uuid)') IS NOT NULL
     OR to_regprocedure('public.rpc_recreate_from_game(uuid,boolean)') IS NOT NULL
     OR to_regclass('public.k799_res') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-799: functions or results already present; use a fresh DB';
  END IF;
END $g$;

-- ---------------------------------------------------------------------------------------------------------
-- F. Fixture
-- ---------------------------------------------------------------------------------------------------------
-- LOCAL STAND-IN (baseline :22535 / :22564 columns and checks; bigserial instead of the owned sequence).
CREATE TABLE public.content_drafts (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    owner_user_id uuid NOT NULL,
    context text NOT NULL,
    payload jsonb NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT content_drafts_context_check CHECK (context = ANY (ARRAY['game'::text, 'meetup'::text, 'challenge'::text])),
    CONSTRAINT content_drafts_status_check CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'archived'::text, 'expired'::text])));
CREATE TABLE public.content_draft_events (
    id bigserial NOT NULL PRIMARY KEY,
    draft_id uuid NOT NULL,
    owner_user_id uuid NOT NULL,
    action text NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT content_draft_events_action_check CHECK (action = ANY (ARRAY['created'::text, 'updated'::text, 'published'::text, 'archived'::text, 'expired'::text])));

-- VERBATIM from the baseline.
\set fx `B=supabase/migrations/20260829080500_baseline_schema.sql; for f in _next_week_same_time rpc_draft_create rpc_recreate_from_game rpc_remove_player; do sed -n "/^CREATE OR REPLACE FUNCTION \"public\".\"$f\"(/,/^ALTER FUNCTION \"public\".\"$f\"(/p" $B; grep "^GRANT ALL ON FUNCTION \"public\".\"$f\"(" $B; done`
:fx

-- T0
DO $t0$
DECLARE x text;
BEGIN
  SELECT string_agg(f || '=' || md5(p.prosrc), ', ') INTO x
    FROM (VALUES ('public.rpc_remove_player(uuid,uuid)', 'ab3b5239eb5bb283622679c842ba9cd7'),
                 ('public.rpc_recreate_from_game(uuid,boolean)', '6e410ca16771fbdf20a6f37553131e6c')) t(f, want)
    JOIN pg_proc p ON p.oid = to_regprocedure(t.f)
   WHERE md5(p.prosrc) <> t.want;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-799 T0 FAIL: fixture pre-image differs from the pin: %', x; END IF;
  RAISE NOTICE 'KAN-799 T0 PASS: fixture pre-images match the migration pins ab3b5239.. / 6e410ca1..';
END $t0$;

-- ---------------------------------------------------------------------------------------------------------
-- Seed (committed, throwaway DB). Game G1: the first open harness game; G2: the first cancelled one.
-- ---------------------------------------------------------------------------------------------------------
CREATE TABLE public.k799_ids AS
SELECT (SELECT id FROM public.games WHERE NOT is_cancelled AND creator_user_id IS NOT NULL ORDER BY id LIMIT 1) AS g1,
       (SELECT id FROM public.games WHERE is_cancelled AND creator_user_id IS NOT NULL ORDER BY id LIMIT 1) AS g2,
       '00000000-0000-0000-0000-0000000079a1'::uuid AS u_t, '00000000-0000-0000-0000-0000000079b1'::uuid AS p_t,
       '00000000-0000-0000-0000-0000000079a2'::uuid AS u_w, '00000000-0000-0000-0000-0000000079b2'::uuid AS p_w;
ALTER TABLE public.k799_ids ADD COLUMN host_u uuid, ADD COLUMN host_p uuid, ADD COLUMN g2_host uuid;
UPDATE public.k799_ids SET host_u = (SELECT creator_user_id FROM public.games WHERE id = g1),
                           host_p = (SELECT creator_profile_id FROM public.games WHERE id = g1),
                           g2_host = (SELECT creator_user_id FROM public.games WHERE id = g2);
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
SELECT g1, host_u, host_p, 'host', 'active' FROM public.k799_ids
UNION ALL SELECT g1, u_t, p_t, 'player', 'active' FROM public.k799_ids
UNION ALL SELECT g2, u_t, p_t, 'player', 'active' FROM public.k799_ids;
INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position) SELECT g1, p_w, u_w, 1 FROM public.k799_ids;
SELECT 'seed' AS k, g1, g2, host_u, g2_host,
       EXISTS (SELECT 1 FROM public.harness_admins a WHERE a.admin_uid IN (host_u, u_t)) AS any_admin
  FROM public.k799_ids;

-- Z01 statements, file order.
\set z01text `cat supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql`
CREATE TABLE public.k799_z01 AS
  SELECT ord, x[1] AS stmt, x[2]::int AS seq
    FROM (SELECT :'z01text'::text AS src) s, regexp_matches(src, '\n((?:ALTER|DROP) [^\n]*?);  -- (\d+)', 'g') WITH ORDINALITY AS r(x, ord);
SELECT 'z01 statements' AS k, count(*) AS n, count(*) FILTER (WHERE seq BETWEEN 601 AND 623) AS games_drop_columns FROM public.k799_z01;

CREATE TABLE public.k799_res (phase text, case_name text, outcome jsonb, PRIMARY KEY (phase, case_name));

-- One case, as the given user. Returns the result or error plus the state it leaves (caller rolls back).
CREATE FUNCTION public.k799_case(p_case text) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE i public.k799_ids; res text; st jsonb; err jsonb := NULL;
BEGIN
  SELECT * INTO i FROM public.k799_ids;
  PERFORM set_config('request.jwt.claim.sub',
    (CASE p_case WHEN 'remove_happy' THEN i.host_u WHEN 'remove_cancelled' THEN i.g2_host
                 WHEN 'recreate_happy' THEN i.host_u WHEN 'recreate_noshift' THEN i.host_u
                 WHEN 'recreate_unknown' THEN i.host_u ELSE i.u_t END)::text, true);
  BEGIN
    res := CASE p_case
      WHEN 'remove_happy'            THEN public.rpc_remove_player(i.g1, i.p_t)
      WHEN 'remove_not_host'         THEN public.rpc_remove_player(i.g1, i.p_t)
      WHEN 'remove_cancelled'        THEN public.rpc_remove_player(i.g2, i.p_t)
      WHEN 'recreate_happy'          THEN CASE WHEN public.rpc_recreate_from_game(i.g1, true) IS NOT NULL THEN 'uuid' END
      WHEN 'recreate_noshift'        THEN CASE WHEN public.rpc_recreate_from_game(i.g1, false) IS NOT NULL THEN 'uuid' END
      WHEN 'recreate_not_authorized' THEN CASE WHEN public.rpc_recreate_from_game(i.g1, true) IS NOT NULL THEN 'uuid' END
      WHEN 'recreate_unknown'        THEN CASE WHEN public.rpc_recreate_from_game('00000000-0000-0000-0000-00000000dead', true) IS NOT NULL THEN 'uuid' END
    END;
  EXCEPTION WHEN OTHERS THEN
    err := jsonb_build_object('sqlstate', SQLSTATE, 'message', SQLERRM);
  END;
  SELECT jsonb_build_object(
    'roster',   (SELECT jsonb_agg(jsonb_build_array(r.game_id = i.g1, r.profile_id, r.role, r.status, r.left_at IS NOT NULL) ORDER BY r.game_id, r.profile_id)
                   FROM public.game_roster r WHERE r.game_id IN (i.g1, i.g2)),
    'waitlist', (SELECT jsonb_agg(w.profile_id ORDER BY w.position) FROM public.game_waitlist w WHERE w.game_id = i.g1),
    'notif',    (SELECT jsonb_agg(jsonb_build_array(n.user_id, n.kind, n.entity_type, n.entity_id = i.g1, n.actor_user_id, n.title) ORDER BY n.user_id)
                   FROM public.notifications n WHERE n.kind = 'game.removed'),
    'drafts',   (SELECT jsonb_agg(jsonb_build_array(d.owner_user_id, d.context, d.status, d.payload)) FROM public.content_drafts d),
    'draft_ev', (SELECT jsonb_agg(jsonb_build_array(e.owner_user_id, e.action)) FROM public.content_draft_events e))
  INTO st;
  RETURN jsonb_build_object('result', res, 'error', err, 'state', st);
END $f$;

-- One phase: every case in its own rolled-back subtransaction, optionally after a Z01 dry run.
CREATE FUNCTION public.k799_phase(p_phase text, p_z01 boolean) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE c text; s record; r jsonb; d text; skipped text[]; gone int;
BEGIN
  FOREACH c IN ARRAY ARRAY['remove_happy', 'remove_not_host', 'remove_cancelled', 'recreate_happy',
                           'recreate_noshift', 'recreate_not_authorized', 'recreate_unknown'] LOOP
    skipped := '{}';
    BEGIN
      IF p_z01 THEN
        FOR s IN SELECT seq, stmt FROM public.k799_z01 ORDER BY ord LOOP
          BEGIN EXECUTE s.stmt; EXCEPTION WHEN OTHERS THEN skipped := skipped || (s.seq || ':' || SQLSTATE); END;
        END LOOP;
        SELECT count(*) INTO gone FROM public.k799_z01 z WHERE z.seq BETWEEN 601 AND 623
           AND NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = 'public.games'::regclass AND NOT a.attisdropped
                            AND a.attname = substring(z.stmt FROM 'DROP COLUMN ([a-z_]+)'));
        IF gone <> 23 THEN RAISE EXCEPTION 'KAN-799: Z01 dry run removed only % of the 23 games columns', gone; END IF;
      END IF;
      r := public.k799_case(c);
      RAISE EXCEPTION 'k799_rollback' USING DETAIL = jsonb_build_object('r', r, 'skipped', to_jsonb(skipped))::text;
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'k799_rollback' THEN RAISE; END IF;
      GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL;
    END;
    INSERT INTO public.k799_res VALUES (p_phase, c, (d::jsonb)->'r');
    IF p_z01 AND c = 'remove_happy' THEN
      RAISE NOTICE 'KAN-799 % Z01 dry run: games columns removed 23/23; harness-skipped statements (seq:sqlstate): %', p_phase, (d::jsonb)->'skipped';
    END IF;
  END LOOP;
END $f$;

-- T1 / T2
SELECT public.k799_phase('pre', false);
SELECT public.k799_phase('pre_z01', true);
\echo '== T1 pre (pre-image, before Z01) and T2 pre_z01 (pre-image after Z01: must be RED)'
SELECT phase, case_name, outcome->>'result' AS result, outcome->'error'->>'sqlstate' AS sqlstate, outcome->'error'->>'message' AS message
  FROM public.k799_res ORDER BY phase, case_name;
DO $t2$ BEGIN
  IF EXISTS (SELECT 1 FROM public.k799_res WHERE phase = 'pre' AND outcome->'error'->>'sqlstate' = '42703')
     OR EXISTS (SELECT 1 FROM public.k799_res WHERE phase = 'pre_z01' AND outcome->'error'->>'sqlstate' IS DISTINCT FROM '42703') THEN
    RAISE EXCEPTION 'KAN-799 T2 FAIL: expected pre clean and every pre_z01 case 42703';
  END IF;
  RAISE NOTICE 'KAN-799 T2 PASS (RED shown): the pre-image fails 42703 in all 7 cases once Z01 has run';
END $t2$;

-- C4 before
CREATE TABLE public.k799_acl AS
SELECT 'before'::text AS k, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prorettype::regtype::text AS rettype,
       p.prosecdef, p.provolatile, p.proconfig::text AS proconfig, p.proacl::text AS proacl, p.proowner::regrole::text AS owner
  FROM pg_proc p WHERE p.oid IN ('public.rpc_remove_player(uuid,uuid)'::regprocedure, 'public.rpc_recreate_from_game(uuid,boolean)'::regprocedure);

-- T3
\echo '== T3 apply 20261104110600_kan799_d04_blockers_remove_recreate.sql'
\i supabase/migrations/20261104110600_kan799_d04_blockers_remove_recreate.sql

INSERT INTO public.k799_acl
SELECT 'after', p.proname, pg_get_function_identity_arguments(p.oid), p.prorettype::regtype::text,
       p.prosecdef, p.provolatile, p.proconfig::text, p.proacl::text, p.proowner::regrole::text
  FROM pg_proc p WHERE p.oid IN ('public.rpc_remove_player(uuid,uuid)'::regprocedure, 'public.rpc_recreate_from_game(uuid,boolean)'::regprocedure);

-- T4 / T5
SELECT public.k799_phase('post', false);
SELECT public.k799_phase('post_z01', true);
\echo '== T4 post (new body, before Z01) and T5 post_z01 (new body after Z01)'
SELECT phase, case_name, outcome->>'result' AS result, outcome->'error'->>'sqlstate' AS sqlstate, outcome->'error'->>'message' AS message
  FROM public.k799_res WHERE phase IN ('post', 'post_z01') ORDER BY phase, case_name;
\echo '== full outcome per case: pre vs post_z01 (state after the call, rolled back)'
SELECT a.case_name, a.outcome AS pre, (a.outcome = b.outcome) AS post_equal, (a.outcome = c.outcome) AS post_z01_equal
  FROM public.k799_res a JOIN public.k799_res b ON b.case_name = a.case_name AND b.phase = 'post'
  JOIN public.k799_res c ON c.case_name = a.case_name AND c.phase = 'post_z01'
 WHERE a.phase = 'pre' ORDER BY a.case_name;
DO $t5$ DECLARE x text; BEGIN
  SELECT string_agg(a.case_name || '/' || b.phase, ', ') INTO x
    FROM public.k799_res a JOIN public.k799_res b ON b.case_name = a.case_name AND b.phase IN ('post', 'post_z01')
   WHERE a.phase = 'pre' AND a.outcome IS DISTINCT FROM b.outcome;
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-799 T4/T5 FAIL: outcome differs from the pre-image: %', x; END IF;
  RAISE NOTICE 'KAN-799 T4/T5 PASS (GREEN): all 7 cases identical to the pre-image, before and after Z01';
END $t5$;

-- T6 (C4)
\echo '== T6 / C4 pg_proc before vs after'
SELECT * FROM public.k799_acl ORDER BY proname, k DESC;
DO $t6$ BEGIN
  IF (SELECT count(DISTINCT (proname, args, rettype, prosecdef, provolatile, proconfig, proacl, owner)) FROM public.k799_acl) <> 2
     OR (SELECT count(*) FROM public.k799_acl) <> 4 THEN
    RAISE EXCEPTION 'KAN-799 T6 FAIL: attributes changed';
  END IF;
  RAISE NOTICE 'KAN-799 T6 PASS: signature, return type, SECURITY DEFINER, volatility, search_path, ACL, owner unchanged';
END $t6$;

-- T7 (C3): games-table aliases per function: rpc_remove_player g; rpc_recreate_from_game gm, gg (its `g` is a record).
\echo '== T7 / C3 games-alias column references in pg_get_functiondef'
SELECT p.proname, m[1] || '.' || m[2] AS ref, count(*)
  FROM pg_proc p, regexp_matches(pg_get_functiondef(p.oid),
         CASE p.proname WHEN 'rpc_remove_player' THEN '\m(g)\.([a-z_]+)' ELSE '\m(gm|gg)\.([a-z_]+)' END, 'g') m
 WHERE p.oid IN ('public.rpc_remove_player(uuid,uuid)'::regprocedure, 'public.rpc_recreate_from_game(uuid,boolean)'::regprocedure)
 GROUP BY 1, 2 ORDER BY 1, 2;
DO $t7$ DECLARE x text; BEGIN
  SELECT string_agg(p.proname || ':' || m[2], ', ') INTO x
    FROM pg_proc p, regexp_matches(pg_get_functiondef(p.oid),
           CASE p.proname WHEN 'rpc_remove_player' THEN '\m(g)\.([a-z_]+)' ELSE '\m(gm|gg)\.([a-z_]+)' END, 'g') m
   WHERE p.oid IN ('public.rpc_remove_player(uuid,uuid)'::regprocedure, 'public.rpc_recreate_from_game(uuid,boolean)'::regprocedure)
     AND m[2] IN (SELECT substring(stmt FROM 'DROP COLUMN ([a-z_]+)') FROM public.k799_z01 WHERE seq BETWEEN 601 AND 623);
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-799 T7 FAIL: new body reads Z01-removed games column(s): %', x; END IF;
  RAISE NOTICE 'KAN-799 T7 PASS: no games-alias reference to any of the 23 Z01-removed columns';
END $t7$;

\echo 'KAN-799: ALL PASS'
