-- KAN-980 [W1-B2] Aggregation (Epic KAN-973; plan Dabbler/dabbler-docs/briefs/NOTIFICATIONS_PLAN_2026-11-16.md).
--
-- Decisions: F-6 (group within 1 hour, push at most every 15 minutes, follows grouped, mentions and comments
-- immediate), I-1 (organiser told about an Interested RSVP: in-app only, aggregated, no push), design G-01 (one row
-- that grows; push replaced in place; read -> new actor -> unread again and on top; after 1 hour a new row).
--
-- Model (replaces the 5-second buffer-then-flush model):
--   * A grouped kind (enabled row in notification_aggregation_rules) arrives through notify_v2, which hands it to
--     notification_aggregate_add. The FIRST actor writes a real notifications row at once (dedupe_key 'agg:<id>',
--     group_key '<family>:<entity_type>:<entity_id>'), so trg_push_on_notification_insert (KAN-979) sends the t0 push.
--   * Each further actor inside the window updates that same row in place: title "X and N others ..." rendered from
--     the kind templates in the recipient's language, args, context (actor list, count), is_read = false,
--     read_at = NULL, created_at = event time (moves it to the top). The same person twice counts once.
--   * notification_aggregates keeps the group: actors (newest first), kinds, window (1 hour from the first actor),
--     push_pending and last_push_at for the 15-minute cap.
--   * flush_notification_aggregates (cron, every minute) re-pushes a group whose row changed since its last push,
--     at most once per push_cap_seconds (900), by calling the KAN-979 hook public.notification_repush(uuid) when it
--     exists (interface agreed in Jira comments on KAN-979 and KAN-980). A group closes (is_flushed) when its
--     window has ended and nothing is pending. A new actor after the window starts a new row.
--   * Families: social.post_liked + social.post_reacted share family 'post' (a like and a reaction by the same
--     person on the same post count once; a mixed group uses the post_reacted template). comment_liked, followed,
--     circle_joined and meetup.rsvp_interested each group alone.
--   * Comments and mentions: the social.post_commented rule is removed, so they insert at once on their existing
--     path (process_notification_event, no rule) and are never grouped.
--   * meetup.rsvp_interested (kind default_channels {inapp}, KAN-974) is activated here; a new trigger on
--     meetup_rsvps sends it to the organiser through notify_v2 when a member marks Interested. No push: the kind
--     has no push channel and the rule has push_enabled = false. trg_meetup_rsvps_notify is untouched.
--   * One sender per kind: fn_likes_notify, trg_post_reaction_notify, trg_profile_follow_notify and
--     trg_circle_join_notify now call notify_v2 instead of process_notification_event (replacement authored from the
--     live pg_get_functiondef, with an assertion that the replaced text was found).
--
-- Not touched: trg_push_on_notification_insert, send-push-notification, notification_deliveries (KAN-979);
-- trg_meetup_rsvps_notify; process_notification_event; notifications / notification_kinds columns (KAN-974).
-- Live test: supabase/tests/notifications_v2/kan980_aggregation.sql.

