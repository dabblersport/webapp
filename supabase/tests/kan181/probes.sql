-- KAN-181 probe pack — public.create_system_post containment + row_security removal.
-- Migration: 20260911075034_kan181_create_system_post_contain_and_reset_row_security
-- APPLIED 2026-09-11 via apply_migration. Repo file is byte-identical to the statement in
-- supabase_migrations.schema_migrations (md5 dea4f00dfb5013162d49214b1bedd3b8, both sides).
-- All probes below PASS post-apply except P1C, which MUST report FAIL by design.
--
-- WHY THESE PROBES LOOK LIKE THIS. `create_system_post` has zero callers and `posts` must not
-- be written by a test, so there is no behavioural assertion to make. The whole defect is
-- REACHABILITY and a CONFIGURATION ARTIFACT, so the evidence is the catalogue itself:
-- who holds EXECUTE, and whether an RLS-bypass override is still attached.
--
-- NO WRITES. Nothing here inserts, updates or deletes. Every probe is a SELECT against
-- pg_proc / pg_roles. The function under test is never invoked in-database: invoking it
-- would attempt an INSERT into `posts` (503 live rows), and this pack must not mutate
-- user data.
--
-- EACH PROBE WAS DEMONSTRATED FAILING BEFORE IT COUNTED AS PASSING:
--   * P2 failed live pre-migration — proconfig was
--     {"search_path=public, extensions",row_security=off}. Re-demonstrated failing
--     immediately before the apply on 2026-09-11 (not cited from an earlier transcript:
--     evidence does not keep overnight). Post-apply it reports PASS on
--     {"search_path=public, extensions"}. That flip IS the proof.
--   * P1 already passed pre-migration (containment landed 2026-09-10, docs/SCHEMA.md §2g.1),
--     so P1 ALONE PROVES NOTHING about the predicate's sharpness. P1C exists for exactly
--     that reason: it aims the identical predicate at a function `anon` genuinely can
--     execute and must report FAIL. A P1C that reports PASS means the predicate has gone
--     vacuous and P1's PASS is worthless — treat that as a broken pack, not a green run.
--
-- RUN AS `postgres`. has_function_privilege is role-explicit so the running role does not
-- change the answers, but the pg_proc reads need catalogue visibility.

-- ===========================================================================
-- P0 — VOID-THE-PACK PRECONDITION. Check the target exists and is shaped as
-- expected before trusting anything below (T-055: a probe against a path that
-- cannot execute proves nothing).
-- ===========================================================================
SELECT
  current_user::text                     AS running_role,   -- expect postgres
  p.oid                                  AS target_oid,     -- expect 109831
  p.prosecdef                            AS secdef,         -- expect true (SECURITY DEFINER)
  pg_get_userbyid(p.proowner)            AS owner,          -- expect postgres
  p.proacl::text                         AS acl,            -- expect {postgres=X/postgres,service_role=X/postgres}
  p.proconfig::text                      AS config,         -- expect {"search_path=public, extensions"} AFTER apply
  md5(p.prosrc)                          AS body_md5        -- expect 993866e237a6563c6df112de59a34988, UNCHANGED
FROM pg_proc p
WHERE p.oid = 'public.create_system_post(uuid,text,post_kind,text,uuid,uuid,post_type_enum,origin_type_enum,uuid,text,double precision,double precision,jsonb)'::regprocedure;

-- The body must be byte-identical across the apply. This migration is pure DDL
-- (REVOKE / ALTER ... RESET / COMMENT) and deliberately restates no body, so a
-- changed md5 means something other than this migration touched the function.

-- ===========================================================================
-- P1 — No untrusted role holds EXECUTE.
-- PUBLIC is checked EXPLICITLY: a bare `=X/postgres` ACL entry is a grant to
-- PUBLIC that `anon` inherits without ever being named, so a proacl text-match
-- for the string 'anon' would miss it. has_function_privilege is required.
-- ===========================================================================
WITH t AS (
  SELECT 'public.create_system_post(uuid,text,post_kind,text,uuid,uuid,post_type_enum,origin_type_enum,uuid,text,double precision,double precision,jsonb)'::regprocedure AS oid
)
SELECT
  'P1 no untrusted EXECUTE' AS probe,
  CASE WHEN NOT has_function_privilege('anon',          (SELECT oid FROM t), 'EXECUTE')
        AND NOT has_function_privilege('authenticated', (SELECT oid FROM t), 'EXECUTE')
        AND NOT has_function_privilege('public',        (SELECT oid FROM t), 'EXECUTE')
       THEN 'PASS' ELSE 'FAIL' END AS result,
  (SELECT proacl::text FROM pg_proc WHERE oid = (SELECT oid FROM t)) AS evidence;

