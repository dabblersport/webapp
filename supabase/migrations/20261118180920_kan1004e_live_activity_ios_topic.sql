-- KAN-1004e: iOS Live Activity sender (send-live-activity v3).
--
-- The stored iOS payload gains apns.headers."apns-topic" = 'app.dabbler.pro.push-type.liveactivity' (Apple: the
-- main app's bundle id + ".push-type.liveactivity", the same topic for start, update and end). Everything else in the
-- apns block is unchanged (see 20261118140810 PAYLOAD CONTRACT). The edge function adds at send time:
--   message.token                 the installation's FCM registration token (fcm_tokens)
--   message.apns.live_activity_token  start: live_activity_push_to_start.token; update/end: sessions.push_token
-- live_activity_config.ios_sender_enabled is NOT changed here (still false): iOS rows still end
-- 'unsent: no credentials' at enqueue and are never posted; the function re-checks the flag before any iOS send.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.live_activity_enqueue(uuid,text,text,jsonb)'::regprocedure)) <> 'e771fcf87ac829a3f7442678757bf8d2'
  THEN RAISE EXCEPTION 'kan1004e pre-image mismatch: live_activity_enqueue'; END IF;
END
$guard$;

DO $enq$
DECLARE d text; d2 text;
BEGIN
  d := pg_get_functiondef('public.live_activity_enqueue(uuid,text,text,jsonb)'::regprocedure);
  d2 := replace(d, $o$jsonb_build_object('apns-push-type', 'liveactivity', 'apns-priority', '10')$o$,
    $n$jsonb_build_object('apns-push-type', 'liveactivity', 'apns-priority', '10', 'apns-topic', 'app.dabbler.pro.push-type.liveactivity')$n$);
  IF d2 = d THEN RAISE EXCEPTION 'kan1004e: enqueue apns headers not found'; END IF;
  EXECUTE d2;
END
$enq$;

REVOKE ALL ON FUNCTION public.live_activity_enqueue(uuid,text,text,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.live_activity_enqueue(uuid,text,text,jsonb) TO service_role;

DO $post$
DECLARE r record;
BEGIN
  SELECT pg_get_userbyid(p.proowner) o, p.prosecdef d, p.proconfig c, p.proacl::text a, pg_get_functiondef(p.oid) src INTO r
    FROM pg_proc p WHERE p.oid = 'public.live_activity_enqueue(uuid,text,text,jsonb)'::regprocedure;
  IF r.o <> 'postgres' OR NOT r.d OR r.c IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
     OR r.a IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
     OR position('app.dabbler.pro.push-type.liveactivity' IN r.src) = 0 THEN
    RAISE EXCEPTION 'kan1004e post-assert failed';
  END IF;
  IF (SELECT ios_sender_enabled FROM public.live_activity_config) THEN
    RAISE EXCEPTION 'kan1004e post-assert: ios_sender_enabled must stay false';
  END IF;
END
$post$;
