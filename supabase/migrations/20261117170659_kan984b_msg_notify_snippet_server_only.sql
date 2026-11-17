-- KAN-984b (PEER review comment 16469): close direct client calls to the snippet overload.
--
-- msg_notify(uuid,bigint,text,text) let any member who may send in a conversation push arbitrary text (up to 140
-- characters) to the other members without a stored message (probe R4). Until the Worker can prove it is the caller
-- (proposal on KAN-984), the overload is server-only: EXECUTE is revoked from authenticated. Nothing else changes:
-- the 3-argument msg_notify (sender-only, what the deployed Worker calls) keeps its grant.

DO $guard$
BEGIN
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.msg_notify(uuid,bigint,text,text)'::regprocedure)
       <> '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
     OR (SELECT proacl::text FROM pg_proc WHERE oid = 'public.msg_notify(uuid,bigint,text)'::regprocedure)
       <> '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan984b pre-image: msg_notify grants changed since 20261117164003';
  END IF;
END
$guard$;

REVOKE EXECUTE ON FUNCTION public.msg_notify(uuid, bigint, text, text) FROM authenticated;

DO $post$
BEGIN
  IF has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.msg_notify(uuid,bigint,text,text)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.msg_notify(uuid,bigint,text,text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan984b post-image: msg_notify grants not as intended';
  END IF;
END
$post$;