-- 1. pre-image guard --------------------------------------------------------------------------------------------------
DO $pre$
DECLARE v_bad text := '';
BEGIN
  IF md5(pg_get_functiondef('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)'::regprocedure))
       <> '5310b3d74bb3e1c1c6b9277c6804e184' THEN v_bad := v_bad || ' notify_v2'; END IF;
  IF md5(pg_get_functiondef('public.flush_notification_aggregates()'::regprocedure))
       <> '52e59f3dd2ebba3d9b3a715c826d4436' THEN v_bad := v_bad || ' flush_notification_aggregates'; END IF;
  IF md5(pg_get_functiondef('public.fn_likes_notify()'::regprocedure))
       <> '21f61569c1c7dfbbbb8c2107c518124e' THEN v_bad := v_bad || ' fn_likes_notify'; END IF;
  IF md5(pg_get_functiondef('public.trg_post_reaction_notify()'::regprocedure))
       <> '3965a19b3836b2e6f8c3afc862481764' THEN v_bad := v_bad || ' trg_post_reaction_notify'; END IF;
  IF md5(pg_get_functiondef('public.trg_profile_follow_notify()'::regprocedure))
       <> 'c67be9ee689fd9151dd2640c8fed4c96' THEN v_bad := v_bad || ' trg_profile_follow_notify'; END IF;
  IF md5(pg_get_functiondef('public.trg_circle_join_notify()'::regprocedure))
       <> '2849bec10dc26be4379be06f3b4d00e9' THEN v_bad := v_bad || ' trg_circle_join_notify'; END IF;
  IF EXISTS (SELECT 1 FROM public.notification_aggregates WHERE NOT is_flushed) THEN
    v_bad := v_bad || ' unflushed-legacy-aggregates';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.notification_aggregation_rules'::regclass
                  AND contype = 'p' AND pg_get_constraintdef(oid) = 'PRIMARY KEY (kind_key)') THEN
    v_bad := v_bad || ' rules-pk-not-kind_key';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'flush_notifications_every_10_seconds') THEN
    v_bad := v_bad || ' cron-job-missing';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
              AND table_name = 'notification_aggregates' AND column_name = 'group_key') THEN
    v_bad := v_bad || ' already-applied';
  END IF;
  IF to_regprocedure('public.notification_aggregate_add(uuid,text,text,uuid,uuid,jsonb,text,text,text,timestamptz)') IS NOT NULL
     OR to_regprocedure('public.trg_meetup_rsvp_interested_notify()') IS NOT NULL THEN
    v_bad := v_bad || ' new-function-name-taken';
  END IF;
  IF (SELECT is_active FROM public.notification_kinds WHERE key = 'meetup.rsvp_interested') IS DISTINCT FROM false THEN
    v_bad := v_bad || ' rsvp_interested-not-inactive';
  END IF;
  IF v_bad <> '' THEN
    RAISE EXCEPTION 'KAN-980 pre-image guard failed:%', v_bad;
  END IF;
END
$pre$;

-- 2. rules ------------------------------------------------------------------------------------------------------------
ALTER TABLE public.notification_aggregation_rules
  ADD COLUMN group_family text,
  ADD COLUMN mixed_kind_key text,
  ADD COLUMN push_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN push_cap_seconds integer NOT NULL DEFAULT 900 CHECK (push_cap_seconds >= 60);

COMMENT ON TABLE public.notification_aggregation_rules IS
  'KAN-980: kinds grouped into one growing row. aggregation_window_seconds = window from the first actor (3600). '
  'group_family: kinds sharing one group (post_liked + post_reacted = post). mixed_kind_key: template used when a '
  'group mixes kinds. push_enabled: re-push on growth (also needs the kind''s push channel). push_cap_seconds: at '
  'most one push per group per cap (900). min_actors_to_aggregate is no longer read.';

DELETE FROM public.notification_aggregation_rules WHERE kind_key = 'social.post_commented';

INSERT INTO public.notification_aggregation_rules
  (kind_key, aggregation_window_seconds, min_actors_to_aggregate, enabled, group_family, mixed_kind_key, push_enabled, push_cap_seconds)
VALUES
  ('social.post_liked',      3600, 1, true, 'post',              'social.post_reacted', true,  900),
  ('social.post_reacted',    3600, 1, true, 'post',              'social.post_reacted', true,  900),
  ('social.comment_liked',   3600, 1, true, 'comment',           NULL,                  true,  900),
  ('social.followed',        3600, 1, true, 'follow',            NULL,                  true,  900),
  ('social.circle_joined',   3600, 1, true, 'circle',            NULL,                  true,  900),
  ('meetup.rsvp_interested', 3600, 1, true, 'meetup_interested', NULL,                  false, 900)
ON CONFLICT (kind_key) DO UPDATE SET
  aggregation_window_seconds = EXCLUDED.aggregation_window_seconds,
  min_actors_to_aggregate    = EXCLUDED.min_actors_to_aggregate,
  enabled                    = EXCLUDED.enabled,
  group_family               = EXCLUDED.group_family,
  mixed_kind_key             = EXCLUDED.mixed_kind_key,
  push_enabled               = EXCLUDED.push_enabled,
  push_cap_seconds           = EXCLUDED.push_cap_seconds;