-- ===========================================================================
-- P1C — DISCRIMINATION CONTROL. MUST REPORT 'FAIL'.
-- The same predicate aimed at public.jwt_role(), which anon genuinely can
-- execute (acl carries anon, authenticated AND a bare =X PUBLIC grant).
-- Measured FAIL on 2026-09-11. A PASS here voids P1.
-- ===========================================================================
SELECT
  'P1C control, expect FAIL' AS probe,
  CASE WHEN NOT has_function_privilege('anon',          'public.jwt_role()'::regprocedure, 'EXECUTE')
        AND NOT has_function_privilege('authenticated', 'public.jwt_role()'::regprocedure, 'EXECUTE')
        AND NOT has_function_privilege('public',        'public.jwt_role()'::regprocedure, 'EXECUTE')
       THEN 'PASS' ELSE 'FAIL' END AS result,
  (SELECT proacl::text FROM pg_proc WHERE oid = 'public.jwt_role()'::regprocedure) AS evidence;

-- ===========================================================================
-- P2 — No row_security override remains on the function.
-- FAILED pre-migration (proconfig held row_security=off). This is the probe
-- the migration actually flips.
-- ===========================================================================
WITH t AS (
  SELECT 'public.create_system_post(uuid,text,post_kind,text,uuid,uuid,post_type_enum,origin_type_enum,uuid,text,double precision,double precision,jsonb)'::regprocedure AS oid
)
SELECT
  'P2 no row_security override' AS probe,
  CASE WHEN NOT EXISTS (
         SELECT 1 FROM pg_proc p, unnest(coalesce(p.proconfig, '{}')) c
         WHERE p.oid = (SELECT oid FROM t) AND c LIKE 'row_security=%')
       THEN 'PASS' ELSE 'FAIL' END AS result,
  (SELECT proconfig::text FROM pg_proc WHERE oid = (SELECT oid FROM t)) AS evidence;

-- ===========================================================================
-- P3 — The justification for REMOVING row_security=off, asserted rather than
-- assumed: every role that still holds EXECUTE must bypass RLS anyway, which
-- is what makes the override redundant rather than load-bearing.
-- If a future grant hands EXECUTE to a role WITHOUT rolbypassrls, this flips
-- to FAIL and the removal would need revisiting.
-- ===========================================================================
WITH t AS (
  SELECT 'public.create_system_post(uuid,text,post_kind,text,uuid,uuid,post_type_enum,origin_type_enum,uuid,text,double precision,double precision,jsonb)'::regprocedure AS oid
)
SELECT
  'P3 all EXECUTE holders bypass RLS' AS probe,
  CASE WHEN bool_and(r.rolbypassrls) THEN 'PASS' ELSE 'FAIL' END AS result,
  string_agg(r.rolname || '=' || r.rolbypassrls::text, ', ' ORDER BY r.rolname) AS evidence
FROM pg_roles r
WHERE r.rolcanlogin IS NOT NULL
  AND has_function_privilege(r.rolname, (SELECT oid FROM t), 'EXECUTE')
  AND r.rolname NOT LIKE 'pg\_%';

-- ===========================================================================
-- P4 — Zero callers. The finding that selected AC2 option (b). If this ever
-- returns rows, the "nothing creates them today" justification in the
-- migration header has expired and the disposition needs rethinking.
-- ===========================================================================
SELECT
  'P4 zero in-database callers' AS probe,
  CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
  coalesce(string_agg(n.nspname || '.' || p.proname, ', '), '(none)') AS evidence
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosrc ILIKE '%create_system_post%'
  AND p.oid <> 'public.create_system_post(uuid,text,post_kind,text,uuid,uuid,post_type_enum,origin_type_enum,uuid,text,double precision,double precision,jsonb)'::regprocedure;

-- ===========================================================================
-- EXTERNAL REACHABILITY (AC4) IS NOT PROVABLE FROM IN-DATABASE SQL and is
-- deliberately not faked here. It was verified by HTTP round-trip on
-- 2026-09-11 against https://wtncuzcskpigqpmnxwws.supabase.co with the anon
-- key, with a positive control so the denial means something:
--
--   POST /rest/v1/rpc/jwt_role            -> HTTP 200, body "anon"
--       (control: the harness reaches PostgREST, RPC dispatch works, and the
--        caller is genuinely executing as anon)
--   POST /rest/v1/rpc/create_system_post  -> HTTP 401,
--       {"code":"42501","message":"permission denied for function create_system_post"}
--
-- Run twice — once before the apply and once after it — with identical results both
-- times, which is the point: the ACL was already contained, so the apply must NOT have
-- changed reachability. The control returning 200 on both runs is what makes the
-- unchanged 401 meaningful rather than a dead endpoint.
--
-- The probe body used a fabricated p_profile_id. That is SAFE BY CONSTRUCTION,
-- not by luck: the function resolves p_profile_id against `profiles` and
-- raises 'user_id is NULL for profile %' BEFORE reaching its INSERT, so even
-- had permission passed, no row could have been written.
-- ===========================================================================
