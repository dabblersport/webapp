-- KAN-1004f: the final 'end' reaches the device.
--
-- live_activity_end enqueues the 'end' send and then, in the same transaction, sets the session to 'ended'. The
-- edge function claims the send after commit, and live_activity_claim skipped every send whose session was not
-- 'active' -- so every 'end' was skipped ('session_ended') and a finished game's Android Live Update stayed open.
--
-- Now: a send with la_event = 'end' is claimed when its session is 'ended', unless it was ended because the user
-- opted out or the provider rejected the token. Stale sessions (token rejected) and every non-end send of a
-- non-active session are still skipped. 'end' is enqueued only by live_activity_end, at most once per session
-- (row locked, returns early when already ended), so this cannot send anything twice.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.live_activity_claim(bigint[])'::regprocedure)) <> '1040f62429aadd6ee9afd8047cd6eed5'
  THEN RAISE EXCEPTION 'kan1004f pre-image mismatch: live_activity_claim'; END IF;
END
$guard$;

DO $claim$
DECLARE d text; d2 text;
BEGIN
  d := pg_get_functiondef('public.live_activity_claim(bigint[])'::regprocedure);
  d2 := replace(d, $o$x.status = 'queued' AND ss.status <> 'active';$o$,
    $n$x.status = 'queued' AND ss.status <> 'active'
     AND NOT (x.la_event = 'end' AND ss.status = 'ended'
              AND ss.end_reason IS DISTINCT FROM 'opted_out' AND ss.end_reason IS DISTINCT FROM 'provider_rejected');$n$);
  IF d2 = d THEN RAISE EXCEPTION 'kan1004f: claim skip clause not found'; END IF;
  EXECUTE d2;
END
$claim$;

REVOKE ALL ON FUNCTION public.live_activity_claim(bigint[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.live_activity_claim(bigint[]) TO service_role;

DO $post$
DECLARE r record;
BEGIN
  SELECT pg_get_userbyid(p.proowner) o, p.prosecdef d, p.proconfig c, p.proacl::text a, pg_get_functiondef(p.oid) src INTO r
    FROM pg_proc p WHERE p.oid = 'public.live_activity_claim(bigint[])'::regprocedure;
  IF r.o <> 'postgres' OR NOT r.d OR r.c IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
     OR r.a IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
     OR position($p$x.la_event = 'end' AND ss.status = 'ended'$p$ IN r.src) = 0 THEN
    RAISE EXCEPTION 'kan1004f post-assert failed';
  END IF;
END
$post$;
