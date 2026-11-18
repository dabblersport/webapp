-- KAN-1004d: Live Activity sender fixes after PEER review of KAN-1004c.
--
-- 1. Claim. send-live-activity no longer reads queued rows; it calls live_activity_claim(ids) (service only), which
--    atomically moves at most 20 'queued' rows (not_before passed) to 'sending', stamps claimed_at and counts the
--    attempt (attempts + 1). The function sends only what the claim returned. A second claim of the same ids
--    returns nothing. Every post (direct or dispatch) carries at most 20 ids.
--    Crash recovery: live_activity_dispatch() puts rows stuck in 'sending' longer than 5 minutes back to 'queued'
--    (or 'failed' once attempts reach 3). DUPLICATES ARE POSSIBLE after a crash (FCM accepted, the result was never
--    recorded); they are harmless because the client applies a payload only if its state_version is newer than the
--    one it shows.
-- 2. Backoff. live_activity_retry (row in 'sending') schedules not_before = now() + 1 min after attempt 1,
--    5 min after attempt 2 (15 min for any later attempt); after 3 attempts the row is 'failed'. dispatch skips rows
--    whose not_before is in the future.
-- 3. The attempt is counted at claim time, so an invocation that dies is still bounded by 3.
-- 4. Inactive sessions: the claim marks rows whose session is not 'active' (stale, ended, opted out) 'skipped'
--    and does not return them.
-- 5. Android TTL: the stored payload's android block carries ttl "3600s" and collapse_key "la:<session_id>".

-- 0. Pre-image guards -----------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.live_activity_post(bigint[])'::regprocedure)) <> '4b2255d37981d2bb83a7f13193a6d82e'
  OR md5(pg_get_functiondef('public.live_activity_dispatch()'::regprocedure)) <> '95185e2d5cce5de96211a0683441d760'
  OR md5(pg_get_functiondef('public.live_activity_retry(bigint,text)'::regprocedure)) <> '643da3d6d0da7c3999a11f0f910468e3'
  OR md5(pg_get_functiondef('public.live_activity_enqueue(uuid,text,text,jsonb)'::regprocedure)) <> '3b2dfa9242a1c8b0d94be4798f1eeca8'
  THEN RAISE EXCEPTION 'kan1004d pre-image mismatch'; END IF;
END
$guard$;

-- 1. Columns and statuses -------------------------------------------------------------------------------------------
ALTER TABLE public.live_activity_sends
  ADD COLUMN IF NOT EXISTS claimed_at timestamptz,
  ADD COLUMN IF NOT EXISTS not_before timestamptz;
ALTER TABLE public.live_activity_sends DROP CONSTRAINT live_activity_sends_status_check;
ALTER TABLE public.live_activity_sends ADD CONSTRAINT live_activity_sends_status_check CHECK (status = ANY (ARRAY[
  'queued', 'sending', 'skipped', 'unsent: no credentials', 'unsent: no token', 'unsent: stale', 'sent',
  'token_rejected', 'gone', 'failed']));
CREATE INDEX IF NOT EXISTS live_activity_sends_sending_idx
  ON public.live_activity_sends (claimed_at) WHERE status = 'sending';

