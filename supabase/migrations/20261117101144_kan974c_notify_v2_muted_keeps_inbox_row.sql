-- KAN-974 follow-up (coordinator ruling, design PUSH-12): a muted kind sends no push but still appears in the inbox.
--
-- notify_v2 no longer returns early for a muted kind. The row is written as for any other kind, and
-- trg_push_on_notification_insert (KAN-979) skips the push through notification_push_enabled ->
-- notification_channel_enabled (muted_kinds). Block and inactive-kind skips are unchanged.
--
-- Rebuilt from pg_get_functiondef on the live catalogue. The pre-image is md5 f770635f99a40d18e1e3ade0bc250b6a,
-- which already carries KAN-980's aggregation hand-off (notification_aggregate_add, migration 20261117100750); the
-- md5 5310b3d7... named in the brief is the KAN-974b version, replaced by KAN-980. Only the mute block is removed.
-- CREATE OR REPLACE keeps the proacl (service_role only).

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)'::regprocedure))
       <> 'f770635f99a40d18e1e3ade0bc250b6a' THEN
    RAISE EXCEPTION 'kan974c pre-image: notify_v2 changed since it was read';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.notify_v2(p_to_user_id uuid, p_kind_key text, p_args jsonb DEFAULT '{}'::jsonb, p_entity_type text DEFAULT NULL::text, p_entity_id uuid DEFAULT NULL::uuid, p_actor_user_id uuid DEFAULT NULL::uuid, p_source_event_id text DEFAULT NULL::text, p_dedupe_key text DEFAULT NULL::text, p_group_key text DEFAULT NULL::text, p_action_route text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_kind   public.notification_kinds%ROWTYPE;
  v_args   jsonb := COALESCE(p_args, '{}'::jsonb);
  v_lang   text;
  v_actor  text;
  v_title  text;
  v_body   text;
  v_route  text;
  v_id     uuid;
BEGIN
  IF p_to_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '22004', message = 'notify_v2: recipient is required';
  END IF;
  IF p_dedupe_key IS NULL OR btrim(p_dedupe_key) = '' THEN
    RAISE EXCEPTION USING errcode = '22004', message = 'notify_v2: dedupe_key is required';
  END IF;
  IF jsonb_typeof(v_args) <> 'object' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'notify_v2: args must be a jsonb object';
  END IF;

  SELECT * INTO v_kind FROM public.notification_kinds WHERE key = p_kind_key;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = '22023', message = format('notify_v2: unknown kind %s', p_kind_key);
  END IF;

  -- inactive kind: nothing is written (each producer ticket activates its own kind)
  IF NOT v_kind.is_active THEN
    RETURN NULL;
  END IF;

  -- block, either direction, between the actor and the recipient
  IF p_actor_user_id IS NOT NULL AND p_actor_user_id <> p_to_user_id AND EXISTS (
       SELECT 1 FROM public.user_blocks b
        WHERE (b.blocker_user_id = p_to_user_id AND b.blocked_user_id = p_actor_user_id)
           OR (b.blocker_user_id = p_actor_user_id AND b.blocked_user_id = p_to_user_id)) THEN
    RETURN NULL;
  END IF;

  -- KAN-974c (design PUSH-12): a muted kind still writes the inbox row; the push trigger skips its push.

  -- recipient's language: the active profile's language, then user_settings.locale, then English
  SELECT CASE WHEN lower(left(COALESCE(
                 (SELECT p.language FROM public.profiles p
                   WHERE p.user_id = p_to_user_id AND p.language IS NOT NULL
                   ORDER BY p.is_active DESC NULLS LAST, p.updated_at DESC NULLS LAST LIMIT 1),
                 (SELECT us.locale FROM public.user_settings us WHERE us.user_id = p_to_user_id),
                 'en'), 2)) = 'ar' THEN 'ar' ELSE 'en' END
    INTO v_lang;

  -- actor display name, unless the producer passed one
  IF p_actor_user_id IS NOT NULL THEN
    SELECT p.display_name INTO v_actor FROM public.profiles p
     WHERE p.user_id = p_actor_user_id AND p.is_active = true
     ORDER BY p.updated_at DESC NULLS LAST LIMIT 1;
  END IF;
  IF NOT (v_args ? 'actor') THEN
    v_args := v_args || jsonb_build_object('actor',
                COALESCE(v_actor, CASE WHEN v_lang = 'ar' THEN 'شخص ما' ELSE 'Someone' END));
  END IF;

  v_title := public.notify_v2_render(
               CASE WHEN v_lang = 'ar' THEN v_kind.title_template_ar ELSE v_kind.title_template_en END, v_args, v_lang);
  v_body  := public.notify_v2_render(
               CASE WHEN v_lang = 'ar' THEN v_kind.body_template_ar ELSE v_kind.body_template_en END, v_args, v_lang);
  v_title := COALESCE(v_title, CASE WHEN v_lang = 'ar' THEN v_kind.label_ar ELSE v_kind.label_en END);

  -- same deep links as process_notification_event when the producer passes none
  v_route := COALESCE(p_action_route, CASE
    WHEN p_entity_type = 'game' AND p_entity_id IS NOT NULL THEN
      '/sports/games/' || p_entity_id::text || CASE WHEN p_kind_key = 'game.join_request' THEN '?focus=requests' ELSE '' END
    WHEN p_entity_type = 'meetup' AND p_entity_id IS NOT NULL THEN
      '/meetups/' || p_entity_id::text ||
      CASE WHEN p_kind_key IN ('meetup.request_received', 'meetup.rsvp_received') THEN '/manage' ELSE '' END
    ELSE NULL END);

  -- KAN-980: a kind with an enabled rule grows one row per group for the rule's window (1 hour).
  IF EXISTS (SELECT 1 FROM public.notification_aggregation_rules r
              WHERE r.kind_key = p_kind_key AND r.enabled = true) THEN
    RETURN public.notification_aggregate_add(p_to_user_id, p_kind_key, p_entity_type, p_entity_id,
                                             p_actor_user_id, p_args, v_lang, p_action_route, p_source_event_id);
  END IF;

  INSERT INTO public.notifications (
    to_user_id, kind_key, title, body, action_route, context, priority, is_read, created_at,
    template_key, args, source_event_id, dedupe_key, group_key, schema_version)
  VALUES (
    p_to_user_id, p_kind_key, v_title, v_body, v_route,
    jsonb_build_object('entity_type', p_entity_type, 'entity_id', p_entity_id,
                       'actor_user_id', p_actor_user_id,
                       'actor_display_name', COALESCE(v_actor, CASE WHEN v_lang = 'ar' THEN 'شخص ما' ELSE 'Someone' END)),
    v_kind.default_priority, false, now(),
    v_kind.key, v_args, p_source_event_id, p_dedupe_key, p_group_key, 2)
  ON CONFLICT (to_user_id, dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT n.id INTO v_id FROM public.notifications n
     WHERE n.to_user_id = p_to_user_id AND n.dedupe_key = p_dedupe_key;
  END IF;

  RETURN v_id;
END;
$function$;

DO $post$
DECLARE d text := pg_get_functiondef('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)'::regprocedure);
BEGIN
  IF d LIKE '%muted_kinds%' THEN
    RAISE EXCEPTION 'kan974c post-image: notify_v2 still reads muted_kinds';
  END IF;
  IF d NOT LIKE '%notification_aggregate_add%' THEN
    RAISE EXCEPTION 'kan974c post-image: KAN-980 aggregation hand-off lost';
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan974c post-image: notify_v2 proacl changed';
  END IF;
END
$post$;
