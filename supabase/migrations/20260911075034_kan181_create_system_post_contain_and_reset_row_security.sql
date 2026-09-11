-- KAN-181 — public.create_system_post: root fix (AC2, option (b)).
-- Full rationale in the committed repo file of the same name. Summary, all
-- measured live against wtncuzcskpigqpmnxwws immediately before applying:
--   * ZERO CALLERS confirmed live (pg_proc.prosrc across all schemas, pg_views,
--     pg_attrdef, pg_constraint, pg_trigger, 4 deployed edge functions, Dart)
--     -> AC3 resolves to "nothing creates them today"; option (b) costs no
--     capability. If revived, the trusted path is service_role.
--   * row_security=off REMOVED as provably redundant: SECURITY DEFINER owned by
--     postgres, and every role retaining EXECUTE (postgres, service_role,
--     supabase_admin) carries rolbypassrls = true, so RLS never applied here.
--   * ALTER ... RESET preserves the ACL. A DROP+CREATE would re-derive it from
--     pg_default_acl, which still grants anon EXECUTE on new public functions
--     (KAN-189/KAN-194, unfixed) -- i.e. would re-open this hole. No body
--     restatement, so T-058 does not arise.
--   * PUBLIC named explicitly: a bare =X/postgres entry is a PUBLIC grant that
--     anon inherits without ever being named.

REVOKE ALL ON FUNCTION public.create_system_post(
  uuid, text, post_kind, text, uuid, uuid, post_type_enum,
  origin_type_enum, uuid, text, double precision, double precision, jsonb
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.create_system_post(
  uuid, text, post_kind, text, uuid, uuid, post_type_enum,
  origin_type_enum, uuid, text, double precision, double precision, jsonb
) FROM anon;

REVOKE ALL ON FUNCTION public.create_system_post(
  uuid, text, post_kind, text, uuid, uuid, post_type_enum,
  origin_type_enum, uuid, text, double precision, double precision, jsonb
) FROM authenticated;

ALTER FUNCTION public.create_system_post(
  uuid, text, post_kind, text, uuid, uuid, post_type_enum,
  origin_type_enum, uuid, text, double precision, double precision, jsonb
) RESET row_security;

COMMENT ON FUNCTION public.create_system_post(
  uuid, text, post_kind, text, uuid, uuid, post_type_enum,
  origin_type_enum, uuid, text, double precision, double precision, jsonb
) IS
'KAN-181. NOT INDEPENDENTLY CALLABLE by any untrusted caller: EXECUTE is held '
'only by postgres, service_role and supabase_admin. p_profile_id is a '
'caller-supplied AUTHORIZATION SUBJECT, not a filter -- it sets post '
'authorship -- so this function must never be reachable by anon or '
'authenticated. It had zero callers as of 2026-09-11 (no function, view, '
'default, constraint, trigger, edge function or client call site); if '
'system-generated posts are revived, the trusted path is service_role, and '
'any move to make it callable by an end-user role requires deriving '
'authorship from auth.uid() inside the body instead of accepting it as an '
'argument. The former SET row_security = off was removed as provably '
'redundant: every remaining EXECUTE holder has rolbypassrls.';