-- KAN-1045 (NOTIF-1): notification channels. Groups = notification_kinds.category; each kind gets a
-- channel_key. Per-user channel mutes (own rows, RLS). The push sender sends channel_key, thread_id and a
-- per-channel iOS interruption level, and skips a muted channel. Security channels cannot be muted.
-- Rollback: supabase/rollbacks/20261125100000_kan1045_notification_channels_rollback.sql
BEGIN;

CREATE TABLE IF NOT EXISTS public.notification_channels (
  key                    text PRIMARY KEY CHECK (key ~ '^[a-z]+\.[a-z_]+$'),
  group_key              text NOT NULL,
  label_en               text NOT NULL,
  label_ar               text NOT NULL,
  ios_interruption_level text NOT NULL DEFAULT 'active' CHECK (ios_interruption_level IN ('time-sensitive','active','passive')),
  android_importance     text NOT NULL DEFAULT 'high' CHECK (android_importance IN ('max','high','default','low','min')),
  can_mute               boolean NOT NULL DEFAULT true,
  sort_order             int NOT NULL DEFAULT 0,
  created_at             timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.notification_channels (key, group_key, label_en, label_ar, ios_interruption_level, android_importance, can_mute, sort_order) VALUES
  ('games.invites',          'games',      'Invites & join requests',      'الدعوات وطلبات الانضمام',       'active',         'high',    true,  10),
  ('games.reminders',        'games',      'Reminders',                    'التذكيرات',                     'time-sensitive', 'max',     true,  11),
  ('games.changes',          'games',      'Changes & cancellations',      'التغييرات والإلغاءات',          'active',         'high',    true,  12),
  ('games.roster',           'games',      'Roster updates',               'تحديثات قائمة اللاعبين',        'active',         'default', true,  13),
  ('meetups.invites',        'meetups',    'Invites & RSVPs',              'الدعوات وتأكيدات الحضور',       'active',         'high',    true,  20),
  ('meetups.reminders',      'meetups',    'Reminders',                    'التذكيرات',                     'time-sensitive', 'max',     true,  21),
  ('meetups.changes',        'meetups',    'Changes & cancellations',      'التغييرات والإلغاءات',          'active',         'high',    true,  22),
  ('activities.checkin',     'activities', 'Check-in',                     'تسجيل الحضور',                  'time-sensitive', 'max',     true,  30),
  ('activities.attendance',  'activities', 'Attendance',                   'الحضور',                        'active',         'default', true,  31),
  ('activities.results',     'activities', 'Results & ratings',            'النتائج والتقييمات',            'active',         'default', true,  32),
  ('messages.direct',        'messages',   'Direct chats',                 'المحادثات المباشرة',            'active',         'max',     true,  40),
  ('messages.threads',       'messages',   'Game & meet-up chats',         'محادثات المباريات واللقاءات',   'active',         'high',    true,  41),
  ('social.follows',         'social',     'New followers',                'المتابعون الجدد',               'active',         'default', true,  50),
  ('social.reactions',       'social',     'Likes & comments',             'الإعجابات والتعليقات',          'passive',        'default', true,  51),
  ('social.mentions',        'social',     'Mentions',                     'الإشارات',                      'active',         'high',    true,  52),
  ('booking.confirmations',  'booking',    'Confirmations & changes',      'التأكيدات والتغييرات',          'active',         'high',    true,  60),
  ('booking.payments',       'booking',    'Payments',                     'المدفوعات',                     'active',         'high',    true,  61),
  ('security.alerts',        'security',   'Sign-in & security alerts',    'تنبيهات تسجيل الدخول والأمان',  'time-sensitive', 'max',     false, 70),
  ('system.announcements',   'system',     'Announcements',                'الإعلانات',                     'passive',        'default', true,  80),
  ('system.rewards',         'system',     'Rewards & badges',             'المكافآت والشارات',             'active',         'default', true,  81)
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.notification_channels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notification_channels_read ON public.notification_channels;
CREATE POLICY notification_channels_read ON public.notification_channels FOR SELECT TO authenticated USING (true);
REVOKE ALL ON public.notification_channels FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.notification_channels TO authenticated;

ALTER TABLE public.notification_kinds ADD COLUMN IF NOT EXISTS channel_key text REFERENCES public.notification_channels(key);

UPDATE public.notification_kinds nk SET channel_key = m.ch FROM (VALUES
  ('game.invited','games.invites'),('game.invite_accepted','games.invites'),('game.invite_declined','games.invites'),
  ('game.invite_expired','games.invites'),('game.invite_withdrawn','games.invites'),('game.join_request','games.invites'),
  ('game.join_accepted','games.invites'),('game.join_declined','games.invites'),
  ('game.reminder','games.reminders'),
  ('game.cancelled','games.changes'),('game.details_changed','games.changes'),('game.occurrence_cancelled','games.changes'),
  ('game.series_cancelled','games.changes'),('game.series_changed','games.changes'),('game.time_changed','games.changes'),
  ('game.updated','games.changes'),('game.venue_changed','games.changes'),
  ('game.full','games.roster'),('game.player_joined','games.roster'),('game.player_left','games.roster'),
  ('game.removed','games.roster'),('game.waitlist_joined','games.roster'),('game.waitlist_position_changed','games.roster'),
  ('game.waitlist_promoted','games.roster'),
  ('meetup.invited','meetups.invites'),('meetup.confirm_attendance','meetups.invites'),('meetup.request_approved','meetups.invites'),
  ('meetup.request_declined','meetups.invites'),('meetup.request_received','meetups.invites'),('meetup.rsvp_interested','meetups.invites'),
  ('meetup.rsvp_received','meetups.invites'),('meetup.wants_to_join_full','meetups.invites'),('meetup.player_joined','meetups.invites'),
  ('meetup.player_left','meetups.invites'),
  ('meetup.reminder','meetups.reminders'),
  ('meetup.cancelled','meetups.changes'),('meetup.details_changed','meetups.changes'),('meetup.occurrence_cancelled','meetups.changes'),
  ('meetup.series_changed','meetups.changes'),('meetup.time_changed','meetups.changes'),('meetup.venue_changed','meetups.changes'),
  ('meetup.removed','meetups.changes'),
  ('activity.checkin_open','activities.checkin'),('activity.checkin_closing','activities.checkin'),('activity.checked_in','activities.checkin'),
  ('activity.confirm_end','activities.checkin'),('activity.confirm_end_reminder','activities.checkin'),('activity.auto_closed','activities.checkin'),
  ('activity.ended','activities.checkin'),
  ('activity.attendance_corrected','activities.attendance'),('activity.no_show_confirmed','activities.attendance'),
  ('activity.no_show_pending','activities.attendance'),('activity.showup_rate_updated','activities.attendance'),
  ('activity.post_activity','activities.results'),('activity.rating_reminder','activities.results'),('activity.result_closed','activities.results'),
  ('activity.result_confirmed','activities.results'),('activity.result_corrected','activities.results'),('activity.result_enter_final','activities.results'),
  ('activity.result_ready','activities.results'),('activity.review_accepted','activities.results'),('activity.review_kept','activities.results'),
  ('activity.review_requested','activities.results'),('activity.summary','activities.results'),
  ('message.received','messages.direct'),
  ('friend.accepted','social.follows'),('friend.requested','social.follows'),('social.followed','social.follows'),
  ('social.friend_accepted','social.follows'),('social.friend_request','social.follows'),('social.circle_joined','social.follows'),
  ('squad.invited','social.follows'),
  ('social.comment_liked','social.reactions'),('social.comment_replied','social.reactions'),('social.post_commented','social.reactions'),
  ('social.post_liked','social.reactions'),('social.post_reacted','social.reactions'),('social.post_reposted','social.reactions'),
  ('social.mentioned_in_comment','social.mentions'),('social.mentioned_in_post','social.mentions'),
  ('booking.cancelled','booking.confirmations'),('booking.changed','booking.confirmations'),('booking.confirmed','booking.confirmations'),
  ('booking.hold_expiring','booking.confirmations'),('booking.pending','booking.confirmations'),('booking.rejected','booking.confirmations'),
  ('venue.feedback_request','booking.confirmations'),
  ('arena.payment_required','booking.payments'),('payment.failed','booking.payments'),('payment.pending','booking.payments'),
  ('payment.succeeded','booking.payments'),('refund.completed','booking.payments'),('refund.failed','booking.payments'),
  ('refund.processing','booking.payments'),
  ('security.email_changed','security.alerts'),('security.new_signin','security.alerts'),('security.password_changed','security.alerts'),
  ('auth.welcome','system.announcements'),('moderation.report_submitted','system.announcements'),
  ('moderation.user_blocked','system.announcements'),('system.announcement','system.announcements'),
  ('reward.badge_awarded','system.rewards')
) AS m(k, ch) WHERE nk.key = m.k;

-- A kind with no explicit mapping (a future kind) is never left without a channel: fail the migration.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.notification_kinds WHERE channel_key IS NULL) THEN
    RAISE EXCEPTION 'KAN-1045: unmapped notification kinds: %',
      (SELECT string_agg(key, ', ') FROM public.notification_kinds WHERE channel_key IS NULL);
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_kinds nk JOIN public.notification_channels c ON c.key = nk.channel_key
              WHERE c.group_key <> nk.category) THEN
    RAISE EXCEPTION 'KAN-1045: a kind maps to a channel outside its category';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.notification_channel_mutes (
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel_key text NOT NULL REFERENCES public.notification_channels(key) ON DELETE CASCADE,
  muted_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, channel_key)
);
ALTER TABLE public.notification_channel_mutes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notification_channel_mutes_own_select ON public.notification_channel_mutes;
DROP POLICY IF EXISTS notification_channel_mutes_own_insert ON public.notification_channel_mutes;
DROP POLICY IF EXISTS notification_channel_mutes_own_delete ON public.notification_channel_mutes;
CREATE POLICY notification_channel_mutes_own_select ON public.notification_channel_mutes FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));
CREATE POLICY notification_channel_mutes_own_insert ON public.notification_channel_mutes FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid())
              AND EXISTS (SELECT 1 FROM public.notification_channels c WHERE c.key = channel_key AND c.can_mute));
