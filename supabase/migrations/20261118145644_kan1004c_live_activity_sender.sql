-- KAN-1004c: the real Android Live Activity sender.
--
-- live_activity_send no longer marks every queued row 'unsent: no credentials'.
--   android: the row stays 'queued', is flagged handoff = true and handed to the edge function send-live-activity by
--            pg_net, the same lane notification_push_dispatch uses for send-push-notification (anon bearer for
--            verify_jwt + x-trigger-secret from vault 'push_trigger_secret', checked by the function).
--   iOS:     'unsent: no credentials' unless live_activity_config.ios_sender_enabled is true (set it once the APNs
--            key is uploaded). The function itself still sends nothing for iOS.
-- Bounds: at most live_activity.dispatch_limit (default 100) direct hand-offs per transaction; a row over the cap,
--   or one put back for a transient retry, is picked up by live_activity_dispatch() (cron, every minute, 100 per
--   post, oldest first). Old rows are never replayed: only rows with handoff = true (set from now on) are dispatched.
-- Outcomes (function -> live_activity_record_result / live_activity_retry):
--   sent | token_rejected (UNREGISTERED / token INVALID_ARGUMENT: session stale) | failed (error_class, attempts)
--   transient (5xx, 429, network): attempts + 1 and back to the queue until 3 attempts, then failed.
-- live_activity_sends / live_activity_config: RLS on, no client grants. The FCM token never leaves the server.

-- 0. Pre-image guard ------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.live_activity_send(bigint)'::regprocedure)) <> 'bba0063101bf42e2e71c6977970c6625' THEN
    RAISE EXCEPTION 'kan1004c pre-image mismatch: live_activity_send';
  END IF;
END
$guard$;

-- 1. Columns and config ---------------------------------------------------------------------------------------------
ALTER TABLE public.live_activity_sends
  ADD COLUMN IF NOT EXISTS handoff boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS dispatched_at timestamptz;

CREATE INDEX IF NOT EXISTS live_activity_sends_dispatch_idx
  ON public.live_activity_sends (id) WHERE status = 'queued' AND handoff;

