-- KAN-958 follow-up (coordinator ruling 2026-11-16): the only opt-out in the product is the bench form's
-- "Hide me in search", which means "while benched". The flag must not outlive the bench, so ending a bench
-- returns the profile to the default (visible).
-- 1. public.rpc_end_bench() also sets hide_in_search = false. Body re-authored from the live
--    pg_get_functiondef (pre-image md5 guarded). Owner, SECURITY DEFINER, search_path and ACL are unchanged
--    (CREATE OR REPLACE keeps the ACL) and are asserted.
-- 2. One-time data fix: user_status rows with is_benched = false and hide_in_search = true get
--    hide_in_search = false (2 rows at authoring).
-- is_benched() (reads user_benches/benches, neither exists, always false) is a known dead helper, left as is.
-- Applied under G-002 by backend-1.

DO $pre$
DECLARE v_md5 text; v_acl text[];
BEGIN
  SELECT md5(pg_get_functiondef(p.oid)), (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x)
    INTO v_md5, v_acl
    FROM pg_proc p WHERE p.oid = 'public.rpc_end_bench()'::regprocedure;
  IF v_md5 IS DISTINCT FROM 'fe518c83318232836479f8ed940e669a' THEN
    RAISE EXCEPTION 'KAN-958b pre-image md5 mismatch: %', v_md5;
  END IF;
  IF v_acl IS DISTINCT FROM ARRAY['=X/postgres','anon=X/postgres','authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres'] THEN
    RAISE EXCEPTION 'KAN-958b pre-image ACL mismatch: %', v_acl;
  END IF;
END
$pre$;

CREATE OR REPLACE FUNCTION public.rpc_end_bench()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.user_status
  set is_benched = false, bench_until = null, reason = null,
      hide_in_search = false,  -- KAN-958: the search opt-out is a bench setting; it ends with the bench
      updated_at = now()
  where user_id = auth.uid();
end;
$function$;

UPDATE public.user_status
   SET hide_in_search = false, updated_at = now()
 WHERE is_benched = false AND hide_in_search = true;

DO $post$
DECLARE r record; v_n int;
BEGIN
  SELECT pg_get_userbyid(p.proowner) AS owner, p.prosecdef, p.proconfig,
         (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x) AS acl,
         pg_get_functiondef(p.oid) AS def
    INTO r
    FROM pg_proc p WHERE p.oid = 'public.rpc_end_bench()'::regprocedure;
  IF r.owner <> 'postgres' OR NOT r.prosecdef
     OR r.proconfig IS DISTINCT FROM ARRAY['search_path=public']
     OR r.acl IS DISTINCT FROM ARRAY['=X/postgres','anon=X/postgres','authenticated=X/postgres','postgres=X/postgres','service_role=X/postgres']
     OR r.def NOT LIKE '%hide_in_search = false%' THEN
    RAISE EXCEPTION 'KAN-958b post-image mismatch: owner=% secdef=% cfg=% acl=%', r.owner, r.prosecdef, r.proconfig, r.acl;
  END IF;
  SELECT count(*) INTO v_n FROM public.user_status WHERE is_benched = false AND hide_in_search = true;
  IF v_n <> 0 THEN RAISE EXCEPTION 'KAN-958b data fix left % unbenched hidden rows', v_n; END IF;
END
$post$;