CREATE POLICY notification_channel_mutes_own_delete ON public.notification_channel_mutes FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));
REVOKE ALL ON public.notification_channel_mutes FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.notification_channel_mutes TO authenticated;

-- Whether a user muted the channel of a kind. Never true for an unmutable kind or channel.
CREATE OR REPLACE FUNCTION public.notification_channel_muted(p_user uuid, p_kind text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT NOT public.notification_kind_is_unmutable(p_kind)
     AND EXISTS (SELECT 1
                   FROM public.notification_kinds nk
                   JOIN public.notification_channels c ON c.key = nk.channel_key AND c.can_mute
                   JOIN public.notification_channel_mutes m ON m.channel_key = c.key AND m.user_id = p_user
                  WHERE nk.key = p_kind);
$function$;
REVOKE ALL ON FUNCTION public.notification_channel_muted(uuid, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.rpc_list_notification_channels()
 RETURNS TABLE(channel_key text, group_key text, label_en text, label_ar text, ios_interruption_level text,
               android_importance text, can_mute boolean, muted boolean, sort_order int)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT c.key, c.group_key, c.label_en, c.label_ar, c.ios_interruption_level, c.android_importance, c.can_mute,
         c.can_mute AND EXISTS (SELECT 1 FROM public.notification_channel_mutes m
                                 WHERE m.user_id = auth.uid() AND m.channel_key = c.key),
         c.sort_order
    FROM public.notification_channels c
   WHERE auth.uid() IS NOT NULL
   ORDER BY c.sort_order, c.key;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_set_notification_channel_muted(p_channel_key text, p_muted boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_can boolean;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501'; END IF;
  SELECT c.can_mute INTO v_can FROM public.notification_channels c WHERE c.key = p_channel_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'unknown channel %', p_channel_key USING ERRCODE = '22023'; END IF;
  IF p_muted AND NOT v_can THEN RAISE EXCEPTION 'channel % cannot be muted', p_channel_key USING ERRCODE = '22023'; END IF;
  IF p_muted THEN
    INSERT INTO public.notification_channel_mutes (user_id, channel_key) VALUES (v_uid, p_channel_key)
    ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.notification_channel_mutes WHERE user_id = v_uid AND channel_key = p_channel_key;
  END IF;
  RETURN p_muted;
END;
$function$;

-- Mutes or unmutes every mutable channel of a group; returns how many channels the group has that can be muted.
CREATE OR REPLACE FUNCTION public.rpc_set_notification_group_muted(p_group_key text, p_muted boolean)
 RETURNS int
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_n int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.notification_channels WHERE group_key = p_group_key) THEN
    RAISE EXCEPTION 'unknown group %', p_group_key USING ERRCODE = '22023';
  END IF;
  SELECT count(*)::int INTO v_n FROM public.notification_channels WHERE group_key = p_group_key AND can_mute;
  IF p_muted AND v_n = 0 THEN RAISE EXCEPTION 'group % cannot be muted', p_group_key USING ERRCODE = '22023'; END IF;
  IF p_muted THEN
    INSERT INTO public.notification_channel_mutes (user_id, channel_key)
    SELECT v_uid, c.key FROM public.notification_channels c WHERE c.group_key = p_group_key AND c.can_mute
    ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.notification_channel_mutes m USING public.notification_channels c
     WHERE m.user_id = v_uid AND m.channel_key = c.key AND c.group_key = p_group_key;
  END IF;
  RETURN v_n;
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_list_notification_channels() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_set_notification_channel_muted(text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_set_notification_group_muted(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_list_notification_channels() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_set_notification_channel_muted(text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_set_notification_group_muted(text, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.notification_push_dispatch(p_notification_id uuid, p_repush boolean DEFAULT false)
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
  _channel public.notification_channels%ROWTYPE;
  _level text;
BEGIN
  SELECT * INTO n FROM public.notifications WHERE id = p_notification_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  _entity_type := NULLIF(n.context->>'entity_type', '');
  _entity_id := NULLIF(n.context->>'entity_id', '');
  _body := COALESCE(n.body, '');

  -- KAN-984: the snippet hook is consumed first, before any gate, so it can never carry over to another row.
  IF NOT p_repush THEN
    _snippet := NULLIF(current_setting('dabbler.push_body', true), '');
    IF _snippet IS NOT NULL THEN
      PERFORM set_config('dabbler.push_body', '', true);
    END IF;
  END IF;

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

  -- KAN-1045: a channel the user muted gets no push (never for security / unmutable kinds).
  IF public.notification_channel_muted(n.to_user_id, n.kind_key) THEN
    RETURN false;
  END IF;
  SELECT * INTO _channel FROM public.notification_channels WHERE key = _kind.channel_key;

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

  -- KAN-1045: iOS interruption level: time-sensitive when the kind breaks quiet, passive when silent, else the channel's.
  _level := CASE WHEN _breaks THEN 'time-sensitive' WHEN _quiet THEN 'passive'
                 ELSE COALESCE(_channel.ios_interruption_level, 'active') END;

  SELECT count(*)::int INTO _badge FROM public.notifications x WHERE x.to_user_id = n.to_user_id AND NOT x.is_read;

  -- KAN-984 hook: the message snippet travels in the push only, for a messages kind; it is never stored.
  IF _kind.category = 'messages' AND _snippet IS NOT NULL THEN
    _body := _snippet;
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
        'repush',          CASE WHEN p_repush THEN 'true' ELSE 'false' END,
        'channel_key',     COALESCE(_kind.channel_key, '')
      ) || CASE
        WHEN _entity_type = 'meetup' AND _entity_id IS NOT NULL
        THEN jsonb_build_object('meetup_id', _entity_id)   -- kept for meetupPushRoute in current builds
        ELSE '{}'::jsonb
      END
      -- KAN-984: the chat a message belongs to, so the app can skip the alert for the open chat (KAN-992)
      || jsonb_strip_nulls(jsonb_build_object(
           'conversation_id', n.args->>'conversation_id',
           'game_id',         n.args->>'game_id',
           'meetup_id',       n.args->>'meetup_id')),
      'delivery',        jsonb_build_object(
        'mode',               CASE WHEN _quiet THEN 'silent' ELSE 'alert' END,
        'time_sensitive',     _breaks,
        -- legacy category channel: what installed builds know. The edge function swaps in channel_key
        -- per device once the app build that creates the new channels is out (PUSH_CHANNEL_KEY_MIN_BUILD).
        'android_channel_id', CASE WHEN _quiet THEN 'dabbler_quiet' ELSE 'dabbler_' || COALESCE(_kind.category, 'default') END,
        'channel_key',        _kind.channel_key,
        'interruption_level', _level,
        'ios_category',       public.notification_push_category(n.kind_key),
        'thread_id',          COALESCE(_kind.channel_key, n.group_key),
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


COMMIT;