-- 2. Claim ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.live_activity_claim(p_ids bigint[])
 RETURNS TABLE(id bigint, session_id uuid, payload jsonb, user_id uuid, installation_id text, platform text, attempts integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ids bigint[];
BEGIN
  SELECT array_agg(q.id ORDER BY q.id) INTO v_ids
    FROM (SELECT x.id FROM public.live_activity_sends x
           WHERE x.id = ANY (p_ids) AND x.status = 'queued' AND (x.not_before IS NULL OR x.not_before <= now())
           ORDER BY x.id LIMIT 20 FOR UPDATE SKIP LOCKED) q;
  IF v_ids IS NULL THEN RETURN; END IF;
  -- inactive session: never sent
  UPDATE public.live_activity_sends x SET status = 'skipped', error_class = 'session_' || ss.status, result_at = now()
    FROM public.live_activity_sessions ss
   WHERE ss.id = x.session_id AND x.id = ANY (v_ids) AND x.status = 'queued' AND ss.status <> 'active';
  RETURN QUERY
  WITH c AS (
    UPDATE public.live_activity_sends x SET status = 'sending', claimed_at = now(), attempts = x.attempts + 1
     WHERE x.id = ANY (v_ids) AND x.status = 'queued' AND (x.not_before IS NULL OR x.not_before <= now())
    RETURNING x.id, x.session_id, x.payload, x.attempts)
  SELECT c.id, c.session_id, c.payload, ss.user_id, ss.installation_id, ss.platform, c.attempts
    FROM c JOIN public.live_activity_sessions ss ON ss.id = c.session_id ORDER BY c.id;
END;
$function$;

-- 3. Post: one request per 20 ids -----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.live_activity_post(p_ids bigint[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_anon text; v_secret text; i int;
BEGIN
  IF p_ids IS NULL OR cardinality(p_ids) = 0 THEN RETURN; END IF;
  SELECT decrypted_secret INTO v_anon FROM vault.decrypted_secrets WHERE name = 'supabase_anon_key' LIMIT 1;
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'push_trigger_secret' LIMIT 1;
  IF v_anon IS NULL OR v_secret IS NULL THEN
    RAISE WARNING 'live_activity_post: vault secret missing';
    RETURN;
  END IF;
  UPDATE public.live_activity_sends SET dispatched_at = now() WHERE id = ANY (p_ids);
  i := 1;
  WHILE i <= cardinality(p_ids) LOOP
    PERFORM net.http_post(
      url     := 'https://wtncuzcskpigqpmnxwws.supabase.co/functions/v1/send-live-activity',
      body    := jsonb_build_object('send_ids', to_jsonb(p_ids[i:i + 19])),
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'Authorization', 'Bearer ' || v_anon,
                                    'x-trigger-secret', v_secret));
    i := i + 20;
  END LOOP;
END;
$function$;

-- 4. Dispatch: recover stuck claims, respect not_before and the 5-minute re-post window ----------------------------
CREATE OR REPLACE FUNCTION public.live_activity_dispatch()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ids bigint[];
BEGIN
  UPDATE public.live_activity_sends
     SET status = CASE WHEN attempts >= 3 THEN 'failed' ELSE 'queued' END,
         error_class = CASE WHEN attempts >= 3 THEN 'claim_timeout' ELSE error_class END,
         result_at = CASE WHEN attempts >= 3 THEN now() ELSE result_at END,
         dispatched_at = NULL, claimed_at = NULL
   WHERE status = 'sending' AND claimed_at < now() - interval '5 minutes';
  SELECT array_agg(id ORDER BY id) INTO v_ids FROM (
    SELECT id FROM public.live_activity_sends
     WHERE status = 'queued' AND handoff
       AND (not_before IS NULL OR not_before <= now())
       AND (dispatched_at IS NULL OR dispatched_at < now() - interval '5 minutes')
     ORDER BY id LIMIT 100 FOR UPDATE SKIP LOCKED) q;
  PERFORM public.live_activity_post(v_ids);
  RETURN coalesce(cardinality(v_ids), 0);
END;
$function$;

-- 5. Retry with backoff ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.live_activity_retry(p_send_id bigint, p_error_class text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.live_activity_sends
     SET error_class = p_error_class, dispatched_at = NULL, claimed_at = NULL,
         status = CASE WHEN attempts >= 3 THEN 'failed' ELSE 'queued' END,
         result_at = CASE WHEN attempts >= 3 THEN now() ELSE result_at END,
         not_before = CASE WHEN attempts >= 3 THEN not_before
                           ELSE now() + CASE attempts WHEN 1 THEN interval '1 minute' WHEN 2 THEN interval '5 minutes'
                                                      ELSE interval '15 minutes' END END
   WHERE id = p_send_id AND status = 'sending';
END;
$function$;

-- 6. Enqueue: android ttl + collapse key, edited from the live definition -------------------------------------------
DO $enq$
DECLARE d text; d2 text;
BEGIN
  d := pg_get_functiondef('public.live_activity_enqueue(uuid,text,text,jsonb)'::regprocedure);
  d2 := replace(d, $o$jsonb_build_object('android', jsonb_build_object('priority', 'high'),$o$,
    $n$jsonb_build_object('android', jsonb_build_object('priority', 'high', 'ttl', '3600s', 'collapse_key', 'la:' || s.id::text),$n$);
  IF d2 = d THEN RAISE EXCEPTION 'kan1004d: enqueue android payload not found'; END IF;
  EXECUTE d2;
END
$enq$;

DO $acl$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.live_activity_claim(bigint[])', 'public.live_activity_post(bigint[])',
                           'public.live_activity_dispatch()', 'public.live_activity_retry(bigint,text)',
                           'public.live_activity_enqueue(uuid,text,text,jsonb)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END
$acl$;

-- 7. Post-assert ----------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record; t text; p text;
BEGIN
  FOR r IN SELECT p.oid::regprocedure::text f, pg_get_userbyid(p.proowner) o, p.prosecdef d, p.proconfig c, p.proacl::text a
             FROM pg_proc p WHERE p.oid IN ('public.live_activity_claim(bigint[])'::regprocedure,
               'public.live_activity_post(bigint[])'::regprocedure, 'public.live_activity_dispatch()'::regprocedure,
               'public.live_activity_retry(bigint,text)'::regprocedure, 'public.live_activity_send(bigint)'::regprocedure,
               'public.live_activity_enqueue(uuid,text,text,jsonb)'::regprocedure,
               'public.live_activity_record_result(bigint,text,text)'::regprocedure) LOOP
    IF r.o <> 'postgres' OR NOT r.d OR r.c IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN
      RAISE EXCEPTION 'kan1004d post-assert attributes: %', r.f;
    END IF;
    IF r.a IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN
      RAISE EXCEPTION 'kan1004d post-assert acl: % %', r.f, r.a;
    END IF;
  END LOOP;
  FOREACH t IN ARRAY ARRAY['public.live_activity_sends', 'public.live_activity_sessions', 'public.live_activity_config'] LOOP
    FOREACH p IN ARRAY ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE'] LOOP
      IF has_table_privilege('anon', t, p) OR has_table_privilege('authenticated', t, p) THEN
        RAISE EXCEPTION 'kan1004d post-assert: client % on %', p, t;
      END IF;
    END LOOP;
  END LOOP;
  IF (SELECT count(*) FROM cron.job WHERE jobname IN ('kan1004c_live_activity_dispatch', 'kan1004_live_activity_every_minute')
        AND active) <> 2 THEN
    RAISE EXCEPTION 'kan1004d post-assert: cron jobs missing';
  END IF;
END
$post$;