CREATE TABLE IF NOT EXISTS public.live_activity_config (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  ios_sender_enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.live_activity_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.live_activity_config FROM PUBLIC, anon, authenticated;
GRANT SELECT, UPDATE ON public.live_activity_config TO service_role;
INSERT INTO public.live_activity_config (id) VALUES (true) ON CONFLICT DO NOTHING;

-- 2. Hand-off -------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.live_activity_post(p_ids bigint[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_anon text; v_secret text;
BEGIN
  IF p_ids IS NULL OR cardinality(p_ids) = 0 THEN RETURN; END IF;
  SELECT decrypted_secret INTO v_anon FROM vault.decrypted_secrets WHERE name = 'supabase_anon_key' LIMIT 1;
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'push_trigger_secret' LIMIT 1;
  IF v_anon IS NULL OR v_secret IS NULL THEN
    RAISE WARNING 'live_activity_post: vault secret missing';
    RETURN;
  END IF;
  UPDATE public.live_activity_sends SET dispatched_at = now() WHERE id = ANY (p_ids);
  PERFORM net.http_post(
    url     := 'https://wtncuzcskpigqpmnxwws.supabase.co/functions/v1/send-live-activity',
    body    := jsonb_build_object('send_ids', to_jsonb(p_ids)),
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'Authorization', 'Bearer ' || v_anon,
                                  'x-trigger-secret', v_secret));
END;
$function$;

CREATE OR REPLACE FUNCTION public.live_activity_send(p_send_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE s record; v_n int; v_limit int;
BEGIN
  SELECT x.id, ss.status, ss.platform, ss.push_token INTO s
    FROM public.live_activity_sends x JOIN public.live_activity_sessions ss ON ss.id = x.session_id
   WHERE x.id = p_send_id AND x.status = 'queued' FOR UPDATE OF x;
  IF s.id IS NULL THEN RETURN false; END IF;
  IF s.platform = 'android'
     OR (s.platform = 'iOS' AND coalesce((SELECT c.ios_sender_enabled FROM public.live_activity_config c), false)) THEN
    UPDATE public.live_activity_sends SET handoff = true WHERE id = p_send_id;
    v_n := coalesce(nullif(current_setting('live_activity.dispatched', true), '')::int, 0);
    v_limit := coalesce(nullif(current_setting('live_activity.dispatch_limit', true), '')::int, 100);
    IF v_n < v_limit THEN
      PERFORM set_config('live_activity.dispatched', (v_n + 1)::text, true);
      PERFORM public.live_activity_post(ARRAY[p_send_id]);
    END IF;                                -- over the cap: live_activity_dispatch picks it up
    RETURN true;
  END IF;
  UPDATE public.live_activity_sends SET status = 'unsent: no credentials', result_at = now() WHERE id = p_send_id;
  RETURN false;
END;
$function$;

-- Picks up rows over the per-transaction cap and transient retries. One post of at most 100 ids per run.
CREATE OR REPLACE FUNCTION public.live_activity_dispatch()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ids bigint[];
BEGIN
  SELECT array_agg(id ORDER BY id) INTO v_ids FROM (
    SELECT id FROM public.live_activity_sends
     WHERE status = 'queued' AND handoff
       AND (dispatched_at IS NULL OR dispatched_at < now() - interval '5 minutes')
     ORDER BY id LIMIT 100 FOR UPDATE SKIP LOCKED) q;
  PERFORM public.live_activity_post(v_ids);
  RETURN coalesce(cardinality(v_ids), 0);
END;
$function$;

-- Transient failure: back to the queue, or failed after 3 attempts.
CREATE OR REPLACE FUNCTION public.live_activity_retry(p_send_id bigint, p_error_class text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.live_activity_sends
     SET attempts = attempts + 1, error_class = p_error_class, dispatched_at = NULL,
         status = CASE WHEN attempts + 1 >= 3 THEN 'failed' ELSE 'queued' END,
         result_at = CASE WHEN attempts + 1 >= 3 THEN now() ELSE result_at END
   WHERE id = p_send_id AND status = 'queued';
END;
$function$;

-- The function counts every attempt it makes, including the last one.
CREATE OR REPLACE FUNCTION public.live_activity_note_attempt(p_send_id bigint)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  UPDATE public.live_activity_sends SET attempts = attempts + 1 WHERE id = p_send_id AND status = 'queued';
$function$;

DO $acl$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.live_activity_post(bigint[])', 'public.live_activity_send(bigint)',
                           'public.live_activity_dispatch()', 'public.live_activity_retry(bigint,text)',
                           'public.live_activity_note_attempt(bigint)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END
$acl$;
GRANT EXECUTE ON FUNCTION public.live_activity_record_result(bigint,text,text) TO service_role;
GRANT SELECT ON public.live_activity_sends, public.live_activity_sessions TO service_role;

SELECT cron.schedule('kan1004c_live_activity_dispatch', '* * * * *', 'SELECT public.live_activity_dispatch()');

-- 3. Post-assert ----------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure::text f, pg_get_userbyid(p.proowner) o, p.prosecdef d, p.proconfig c, p.proacl a
             FROM pg_proc p WHERE p.oid IN ('public.live_activity_post(bigint[])'::regprocedure,
               'public.live_activity_send(bigint)'::regprocedure, 'public.live_activity_dispatch()'::regprocedure,
               'public.live_activity_retry(bigint,text)'::regprocedure,
               'public.live_activity_note_attempt(bigint)'::regprocedure) LOOP
    IF r.o <> 'postgres' OR NOT r.d OR r.c IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN
      RAISE EXCEPTION 'kan1004c post-assert attributes: %', r.f;
    END IF;
    IF r.a::text ~ '(^|[{,])(=|anon=|authenticated=)' THEN RAISE EXCEPTION 'kan1004c post-assert acl: % %', r.f, r.a; END IF;
  END LOOP;
  IF has_table_privilege('authenticated', 'public.live_activity_sends', 'SELECT')
     OR has_table_privilege('anon', 'public.live_activity_sends', 'SELECT')
     OR has_table_privilege('authenticated', 'public.live_activity_config', 'SELECT') THEN
    RAISE EXCEPTION 'kan1004c post-assert: client can read the queue';
  END IF;
END
$post$;
