-- Applied to live DB on 2026-07-11 (migration: broadcast_inapp_persistence).
-- Broadcasts previously went out only as an FCM topic push and never appeared
-- in the in-app feed. Adds an in-app-only kind plus a service-role fan-out RPC
-- that the broadcast-notification edge function calls after the topic send.
--
-- IMPORTANT: default_channels is {inapp} ONLY. The push already went out via
-- the FCM topic; if this kind included 'push', trg_push_on_notification_insert
-- would fire one net.http_post per user (double delivery + request storm).

INSERT INTO public.notification_kinds (key, label_en, label_ar, default_priority, default_channels, route_template, is_active)
VALUES ('system.announcement', 'Announcement', 'إعلان', 'normal', '{inapp}'::notify_channel[], NULL, true)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.rpc_broadcast_inapp_notification(
  p_title text,
  p_body  text,
  p_route text DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_inserted integer;
BEGIN
  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RAISE EXCEPTION 'title is required';
  END IF;

  INSERT INTO public.notifications (to_user_id, kind_key, title, body, action_route, context, priority)
  SELECT p.user_id,
         'system.announcement',
         p_title,
         p_body,
         p_route,
         jsonb_build_object('broadcast', true),
         'normal'
  FROM public.profiles p
  WHERE p.is_active = true;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN v_inserted;
END;
$$;

-- Service-role only: the edge function enforces admin, clients must not call this.
REVOKE ALL ON FUNCTION public.rpc_broadcast_inapp_notification(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_broadcast_inapp_notification(text, text, text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_broadcast_inapp_notification(text, text, text) TO service_role;
