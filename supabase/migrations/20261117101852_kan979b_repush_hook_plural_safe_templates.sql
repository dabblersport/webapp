-- KAN-979 follow-up (coordinator, 2026-11-17; interface in Jira KAN-979 comment 16429 from KAN-980).
--
-- 1. notification_push_dispatch(p_notification_id, p_repush): the one place a notifications row becomes a push.
--    trg_push_on_notification_insert now calls it (behaviour unchanged, rebuilt from the live definition md5
--    ed19e052327bd7583e4b32841af6e7b3); the new hook notification_repush(uuid) calls it with p_repush = true.
-- 2. notification_repush(p_notification_id) RETURNS void, SECURITY DEFINER, service_role only. Called by KAN-980's
--    flush_notification_aggregates for a grouped row that grew. It re-sends the row's current title/body with
--    collapse/thread id = group_key so it replaces the group's earlier push, with no sound (silent mode:
--    dabbler_quiet, iOS passive, never time-sensitive). Same gate as the first push (master switch, muted kinds,
--    category flags, activities rule, push channel on the kind). Blocked or missing row: sends nothing, never raises.
--    One notification_deliveries row per device comes from send-push-notification v14 as for any push.
-- 3. Plural-safe templates for the grouped kinds (rendered by KAN-980 with {actor} = "Sara and 2 others" /
--    «سارة وشخصان آخران»). EN "is interested" and the Arabic verb/adjective forms that agree with one person are
--    replaced by wording that reads for one or many.

-- 0. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.trg_push_on_notification_insert()'::regprocedure)) <> 'ed19e052327bd7583e4b32841af6e7b3' THEN
    RAISE EXCEPTION 'kan979b pre-image: trg_push_on_notification_insert changed';
  END IF;
  IF to_regproc('public.notification_repush') IS NOT NULL OR to_regproc('public.notification_push_dispatch') IS NOT NULL THEN
    RAISE EXCEPTION 'kan979b pre-image: repush or dispatch already exists';
  END IF;
  IF (SELECT title_template_en FROM public.notification_kinds WHERE key = 'meetup.rsvp_interested') <> '{actor} is interested in {title}'
     OR (SELECT title_template_ar FROM public.notification_kinds WHERE key = 'social.post_liked') <> '{actor} أعجبه منشورك' THEN
    RAISE EXCEPTION 'kan979b pre-image: grouped-kind templates changed';
  END IF;
END
$guard$;

-- 1. Dispatch --------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.notification_push_dispatch(p_notification_id uuid, p_repush boolean DEFAULT false)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  n public.notifications%ROWTYPE;
  _kind public.notification_kinds%ROWTYPE;
  _anon_key text;
  _trigger_secret text;
  _entity_type text;
  _entity_id text;
  _breaks boolean;
  _quiet boolean;
  _collapse text;
  _badge int;
  _body text;
  _snippet text;
BEGIN
  SELECT * INTO n FROM public.notifications WHERE id = p_notification_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  _entity_type := NULLIF(n.context->>'entity_type', '');
  _entity_id := NULLIF(n.context->>'entity_id', '');
  _body := COALESCE(n.body, '');

  -- Only proceed for kinds whose default channels include push.
  SELECT * INTO _kind FROM public.notification_kinds WHERE key = n.kind_key;
  IF NOT FOUND OR _kind.default_channels IS NULL OR NOT ('push' = ANY(_kind.default_channels)) THEN
    RETURN false;
  END IF;

  -- Per-user push gate: master switch, muted kinds, category flags (activities follow games / meetups by entity).
  -- Security kinds are always on. The in-app row is never touched here.
  IF NOT public.notification_push_enabled(n.to_user_id, n.kind_key, _entity_type) THEN
    RETURN false;
  END IF;

  IF p_repush THEN
    -- KAN-980 growth re-push: replaces the group's push, no sound, never time-sensitive.
    _breaks := false;
    _quiet := true;
  ELSE
    -- KAN-979, I-2 / I-3: quiet hours deliver silently; breaks_quiet and security kinds alert and are time-sensitive.
    _breaks := COALESCE(_kind.breaks_quiet, false) OR public.notification_kind_is_unmutable(n.kind_key);
    _quiet := NOT _breaks AND public.is_quiet_hour(n.to_user_id, now());
  END IF;

  _collapse := CASE WHEN n.group_key IS NULL THEN NULL
                    WHEN octet_length(n.group_key) <= 64 THEN n.group_key
                    ELSE md5(n.group_key) END;

  SELECT count(*)::int INTO _badge FROM public.notifications x WHERE x.to_user_id = n.to_user_id AND NOT x.is_read;

  -- KAN-984 hook: the message snippet travels in the push only. The producer sets it transaction-locally right before
  -- inserting the row; it is consumed once by the insert push and never stored in notifications.
  IF _kind.category = 'messages' AND NOT p_repush THEN
    _snippet := NULLIF(current_setting('dabbler.push_body', true), '');
    IF _snippet IS NOT NULL THEN
      _body := _snippet;
      PERFORM set_config('dabbler.push_body', '', true);
    END IF;
  END IF;

  SELECT decrypted_secret INTO _anon_key FROM vault.decrypted_secrets WHERE name = 'supabase_anon_key' LIMIT 1;
  IF _anon_key IS NULL THEN
    RAISE WARNING 'notification_push_dispatch: supabase_anon_key not found in vault';
    RETURN false;
  END IF;
  SELECT decrypted_secret INTO _trigger_secret FROM vault.decrypted_secrets WHERE name = 'push_trigger_secret' LIMIT 1;
  IF _trigger_secret IS NULL THEN
    RAISE WARNING 'notification_push_dispatch: push_trigger_secret not found in vault';
    RETURN false;
  END IF;

  PERFORM net.http_post(
    url    := 'https://wtncuzcskpigqpmnxwws.supabase.co/functions/v1/send-push-notification',
    body   := jsonb_build_object(
      'user_id',         n.to_user_id,
      'notification_id', n.id,
      'title',           COALESCE(n.title, ''),
      'body',            _body,
      'data',            jsonb_build_object(
        'kind_key',        n.kind_key,
        'action_route',    COALESCE(n.action_route, ''),
        'entity_type',     COALESCE(_entity_type, ''),
        'entity_id',       COALESCE(_entity_id, ''),
        'notification_id', n.id::text,
        'dedupe_key',      COALESCE(n.dedupe_key, ''),
        'group_key',       COALESCE(n.group_key, ''),
        'repush',          CASE WHEN p_repush THEN 'true' ELSE 'false' END
      ) || CASE
        WHEN _entity_type = 'meetup' AND _entity_id IS NOT NULL
        THEN jsonb_build_object('meetup_id', _entity_id)   -- kept for meetupPushRoute in current builds
        ELSE '{}'::jsonb
      END,
      'delivery',        jsonb_build_object(
        'mode',               CASE WHEN _quiet THEN 'silent' ELSE 'alert' END,
        'time_sensitive',     _breaks,
        'android_channel_id', CASE WHEN _quiet THEN 'dabbler_quiet' ELSE 'dabbler_' || COALESCE(_kind.category, 'default') END,
        'ios_category',       public.notification_push_category(n.kind_key),
        'thread_id',          n.group_key,
        'collapse_id',        _collapse,
        'badge',              _badge
      )
    ),
    headers := jsonb_build_object(
      'Content-Type',     'application/json',
      'Authorization',    'Bearer ' || _anon_key,
      'x-trigger-secret', _trigger_secret
    )
  );
  RETURN true;