-- 3. aggregates -------------------------------------------------------------------------------------------------------
ALTER TABLE public.notification_aggregates
  ADD COLUMN group_key text,
  ADD COLUMN kinds text[] NOT NULL DEFAULT '{}',
  ADD COLUMN args jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN lang text,
  ADD COLUMN notification_id uuid REFERENCES public.notifications (id) ON DELETE SET NULL,
  ADD COLUMN push_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN push_pending boolean NOT NULL DEFAULT false,
  ADD COLUMN push_cap_seconds integer NOT NULL DEFAULT 900,
  ADD COLUMN last_push_at timestamptz,
  ADD COLUMN push_count integer NOT NULL DEFAULT 0,
  ADD COLUMN repush_hook_calls integer NOT NULL DEFAULT 0;

COMMENT ON TABLE public.notification_aggregates IS
  'KAN-980: one row per group of a grouped notification. notification_id = the notifications row that grows. '
  'actors newest first; window_started_at = first actor, window_expires_at = +1 hour. push_pending = the row changed '
  'since the last push; last_push_at / push_count for the 15-minute cap; repush_hook_calls = calls made to '
  'notification_repush (KAN-979). Rows with notification_id NULL and is_flushed = true are the pre-KAN-980 buffer.';

CREATE INDEX notification_aggregates_open_group_idx
  ON public.notification_aggregates (to_user_id, group_key, window_expires_at DESC)
  WHERE notification_id IS NOT NULL;
CREATE INDEX notification_aggregates_flush_idx
  ON public.notification_aggregates (updated_at)
  WHERE notification_id IS NOT NULL AND NOT is_flushed;

