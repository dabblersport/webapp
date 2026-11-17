-- KAN-974 follow-up (PEER review comment 16411).
--
-- 1. Blocking: `authenticated` held table-level UPDATE on notifications, so a user could rewrite their own row's
--    dedupe_key (or kind_key, title, ...) and make notify_v2 treat, e.g., a security notice as already sent.
--    Table UPDATE is revoked; UPDATE is granted back on the four columns clients write:
--    is_read, read_at (markAsRead / markAllRead in notifications_repository_impl.dart, direct PostgREST update) and
--    clicked_at, interaction_count (increment_notification_interaction, SECURITY INVOKER).
--    mark_notification_read and rpc_notification_clicked are SECURITY DEFINER and unaffected.
-- 2. notify_v2_render substitutes each placeholder value as a literal in one left-to-right pass; a value that itself
--    contains "{title}" is no longer expanded.
-- 3. notify_v2: the fallback actor name in context.actor_display_name follows the recipient language ("شخص ما").
--    Rebuilt from pg_get_functiondef on the live catalogue (md5 4207c7ee80808e2b470191fc053795db) with only that
--    change; CREATE OR REPLACE keeps the proacl (service_role only).

-- Pre-image guard ----------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)'::regprocedure))
       <> '4207c7ee80808e2b470191fc053795db' THEN
    RAISE EXCEPTION 'kan974b pre-image: notify_v2 changed since KAN-974';
  END IF;
  IF md5(pg_get_functiondef('public.notify_v2_render(text,jsonb,text)'::regprocedure))
       <> 'a7302c8e7b5196963e99840e177f4bb0' THEN
    RAISE EXCEPTION 'kan974b pre-image: notify_v2_render changed since KAN-974';
  END IF;
  IF (SELECT relacl::text FROM pg_class WHERE oid = 'public.notifications'::regclass)
       <> '{postgres=arwdDxtm/postgres,anon=rm/postgres,authenticated=rwm/postgres,service_role=arwdDxtm/postgres}' THEN
    RAISE EXCEPTION 'kan974b pre-image: notifications table ACL is not the expected one';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.notifications'::regclass AND attacl IS NOT NULL) THEN
    RAISE EXCEPTION 'kan974b pre-image: notifications already has column-level grants';
  END IF;
END
$guard$;

-- 1. Column-scoped UPDATE for clients --------------------------------------------------------------------------------
REVOKE UPDATE ON public.notifications FROM authenticated;
GRANT UPDATE (is_read, read_at, clicked_at, interaction_count) ON public.notifications TO authenticated;

-- 2. Literal, single-pass renderer -----------------------------------------------------------------------------------
-- {key} -> args->>(key || '_' || lang), else args->>key, else ''. Values are appended to the output and never
-- rescanned. When a placeholder renders empty, one of the two spaces around it is dropped.
CREATE OR REPLACE FUNCTION public.notify_v2_render(p_template text, p_args jsonb, p_lang text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_args jsonb := COALESCE(p_args, '{}'::jsonb);
  v_rest text  := p_template;
  v_out  text  := '';
  v_val  text;
  m      text[];
  pos    int;
BEGIN
  IF p_template IS NULL THEN
    RETURN NULL;
  END IF;
  LOOP
    m := regexp_match(v_rest, '\{([A-Za-z_][A-Za-z0-9_]*)\}');
    EXIT WHEN m IS NULL;
    pos := position('{' || m[1] || '}' IN v_rest);      -- first occurrence = leftmost regex match
    v_val := COALESCE(v_args ->> (m[1] || '_' || p_lang), v_args ->> m[1], '');
    v_out := v_out || left(v_rest, pos - 1);
    v_rest := substr(v_rest, pos + length(m[1]) + 2);
    IF v_val = '' AND right(v_out, 1) = ' ' AND left(v_rest, 1) = ' ' THEN
      v_rest := substr(v_rest, 2);
    END IF;
    v_out := v_out || v_val;
  END LOOP;
  RETURN NULLIF(btrim(v_out || v_rest), '');
END;
$function$;

-- 3. notify_v2: language-aware fallback actor name in context --------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_v2(
  p_to_user_id      uuid,
  p_kind_key        text,
  p_args            jsonb DEFAULT '{}'::jsonb,
  p_entity_type     text  DEFAULT NULL,
  p_entity_id       uuid  DEFAULT NULL,
  p_actor_user_id   uuid  DEFAULT NULL,
  p_source_event_id text  DEFAULT NULL,
  p_dedupe_key      text  DEFAULT NULL,
  p_group_key       text  DEFAULT NULL,
  p_action_route    text  DEFAULT NULL
)
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

  -- "Turn off notifications like this": a muted kind writes nothing, unless the kind cannot be muted
  IF v_kind.can_mute AND EXISTS (
       SELECT 1 FROM public.notification_settings s
        WHERE s.user_id = p_to_user_id AND p_kind_key = ANY (COALESCE(s.muted_kinds, '{}'::text[]))) THEN
    RETURN NULL;
  END IF;

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

  -- Aggregation stays as it is (KAN-980 owns it): a kind with an enabled rule is handed to the existing path.
  IF EXISTS (SELECT 1 FROM public.notification_aggregation_rules r
              WHERE r.kind_key = p_kind_key AND r.enabled = true) THEN
    PERFORM public.process_notification_event(p_to_user_id, p_kind_key, p_entity_type, p_entity_id,
                                              p_actor_user_id, v_title, v_body);
    RETURN NULL;
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

-- Post-image guard ---------------------------------------------------------------------------------------------------
DO $post$
DECLARE c text;
BEGIN
  IF has_table_privilege('authenticated', 'public.notifications', 'UPDATE') THEN
    RAISE EXCEPTION 'kan974b post-image: authenticated still has table-level UPDATE';
  END IF;
  SELECT string_agg(attname, ',' ORDER BY attname) INTO c FROM pg_attribute
   WHERE attrelid = 'public.notifications'::regclass AND attnum > 0 AND NOT attisdropped
     AND has_column_privilege('authenticated', 'public.notifications', attname, 'UPDATE');
  IF c IS DISTINCT FROM 'clicked_at,interaction_count,is_read,read_at' THEN
    RAISE EXCEPTION 'kan974b post-image: authenticated UPDATE columns are %', c;
  END IF;
  IF NOT has_table_privilege('authenticated', 'public.notifications', 'SELECT') THEN
    RAISE EXCEPTION 'kan974b post-image: authenticated lost SELECT';
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan974b post-image: notify_v2 proacl changed';
  END IF;
  IF public.notify_v2_render('{a} and {b}', '{"a":"{b}","b":"x"}', 'en') <> '{b} and x' THEN
    RAISE EXCEPTION 'kan974b post-image: renderer still expands values';
  END IF;
END
$post$;
