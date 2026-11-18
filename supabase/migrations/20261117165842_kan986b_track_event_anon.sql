-- KAN-1011 follow-up (PEER 16467): rpc_track_event(text, jsonb) keeps anon EXECUTE.
--
-- 20261117164404 revoked anon from every volatile rpc_* outside its read-only list. rpc_track_event is a write, but
-- KAN-109 designed it to accept one event before sign-in: lib/main.dart:91 sends 'flags_snapshot' as anon. The
-- function guards itself: with auth.uid() NULL any other event name raises 42501 ('event "%" is not permitted for
-- unauthenticated callers'), and properties over 4096 bytes raise 22001. So anon EXECUTE is restored, and the
-- function joins the anon-kept list (also recorded in 20261117164404 and in kan986_housekeeping.sql).

DO $pre$
BEGIN
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.rpc_track_event(text,jsonb)'::regprocedure)
       IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-986b pre: rpc_track_event ACL is not the 20261117164404 state';
  END IF;
  IF md5(pg_get_functiondef('public.rpc_track_event(text,jsonb)'::regprocedure)) <> '7bfdfaf799005b6ce9a685da1637c58b' THEN
    RAISE EXCEPTION 'KAN-986b pre: rpc_track_event body changed (its anon guard must be re-read)';
  END IF;
END
$pre$;

GRANT EXECUTE ON FUNCTION public.rpc_track_event(text, jsonb) TO anon;

DO $post$
BEGIN
  IF NOT has_function_privilege('anon', 'public.rpc_track_event(text,jsonb)', 'EXECUTE')
     OR has_function_privilege('public', 'public.rpc_track_event(text,jsonb)', 'EXECUTE')
     OR (SELECT count(*) FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f'
           AND p.provolatile = 'v' AND p.proname LIKE 'rpc\_%' AND has_function_privilege('anon', p.oid, 'EXECUTE')) <> 16 THEN
    RAISE EXCEPTION 'KAN-986b post: anon rpc_* set is not the 15 read-only RPCs + rpc_track_event';
  END IF;
END
$post$;