END;
$function$;

-- 2. The insert trigger delegates to dispatch (same behaviour) -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_push_on_notification_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- KAN-979: the push decision and payload live in notification_push_dispatch (shared with notification_repush).
  PERFORM public.notification_push_dispatch(NEW.id, false);
  RETURN NEW;
END;
$function$;

-- 3. The re-push hook for KAN-980 ------------------------------------------------------------------------------------
CREATE FUNCTION public.notification_repush(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Rows without a group_key have nothing to replace; they are never re-pushed.
  IF EXISTS (SELECT 1 FROM public.notifications WHERE id = p_notification_id AND group_key IS NOT NULL) THEN
    PERFORM public.notification_push_dispatch(p_notification_id, true);
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.notification_push_dispatch(uuid, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_push_dispatch(uuid, boolean) TO service_role;
REVOKE ALL ON FUNCTION public.notification_repush(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_repush(uuid) TO service_role;

-- 4. Plural-safe templates for the grouped kinds ---------------------------------------------------------------------
UPDATE public.notification_kinds k
   SET title_template_en = v.t_en, title_template_ar = v.t_ar, body_template_ar = COALESCE(v.b_ar, k.body_template_ar)
  FROM (VALUES
    ('meetup.rsvp_interested', '{actor} showed interest in {title}', 'اهتمام بـ {title} من {actor}', NULL),
    ('social.post_liked',      '{actor} liked your post',            'إعجاب بمنشورك من {actor}',    NULL),
    ('social.post_reacted',    '{actor} reacted to your post',       'تفاعل مع منشورك من {actor}',  NULL),
    ('social.comment_liked',   '{actor} liked your comment',         'إعجاب بتعليقك من {actor}',    NULL),
    ('social.followed',        '{actor} started following you',      'متابعة جديدة من {actor}',     NULL),
    ('social.circle_joined',   '{actor} joined your circle',         'انضمام إلى دائرتك من {actor}', 'قل مرحبًا.')
  ) AS v(key, t_en, t_ar, b_ar)
 WHERE k.key = v.key;

-- 5. Post-image guard ------------------------------------------------------------------------------------------------
DO $post$
DECLARE v text;
BEGIN
  FOR v IN SELECT p.oid::regprocedure::text || ' ' || COALESCE(p.proacl::text, 'null') FROM pg_proc p
            WHERE p.oid IN ('public.notification_push_dispatch(uuid,boolean)'::regprocedure,
                            'public.notification_repush(uuid)'::regprocedure,
                            'public.trg_push_on_notification_insert()'::regprocedure) LOOP
    IF v NOT LIKE '%{postgres=X/postgres,service_role=X/postgres}' THEN
      RAISE EXCEPTION 'kan979b post-image: unexpected proacl %', v;
    END IF;
  END LOOP;
  IF to_regprocedure('public.notification_repush(uuid)') IS NULL THEN
    RAISE EXCEPTION 'kan979b post-image: notification_repush(uuid) missing';
  END IF;
END
$post$;