-- 4. the growing row ----------------------------------------------------------------------------------------------------
CREATE FUNCTION public.notification_aggregate_actor_phrase(p_lead text, p_others integer, p_lang text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- "{actor}" for a group: the newest actor's name plus how many others (EN and AR).
  SELECT CASE
    WHEN COALESCE(p_others, 0) <= 0 THEN p_lead
    WHEN p_lang = 'ar' THEN CASE
      WHEN p_others = 1 THEN p_lead || ' وشخص آخر'
      WHEN p_others = 2 THEN p_lead || ' وشخصان آخران'
      ELSE p_lead || ' و' || p_others || ' آخرين' END
    ELSE CASE
      WHEN p_others = 1 THEN p_lead || ' and 1 other'
      ELSE p_lead || ' and ' || p_others || ' others' END
  END;
$function$;

CREATE FUNCTION public.notification_aggregate_add(
  p_to_user_id uuid, p_kind_key text, p_entity_type text, p_entity_id uuid, p_actor_user_id uuid,
  p_args jsonb, p_lang text, p_action_route text, p_source_event_id text, p_now timestamptz DEFAULT now())
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rule   public.notification_aggregation_rules%ROWTYPE;
  v_kind   public.notification_kinds%ROWTYPE;
  v_agg    public.notification_aggregates%ROWTYPE;
  v_lang   text := CASE WHEN p_lang = 'ar' THEN 'ar' ELSE 'en' END;
  v_family text;
  v_group  text;
  v_new    boolean := false;
  v_rowkind text;
  v_push   boolean;
  v_lead   text;
  v_args   jsonb;
  v_title  text;
  v_body   text;
  v_route  text;
  v_ctx    jsonb;
  v_id     uuid;
BEGIN
  IF p_to_user_id IS NULL OR p_actor_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '22004', message = 'notification_aggregate_add: recipient and actor are required';
  END IF;
  SELECT * INTO v_rule FROM public.notification_aggregation_rules WHERE kind_key = p_kind_key AND enabled;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = '22023', message = format('notification_aggregate_add: no enabled rule for %s', p_kind_key);
  END IF;

  v_family := COALESCE(v_rule.group_family, p_kind_key);
  v_group  := v_family || ':' || COALESCE(p_entity_type, '-') || ':' || COALESCE(p_entity_id::text, '-');
  -- one writer per (recipient, group) at a time
  PERFORM pg_advisory_xact_lock(hashtextextended(p_to_user_id::text || '|' || v_group, 980));

  SELECT a.* INTO v_agg
    FROM public.notification_aggregates a
    JOIN public.notifications n ON n.id = a.notification_id
   WHERE a.to_user_id = p_to_user_id AND a.group_key = v_group
     AND a.window_expires_at > p_now
   ORDER BY a.window_started_at DESC
   LIMIT 1
   FOR UPDATE OF a;

  IF FOUND THEN
    IF p_actor_user_id = ANY (v_agg.actors) THEN
      RETURN v_agg.notification_id;          -- the same person counts once (a like and a reaction too)
    END IF;
    v_agg.actors := p_actor_user_id || v_agg.actors;     -- newest first
    IF NOT (p_kind_key = ANY (v_agg.kinds)) THEN
      v_agg.kinds := v_agg.kinds || p_kind_key;
    END IF;
    UPDATE public.notification_aggregates
       SET actors = v_agg.actors, kinds = v_agg.kinds, total_count = cardinality(v_agg.actors),
           updated_at = p_now, push_pending = push_enabled, is_flushed = false
     WHERE id = v_agg.id
    RETURNING * INTO v_agg;
  ELSE
    v_new := true;
    SELECT * INTO v_kind FROM public.notification_kinds WHERE key = p_kind_key;
    v_push := v_rule.push_enabled AND 'push' = ANY (v_kind.default_channels::text[]);
    INSERT INTO public.notification_aggregates (
      to_user_id, kind_key, entity_type, entity_id, actors, total_count, window_started_at, window_expires_at,
      is_flushed, created_at, updated_at, group_key, kinds, args, lang, push_enabled, push_pending,
      push_cap_seconds, last_push_at, push_count)
    VALUES (
      p_to_user_id, p_kind_key, COALESCE(p_entity_type, '-'), COALESCE(p_entity_id, p_to_user_id),
      ARRAY[p_actor_user_id], 1, p_now, p_now + make_interval(secs => v_rule.aggregation_window_seconds),
      false, p_now, p_now, v_group, ARRAY[p_kind_key], COALESCE(p_args, '{}'::jsonb), v_lang, v_push, false,
      v_rule.push_cap_seconds,
      CASE WHEN v_push THEN p_now END,      -- the insert push (trg_push_on_notification_insert) is the t0 push
      CASE WHEN v_push THEN 1 ELSE 0 END)
    RETURNING * INTO v_agg;
  END IF;

  -- render the row from the kind templates, in the recipient's language
  v_rowkind := CASE WHEN cardinality(v_agg.kinds) > 1 THEN COALESCE(v_rule.mixed_kind_key, v_agg.kinds[1])
                    ELSE v_agg.kinds[1] END;
  SELECT * INTO v_kind FROM public.notification_kinds WHERE key = v_rowkind;
  SELECT p.display_name INTO v_lead FROM public.profiles p
   WHERE p.user_id = v_agg.actors[1] AND p.is_active = true
   ORDER BY p.updated_at DESC NULLS LAST LIMIT 1;
  v_lead := COALESCE(v_lead, CASE WHEN v_agg.lang = 'ar' THEN 'شخص ما' ELSE 'Someone' END);
  v_args := v_agg.args || jsonb_build_object(
              'actor', public.notification_aggregate_actor_phrase(v_lead, v_agg.total_count - 1, v_agg.lang),
              'actor_count', v_agg.total_count, 'others_count', v_agg.total_count - 1,
              'actor_user_ids', to_jsonb(v_agg.actors));
  v_title := COALESCE(public.notify_v2_render(
               CASE WHEN v_agg.lang = 'ar' THEN v_kind.title_template_ar ELSE v_kind.title_template_en END,
               v_args, v_agg.lang),
             CASE WHEN v_agg.lang = 'ar' THEN v_kind.label_ar ELSE v_kind.label_en END);
  v_body  := public.notify_v2_render(
               CASE WHEN v_agg.lang = 'ar' THEN v_kind.body_template_ar ELSE v_kind.body_template_en END,
               v_args, v_agg.lang);
  v_route := COALESCE(p_action_route, CASE
               WHEN v_family = 'post'    THEN '/social-post-detail/' || v_agg.entity_id::text
               WHEN v_family IN ('follow', 'circle') THEN '/user-profile/' || v_agg.actors[1]::text
               WHEN v_agg.entity_type = 'meetup' THEN '/meetups/' || v_agg.entity_id::text || '/manage'
               ELSE NULL END);
  v_ctx := jsonb_build_object(
             'entity_type', v_agg.entity_type, 'entity_id', v_agg.entity_id,
             'actor_user_id', v_agg.actors[1], 'actor_display_name', v_lead,
             'actor_user_ids', to_jsonb(v_agg.actors), 'total_count', v_agg.total_count,
             'aggregated', true, 'group_key', v_group, 'kinds', to_jsonb(v_agg.kinds))
           || CASE WHEN v_family = 'post' THEN jsonb_build_object('post_id', v_agg.entity_id) ELSE '{}'::jsonb END
           || CASE WHEN v_family = 'follow' THEN jsonb_build_object('follower_user_ids', to_jsonb(v_agg.actors))
                   ELSE '{}'::jsonb END;

  IF NOT v_new THEN
    -- grows in place: unread again, on top
    UPDATE public.notifications
       SET kind_key = v_rowkind, template_key = v_rowkind, title = v_title, body = v_body, action_route = v_route,
           context = v_ctx, args = v_args, is_read = false, read_at = NULL, created_at = p_now
     WHERE id = v_agg.notification_id
    RETURNING id INTO v_id;
    RETURN v_id;
  END IF;

  INSERT INTO public.notifications (
    to_user_id, kind_key, title, body, action_route, context, priority, is_read, created_at,
    template_key, args, source_event_id, dedupe_key, group_key, schema_version)
  VALUES (
    p_to_user_id, v_rowkind, v_title, v_body, v_route, v_ctx, v_kind.default_priority, false, p_now,
    v_rowkind, v_args, p_source_event_id, 'agg:' || v_agg.id::text, v_group, 2)
  RETURNING id INTO v_id;

  UPDATE public.notification_aggregates SET notification_id = v_id WHERE id = v_agg.id;
  RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.notification_aggregate_actor_phrase(text, integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notification_aggregate_add(uuid, text, text, uuid, uuid, jsonb, text, text, text, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_aggregate_add(uuid, text, text, uuid, uuid, jsonb, text, text, text, timestamptz)
  TO service_role;

-- 5. flush: the 15-minute push cap and closing groups --------------------------------------------------------------------
DROP FUNCTION public.flush_notification_aggregates();

CREATE FUNCTION public.flush_notification_aggregates(p_now timestamptz DEFAULT now())
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a      record;
  v_n    integer := 0;
  v_hook boolean := to_regprocedure('public.notification_repush(uuid)') IS NOT NULL;
BEGIN
  FOR a IN
    SELECT g.id, g.notification_id, g.push_pending, g.last_push_at, g.push_cap_seconds, g.window_expires_at
      FROM public.notification_aggregates g
     WHERE g.notification_id IS NOT NULL AND NOT g.is_flushed
     ORDER BY g.updated_at
     FOR UPDATE OF g SKIP LOCKED
  LOOP
    IF a.push_pending
       AND (a.last_push_at IS NULL OR a.last_push_at <= p_now - make_interval(secs => a.push_cap_seconds)) THEN
      -- KAN-979 owns how a row becomes a push: replace the previous push of this group (collapse id = group_key,
      -- no sound) with the row's current title and body.
      IF v_hook THEN
        EXECUTE 'SELECT public.notification_repush($1)' USING a.notification_id;
      END IF;
      UPDATE public.notification_aggregates
         SET push_pending = false, last_push_at = p_now, push_count = push_count + 1,
             repush_hook_calls = repush_hook_calls + CASE WHEN v_hook THEN 1 ELSE 0 END
       WHERE id = a.id;
      v_n := v_n + 1;
    ELSIF NOT a.push_pending AND a.window_expires_at <= p_now THEN
      UPDATE public.notification_aggregates SET is_flushed = true WHERE id = a.id;
    END IF;
  END LOOP;
  RETURN v_n;   -- re-pushes made
END;
$function$;

REVOKE ALL ON FUNCTION public.flush_notification_aggregates(timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.flush_notification_aggregates(timestamptz) TO service_role;

SELECT cron.unschedule('flush_notifications_every_10_seconds');
SELECT cron.schedule('flush_notification_aggregates_every_minute', '* * * * *',
                     'SELECT public.flush_notification_aggregates();');

-- 6. senders: notify_v2's aggregation branch and the four producers (authored from the live definitions) -----------------
DO $senders$
DECLARE
  v_def text;
  r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)',
$o$  -- Aggregation stays as it is (KAN-980 owns it): a kind with an enabled rule is handed to the existing path.
  IF EXISTS (SELECT 1 FROM public.notification_aggregation_rules r
              WHERE r.kind_key = p_kind_key AND r.enabled = true) THEN
    PERFORM public.process_notification_event(p_to_user_id, p_kind_key, p_entity_type, p_entity_id,
                                              p_actor_user_id, v_title, v_body);
    RETURN NULL;
  END IF;$o$,
$n$  -- KAN-980: a kind with an enabled rule grows one row per group for the rule's window (1 hour).
  IF EXISTS (SELECT 1 FROM public.notification_aggregation_rules r
              WHERE r.kind_key = p_kind_key AND r.enabled = true) THEN
    RETURN public.notification_aggregate_add(p_to_user_id, p_kind_key, p_entity_type, p_entity_id,
                                             p_actor_user_id, p_args, v_lang, p_action_route, p_source_event_id);
  END IF;$n$),
    ('public.fn_likes_notify()',
$o$  PERFORM public.process_notification_event(
    v_target_uid,
    CASE v_activity_type
      WHEN 'comment' THEN 'social.comment_liked'
      ELSE 'social.post_liked'
    END,
    v_activity_type,
    NEW.parent_activity_id,
    NEW.actor_user_id,
    NULL,
    NULL
  );$o$,
$n$  -- KAN-980: grouped through notify_v2 (one sender per kind)
  PERFORM public.notify_v2(
    v_target_uid,
    CASE v_activity_type
      WHEN 'comment' THEN 'social.comment_liked'
      ELSE 'social.post_liked'
    END,
    '{}'::jsonb,
    v_activity_type,
    NEW.parent_activity_id,
    NEW.actor_user_id,
    'likes:' || NEW.id::text,
    'likes:' || NEW.id::text
  );$n$),
    ('public.trg_post_reaction_notify()',
$o$    PERFORM public.process_notification_event(
        v_post_author,
        'social.post_reacted',
        'post',
        NEW.parent_activity_id,
        NEW.actor_user_id
    );$o$,
$n$    -- KAN-980: grouped through notify_v2 (one sender per kind)
    PERFORM public.notify_v2(
        v_post_author,
        'social.post_reacted',
        '{}'::jsonb,
        'post',
        NEW.parent_activity_id,
        NEW.actor_user_id,
        'reactions:' || NEW.id::text,
        'reactions:' || NEW.id::text
    );$n$),
    ('public.trg_profile_follow_notify()',
$o$    PERFORM public.process_notification_event(
        v_followed_user,
        'social.followed',
        'profile',
        NEW.following_profile_id,
        v_follower_user
    );$o$,
$n$    -- KAN-980: grouped through notify_v2 (one sender per kind)
    PERFORM public.notify_v2(
        v_followed_user,
        'social.followed',
        '{}'::jsonb,
        'profile',
        NEW.following_profile_id,
        v_follower_user,
        'profile_follows:' || NEW.id::text,
        'profile_follows:' || NEW.id::text
    );$n$),
    ('public.trg_circle_join_notify()',
$o$    PERFORM public.process_notification_event(
        v_circle_owner,
        'social.circle_joined',
        'circle',
        NEW.circle_id,
        (
            SELECT user_id
            FROM public.profiles
            WHERE id = NEW.member_profile_id
        )
    );$o$,
$n$    -- KAN-980: grouped through notify_v2 (one sender per kind)
    PERFORM public.notify_v2(
        v_circle_owner,
        'social.circle_joined',
        '{}'::jsonb,
        'circle',
        NEW.circle_id,
        (
            SELECT user_id
            FROM public.profiles
            WHERE id = NEW.member_profile_id
        ),
        'circle_members:' || NEW.circle_id::text || ':' || NEW.member_profile_id::text,
        'circle_members:' || NEW.circle_id::text || ':' || NEW.member_profile_id::text
    );$n$)
  ) AS t(fn, old_text, new_text)
  LOOP
    v_def := pg_get_functiondef(r.fn::regprocedure);
    IF position(r.old_text IN v_def) = 0 THEN
      RAISE EXCEPTION 'KAN-980: expected text not found in %', r.fn;
    END IF;
    EXECUTE replace(v_def, r.old_text, r.new_text);
  END LOOP;
END
$senders$;

-- 7. Interested RSVP -> organiser, in-app, grouped (I-1) ----------------------------------------------------------------
UPDATE public.notification_kinds SET is_active = true WHERE key = 'meetup.rsvp_interested';

CREATE FUNCTION public.trg_meetup_rsvp_interested_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_host  uuid;
  v_title text;
BEGIN
  IF NEW.status IS DISTINCT FROM 'interested' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;
  -- the host approving a request into 'interested' (meet-up full) is not the member's own Interested RSVP
  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND v_actor IS NOT NULL AND v_actor <> NEW.user_id THEN
    RETURN NEW;
  END IF;

  SELECT e.creator_user_id, e.title INTO v_host, v_title
    FROM public.kan714_meetups_read m
    JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
   WHERE m.id = NEW.meetup_id;
  IF v_host IS NULL OR v_host = NEW.user_id THEN RETURN NEW; END IF;

  PERFORM public.notify_v2(
    v_host, 'meetup.rsvp_interested', jsonb_build_object('title', COALESCE(v_title, '')),
    'meetup', NEW.meetup_id, NEW.user_id,
    'meetup_rsvps:' || NEW.id::text || ':interested', 'meetup_rsvps:' || NEW.id::text || ':interested');
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.trg_meetup_rsvp_interested_notify() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_meetup_rsvp_interested_notify
  AFTER INSERT OR UPDATE OF status ON public.meetup_rsvps
  FOR EACH ROW EXECUTE FUNCTION public.trg_meetup_rsvp_interested_notify();

-- 8. table grants: server-internal; the owner keeps reading own groups through RLS ---------------------------------------
REVOKE ALL ON TABLE public.notification_aggregates FROM anon;
REVOKE ALL ON TABLE public.notification_aggregation_rules FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.notification_aggregates FROM authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.notification_aggregation_rules FROM authenticated;

-- 9. post asserts -----------------------------------------------------------------------------------------------------
DO $post$
DECLARE v_bad text := ''; f text;
BEGIN
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.flush_notification_aggregates(timestamptz)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}' THEN v_bad := v_bad || ' flush-acl'; END IF;
  IF has_function_privilege('anon', 'public.notification_aggregate_add(uuid,text,text,uuid,uuid,jsonb,text,text,text,timestamptz)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.notification_aggregate_add(uuid,text,text,uuid,uuid,jsonb,text,text,text,timestamptz)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.trg_meetup_rsvp_interested_notify()', 'EXECUTE') THEN
    v_bad := v_bad || ' client-can-execute';
  END IF;
  IF (SELECT count(*) FROM cron.job WHERE jobname = 'flush_notification_aggregates_every_minute'
        AND schedule = '* * * * *' AND active) <> 1
     OR EXISTS (SELECT 1 FROM cron.job WHERE command ILIKE '%flush_notification_aggregates%'
                  AND jobname <> 'flush_notification_aggregates_every_minute') THEN
    v_bad := v_bad || ' cron';
  END IF;
  FOREACH f IN ARRAY ARRAY['public.fn_likes_notify()', 'public.trg_post_reaction_notify()',
                           'public.trg_profile_follow_notify()', 'public.trg_circle_join_notify()'] LOOP
    IF pg_get_functiondef(f::regprocedure) ~ 'process_notification_event'
       OR pg_get_functiondef(f::regprocedure) !~ 'notify_v2\(' THEN
      v_bad := v_bad || ' sender:' || f;
    END IF;
  END LOOP;
  IF pg_get_functiondef('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)'::regprocedure)
       ~ 'PERFORM public\.process_notification_event' THEN v_bad := v_bad || ' notify_v2-still-calls-pne'; END IF;
  IF EXISTS (SELECT 1 FROM public.notification_aggregation_rules WHERE kind_key = 'social.post_commented')
     OR EXISTS (SELECT 1 FROM public.notification_aggregation_rules
                 WHERE kind_key LIKE 'social.mentioned%' OR kind_key = 'social.comment_replied') THEN
    v_bad := v_bad || ' comment-or-mention-rule';
  END IF;
  IF (SELECT count(*) FROM public.notification_aggregation_rules WHERE enabled AND aggregation_window_seconds = 3600) <> 6 THEN
    v_bad := v_bad || ' rules';
  END IF;
  IF has_table_privilege('anon', 'public.notification_aggregates', 'SELECT')
     OR has_table_privilege('authenticated', 'public.notification_aggregates', 'INSERT') THEN
    v_bad := v_bad || ' table-grants';
  END IF;
  IF v_bad <> '' THEN
    RAISE EXCEPTION 'KAN-980 post assert failed:%', v_bad;
  END IF;
END
$post$;
