-- KAN-981 [W1-B3] Event changes and cancel (Epic KAN-973, plan Dabbler/dabbler-docs/briefs/NOTIFICATIONS_PLAN_2026-11-16.md).
--
-- Tells active participants when a game or meetup changes or is cancelled, with the old and the new value, and stops
-- game.updated from meaning "cancelled". Every notice goes through notify_v2 (KAN-974) with a dedupe key built from
-- event_changes ids (KAN-976), so a re-run or a retried batch never sends twice.
--
-- 1. Recipients (kan981_recipients): game = game_roster.status 'active'; meetup = meetup_rsvps.status 'going' or
--    'interested' (I-5). Never the event creator, never the person who made the change. Left/kicked roster rows,
--    'cancelled' and 'pending' RSVPs get nothing (the old meetup cancel loop also reached 'pending'; dropped on purpose).
-- 2. Cancel (immediate): trg_game_updated_notify() is rewritten as the one cancel sender for both event types:
--    game.cancelled / meetup.cancelled, one per recipient, dedupe 'w1_b3:cancel:<event_changes.id>'. It marks that
--    is_cancelled outbox row consumed ('w1_b3'). Its trigger trg_kan947_events_game_updated_notify keeps its name and
--    now fires for meetups too (WHEN no longer requires event_type = 'game'); no trigger is added to events.
--    A series occurrence is left to the consumer (step 3) so a whole-series cancel can be grouped.
--    Old senders switched off here: the game.updated loop (this function) and the process_notification_event
--    'meetup.cancelled' loop inside rpc_meetup_cancel_kan712_inner (removed; the rest of that body is unchanged,
--    authored from pg_get_functiondef). game.updated is deactivated: nothing sends it any more.
-- 3. Changes (debounced): kan981_consume_event_changes(), run by pg_cron every minute
--    ('kan981_event_changes_every_minute'). Why cron and not a deferred trigger on event_changes:
--      - the debounce needs time to pass: a deferred trigger fires at the writer's COMMIT, so it cannot wait for a
--        burst of edits to settle;
--      - it runs outside the organiser's transaction, so a failed render or a slow recipient query can never roll back
--        the organiser's save;
--      - one run sees several occurrences of a series together and can send one series notice per person;
--      - pg_cron already runs flush_notification_aggregates_every_minute here.
--    Cost: a change notice arrives 1-2 minutes after the last edit. Cancels do not wait (step 2).
--    Per event, all unconsumed rows are taken together once the event has been quiet for p_settle (60 s), or once
--    its oldest unconsumed row is p_max_wait (5 min) old, so continuous edits cannot starve it. Fields are collapsed
--    (first old value, last new value); a field that ended where it started is dropped; nothing left = no notice.
--    Kind: *.time_changed if start/end moved, else *.venue_changed if the place moved, else *.details_changed
--    (capacity, who can join, joining rule / cost cover, skill range). All changed parts are listed in one notice.
--    Series: when one transaction changed two or more occurrences of the same game series (edit-future or cancel of
--    the whole series), the consumer sends one game.series_changed per person across those occurrences. One
--    occurrence cancelled alone -> game.occurrence_cancelled to that occurrence's participants only. A changed event
--    that is now cancelled, or that is already in the past, is consumed without a notice.
--    Localised: args carry *_en and *_ar for title, field, old, new and when (notify_v2_render picks <key>_<lang>).
--    Times are rendered in event_timezone(event) (KAN-976).
-- 4. Kinds activated (all already breaks_quiet = true from KAN-974): game.cancelled, game.time_changed,
--    game.venue_changed, game.details_changed, game.occurrence_cancelled, game.series_changed, meetup.time_changed,
--    meetup.venue_changed, meetup.details_changed. meetup.cancelled stays active (new sender). game.updated
--    deactivated. meetup.occurrence_cancelled and meetup.series_changed stay inactive: meetups have no series.
--
-- Pre-image guard: md5 of the live trg_game_updated_notify, rpc_meetup_cancel_kan712_inner and trigger definitions as
--   read 2026-11-17 (Jira KAN-981 claim 16431); kind states; no kan981 object or cron job exists yet.
-- Post asserts: kind states, trigger WHEN, old senders gone, ACLs, cron job, index.
-- Live test: supabase/tests/notifications_v2/kan981_event_change_notices.sql.
-- Rollback: supabase/schema/rollback/kan981_ROLLBACK_event_change_notices.sql.

-- 1. pre-image guard ---------------------------------------------------------------------------------------------------
DO $pre$
BEGIN
  IF md5(pg_get_functiondef('public.trg_game_updated_notify()'::regprocedure)) <> '45c97c575b8ad3887d61cecbb72e80bf' THEN
    RAISE EXCEPTION 'kan981 pre: trg_game_updated_notify changed since the claim';
  END IF;
  IF md5(pg_get_functiondef('public.rpc_meetup_cancel_kan712_inner(uuid)'::regprocedure)) <> '164ee91bc4c5799316830785b415eb85' THEN
    RAISE EXCEPTION 'kan981 pre: rpc_meetup_cancel_kan712_inner changed since the claim';
  END IF;
  IF (SELECT md5(pg_get_triggerdef(t.oid)) FROM pg_trigger t
       WHERE t.tgrelid = 'public.events'::regclass AND t.tgname = 'trg_kan947_events_game_updated_notify')
     IS DISTINCT FROM '2420a07e369244f952987f03f134dda2' THEN
    RAISE EXCEPTION 'kan981 pre: trg_kan947_events_game_updated_notify changed since the claim';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('game.cancelled', 'game.time_changed', 'game.venue_changed', 'game.details_changed',
                     'game.occurrence_cancelled', 'game.series_changed', 'meetup.time_changed',
                     'meetup.venue_changed', 'meetup.details_changed') AND NOT is_active) <> 9 THEN
    RAISE EXCEPTION 'kan981 pre: the 9 change/cancel kinds are not all present and inactive';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds WHERE key IN ('game.updated', 'meetup.cancelled') AND is_active) <> 2 THEN
    RAISE EXCEPTION 'kan981 pre: game.updated / meetup.cancelled are not both active';
  END IF;
  IF to_regprocedure('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)') IS NULL
     OR to_regprocedure('public.event_timezone(uuid)') IS NULL OR to_regclass('public.event_changes') IS NULL THEN
    RAISE EXCEPTION 'kan981 pre: Wave 0 contract missing (notify_v2, event_timezone, event_changes)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname LIKE 'kan981\_%')
     OR EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan981_event_changes_every_minute')
     OR to_regclass('public.event_changes_w1_b3_pending_idx') IS NOT NULL THEN
    RAISE EXCEPTION 'kan981 pre: a kan981 object already exists';
  END IF;
END $pre$;

-- 2. helpers -----------------------------------------------------------------------------------------------------------
-- Active participants who hear about a change or a cancel. Creator excluded; the caller excludes the actor.
CREATE FUNCTION public.kan981_recipients(p_event_id uuid)
  RETURNS SETOF uuid
  LANGUAGE sql
  STABLE
  SET search_path TO ''
AS $function$
  SELECT r.user_id
    FROM public.events e
    JOIN public.game_roster r ON r.game_id = e.id
   WHERE e.id = p_event_id AND e.event_type = 'game'
     AND r.status = 'active' AND r.user_id IS NOT NULL AND r.user_id <> e.creator_user_id
  UNION
  SELECT s.user_id
    FROM public.events e
    JOIN public.meetup_rsvps s ON s.meetup_id = e.id
   WHERE e.id = p_event_id AND e.event_type = 'meetup'
     AND s.status IN ('going', 'interested') AND s.user_id IS NOT NULL AND s.user_id <> e.creator_user_id
$function$;

-- 'Mon 17 Nov, 18:00–19:30' / 'الاثنين 17 نوفمبر، 18:00–19:30' in the event's zone.
CREATE FUNCTION public.kan981_fmt_span(p_start timestamptz, p_end timestamptz, p_tz text, p_lang text)
  RETURNS text
  LANGUAGE sql
  STABLE
  SET search_path TO ''
AS $function$
  SELECT CASE WHEN p_start IS NULL THEN NULL
    WHEN p_lang = 'ar' THEN
      (ARRAY['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'])[extract(dow FROM l.s)::int + 1]
      || ' ' || extract(day FROM l.s)::int || ' '
      || (ARRAY['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'])[extract(month FROM l.s)::int]
      || '، ' || to_char(l.s, 'HH24:MI') || coalesce('–' || to_char(l.e, 'HH24:MI'), '')
    ELSE
      (ARRAY['Sun','Mon','Tue','Wed','Thu','Fri','Sat'])[extract(dow FROM l.s)::int + 1]
      || ' ' || extract(day FROM l.s)::int || ' '
      || (ARRAY['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'])[extract(month FROM l.s)::int]
      || ', ' || to_char(l.s, 'HH24:MI') || coalesce('–' || to_char(l.e, 'HH24:MI'), '')
    END
    FROM (SELECT p_start AT TIME ZONE coalesce(p_tz, 'Asia/Dubai') AS s,
                 p_end   AT TIME ZONE coalesce(p_tz, 'Asia/Dubai') AS e) l
$function$;

-- Display label of a field ('field') or of a field value, EN/AR. NULL value -> the field's empty label.
CREATE FUNCTION public.kan981_value_label(p_field text, p_value text, p_lang text)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  SET search_path TO ''
AS $function$
  SELECT CASE p_field
    WHEN 'field' THEN CASE p_value
        WHEN 'time'         THEN CASE WHEN p_lang = 'ar' THEN 'الموعد'           ELSE 'Time' END
        WHEN 'place'        THEN CASE WHEN p_lang = 'ar' THEN 'المكان'           ELSE 'Venue' END
        WHEN 'capacity'     THEN CASE WHEN p_lang = 'ar' THEN 'العدد'            ELSE 'Places' END
        WHEN 'join_policy'  THEN CASE WHEN p_lang = 'ar' THEN 'من يمكنه الانضمام' ELSE 'Who can join' END
        WHEN 'joining_rule' THEN CASE WHEN p_lang = 'ar' THEN 'شروط الانضمام'    ELSE 'Joining rule' END
        WHEN 'skill'        THEN CASE WHEN p_lang = 'ar' THEN 'مستوى المهارة'    ELSE 'Skill level' END
        ELSE p_value END
    WHEN 'capacity' THEN coalesce(p_value, CASE WHEN p_lang = 'ar' THEN 'بلا حد' ELSE 'No limit' END)
    WHEN 'join_policy' THEN CASE p_value
        WHEN 'open'    THEN CASE WHEN p_lang = 'ar' THEN 'مفتوح للجميع'     ELSE 'Open to everyone' END
        WHEN 'request' THEN CASE WHEN p_lang = 'ar' THEN 'بطلب انضمام'      ELSE 'Request to join' END
        WHEN 'invite'  THEN CASE WHEN p_lang = 'ar' THEN 'بالدعوة فقط'      ELSE 'Invite only' END
        WHEN 'link'    THEN CASE WHEN p_lang = 'ar' THEN 'لمن لديه الرابط'  ELSE 'Anyone with the link' END
        WHEN 'closed'  THEN CASE WHEN p_lang = 'ar' THEN 'مغلق'             ELSE 'Closed' END
        ELSE p_value END
    WHEN 'joining_rule' THEN CASE p_value
        WHEN 'free'         THEN CASE WHEN p_lang = 'ar' THEN 'مجاني'        ELSE 'Free' END
        WHEN 'members_only' THEN CASE WHEN p_lang = 'ar' THEN 'للأعضاء فقط'  ELSE 'Members only' END
        WHEN 'paid'         THEN CASE WHEN p_lang = 'ar' THEN 'مدفوع'        ELSE 'Paid' END
        ELSE p_value END
    ELSE p_value END
$function$;

-- Venue name, else area name, else 'to be confirmed'.
CREATE FUNCTION public.kan981_place_name(p_venue_id uuid, p_area_id uuid, p_lang text)
  RETURNS text
  LANGUAGE sql
  STABLE
  SET search_path TO ''
AS $function$
  SELECT coalesce(
    (SELECT CASE WHEN p_lang = 'ar' THEN coalesce(nullif(btrim(v.name_ar), ''), v.name_en) ELSE v.name_en END
       FROM public.venues v WHERE v.id = p_venue_id),
    (SELECT a.name FROM public.areas a WHERE a.id = p_area_id),
    CASE WHEN p_lang = 'ar' THEN 'الموقع سيُحدَّد' ELSE 'Location to be confirmed' END)
$function$;

-- The event's title for a notice; a game without a title is named by its sport.
CREATE FUNCTION public.kan981_event_title(p_event_id uuid, p_lang text)
  RETURNS text
  LANGUAGE sql
  STABLE
  SET search_path TO ''
AS $function$
  SELECT coalesce(
    nullif(btrim(e.title), ''),
    CASE WHEN e.event_type = 'game' THEN
      CASE WHEN p_lang = 'ar' THEN 'مباراة ' || coalesce(nullif(btrim(sp.name_ar), ''), sp.name_en)
           ELSE sp.name_en || ' game' END
    END,
    CASE WHEN e.event_type = 'game' THEN CASE WHEN p_lang = 'ar' THEN 'مباراتك' ELSE 'Your game' END
         ELSE CASE WHEN p_lang = 'ar' THEN 'لقاؤك' ELSE 'Your meet-up' END END)
    FROM public.events e
    LEFT JOIN public.sports sp ON sp.id = e.sport_id
   WHERE e.id = p_event_id
$function$;

-- 3. cancel sender (replaces the game.updated loop) --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_game_updated_notify()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_actor  uuid := auth.uid();
  v_series uuid;
  v_ec     bigint;
  v_kind   text;
  v_args   jsonb;
  u        uuid;
BEGIN
  -- Only a real cancel (false -> true). Un-cancel is recorded in event_changes and left to the consumer (no notice).
  IF NOT (OLD.is_cancelled IS NOT TRUE AND NEW.is_cancelled IS TRUE) THEN
    RETURN NULL;
  END IF;

  -- A series occurrence is sent by kan981_consume_event_changes, which can group a whole-series cancel.
  IF NEW.event_type = 'game' THEN
    SELECT g.series_id INTO v_series FROM public.games g WHERE g.event_id = NEW.id;
    IF v_series IS NOT NULL THEN
      RETURN NULL;
    END IF;
  END IF;

  -- The is_cancelled row trg_kan976_events_change_signal wrote for this UPDATE (same statement).
  SELECT x.id INTO v_ec FROM public.event_changes x
   WHERE x.event_id = NEW.id AND x.field = 'is_cancelled' AND x.new_value = 'true'::jsonb
     AND NOT (x.consumed_by ? 'w1_b3')
   ORDER BY x.id DESC LIMIT 1;

  v_kind := NEW.event_type || '.cancelled';
  v_args := jsonb_build_object('title_en', public.kan981_event_title(NEW.id, 'en'),
                               'title_ar', public.kan981_event_title(NEW.id, 'ar'),
                               'when_en',  public.kan981_fmt_span(NEW.start_at, NEW.end_at, public.event_timezone(NEW.id), 'en'),
                               'when_ar',  public.kan981_fmt_span(NEW.start_at, NEW.end_at, public.event_timezone(NEW.id), 'ar'));

  FOR u IN SELECT r FROM public.kan981_recipients(NEW.id) AS r WHERE r IS DISTINCT FROM v_actor LOOP
    PERFORM public.notify_v2(
      u, v_kind, v_args, NEW.event_type, NEW.id, coalesce(v_actor, NEW.creator_user_id),
      'event_changes:' || coalesce(v_ec::text, 'none'),
      'w1_b3:cancel:' || coalesce(v_ec::text, NEW.id::text || ':' || txid_current()::text),
      'event:' || NEW.id::text, NULL);
  END LOOP;

  IF v_ec IS NOT NULL THEN
    UPDATE public.event_changes x SET consumed_by = x.consumed_by || jsonb_build_object('w1_b3', now()) WHERE x.id = v_ec;
  END IF;
  RETURN NULL;
END
$function$;

DROP TRIGGER trg_kan947_events_game_updated_notify ON public.events;
CREATE TRIGGER trg_kan947_events_game_updated_notify
  AFTER UPDATE ON public.events
  FOR EACH ROW
  WHEN (OLD.is_cancelled IS DISTINCT FROM NEW.is_cancelled)
  EXECUTE FUNCTION public.trg_game_updated_notify();

-- 4. old meetup cancel sender off (body from pg_get_functiondef; only the process_notification_event loop removed) --
CREATE OR REPLACE FUNCTION public.rpc_meetup_cancel_kan712_inner(p_meetup_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_creator uuid;
  v_title   text;
begin
  if auth.uid() is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;
  if not exists (
    select 1 from public.meetups m
      join public.events e on e.id = m.id and e.event_type = 'meetup'
    where m.id = p_meetup_id
      and (e.creator_user_id = auth.uid() or public.is_admin(auth.uid()))
  ) then
    raise exception using errcode='P0001', message='not_host';
  end if;
  update public.events
     set is_cancelled = true, updated_at = now()
   where id = p_meetup_id and event_type = 'meetup' and is_cancelled = false
  returning creator_user_id, title into v_creator, v_title;
  if found then
    -- KAN-862: parity onto the legacy meetups columns and the meetups AFTER triggers, without routing back to events.
    perform set_config('kan712.events_first', p_meetup_id::text, true);
    update public.meetups set is_indoor = is_indoor where id = p_meetup_id;
    perform set_config('kan712.events_first', '', true);
    -- KAN-981: meetup.cancelled is sent by trg_game_updated_notify (trigger trg_kan947_events_game_updated_notify on
    -- events) through notify_v2, to going and interested RSVPs. The old per-RSVP sender loop that was here is
    -- removed so the kind has one sender.
    perform public.emit_event('meetup.cancelled','meetup', p_meetup_id, auth.uid(), '{}');
  end if;
  return 'ok';
end;
$function$;

-- 5. the consumer ------------------------------------------------------------------------------------------------------
CREATE INDEX event_changes_w1_b3_pending_idx ON public.event_changes (event_id, id) WHERE NOT (consumed_by ? 'w1_b3');

CREATE FUNCTION public.kan981_consume_event_changes(
    p_now      timestamptz DEFAULT now(),
    p_settle   interval    DEFAULT '60 seconds',
    p_max_wait interval    DEFAULT '5 minutes')
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_mark     jsonb := jsonb_build_object('w1_b3', p_now);
  v_sent     int := 0;
  v_notices  int := 0;
  v_silent   int := 0;
  v_series_n int := 0;
  s          record;
  ev         public.events;
  v_ids      bigint[];
  v_max      bigint;
  v_actors   uuid[];
  v_c        jsonb;
  v_tz       text;
  v_series   uuid;
  v_title_en text;  v_title_ar text;
  f_en text[]; f_ar text[]; o_en text[]; o_ar text[]; n_en text[]; n_ar text[];
  v_time boolean; v_place boolean;
  o_start timestamptz; o_end timestamptz; o_venue uuid; o_area uuid;
  v_o text; v_n text;
  v_kind     text;
  v_args     jsonb;
  v_ec       bigint;
  u          uuid;
  v_id       uuid;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('kan981_consume_event_changes')) THEN
    RETURN jsonb_build_object('skipped', 'locked');
  END IF;

  -- (a) series batches: one transaction touched two or more occurrences of one game series.
  FOR s IN
    WITH ready AS (
      SELECT x.event_id FROM public.event_changes x
       WHERE NOT (x.consumed_by ? 'w1_b3') AND x.occurred_at <= p_now
       GROUP BY x.event_id
      HAVING max(x.occurred_at) <= p_now - p_settle OR min(x.occurred_at) <= p_now - p_max_wait)
    SELECT g.series_id, x.occurred_at, array_agg(DISTINCT x.event_id) AS events,
           array_agg(x.id) AS ids, max(x.id) AS max_id,
           array_agg(DISTINCT x.actor_user_id) FILTER (WHERE x.actor_user_id IS NOT NULL) AS actors
      FROM public.event_changes x
      JOIN ready r ON r.event_id = x.event_id
      JOIN public.games g ON g.event_id = x.event_id
     WHERE NOT (x.consumed_by ? 'w1_b3') AND g.series_id IS NOT NULL
     GROUP BY g.series_id, x.occurred_at
    HAVING count(DISTINCT x.event_id) >= 2
  LOOP
    v_title_en := coalesce(nullif(btrim((SELECT gs.title FROM public.game_series gs WHERE gs.id = s.series_id)), ''),
                           public.kan981_event_title(s.events[1], 'en'));
    v_title_ar := coalesce(nullif(btrim((SELECT gs.title FROM public.game_series gs WHERE gs.id = s.series_id)), ''),
                           public.kan981_event_title(s.events[1], 'ar'));
    v_args := jsonb_build_object('title_en', v_title_en, 'title_ar', v_title_ar,
                                 'occurrences', cardinality(s.events), 'series_id', s.series_id);
    FOR u IN SELECT DISTINCT r FROM unnest(s.events) AS e(id), LATERAL public.kan981_recipients(e.id) AS r
              WHERE r <> ALL (coalesce(s.actors, '{}')) LOOP
      v_id := public.notify_v2(u, 'game.series_changed', v_args, 'game', s.events[1], s.actors[1],
                               'event_changes:' || s.max_id, 'w1_b3:series:' || s.series_id || ':' || s.max_id,
                               'series:' || s.series_id, NULL);
      IF v_id IS NOT NULL THEN v_sent := v_sent + 1; END IF;
    END LOOP;
    UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (s.ids);
    v_series_n := v_series_n + 1;
  END LOOP;

  -- (b) one event at a time.
  FOR s IN
    SELECT x.event_id, array_agg(x.id ORDER BY x.id) AS ids, max(x.id) AS max_id,
           array_agg(DISTINCT x.actor_user_id) FILTER (WHERE x.actor_user_id IS NOT NULL) AS actors
      FROM public.event_changes x
     WHERE NOT (x.consumed_by ? 'w1_b3') AND x.occurred_at <= p_now
     GROUP BY x.event_id
    HAVING max(x.occurred_at) <= p_now - p_settle OR min(x.occurred_at) <= p_now - p_max_wait
  LOOP
    v_ids := s.ids; v_max := s.max_id; v_actors := coalesce(s.actors, '{}');
    SELECT * INTO ev FROM public.events e WHERE e.id = s.event_id;
    IF NOT FOUND THEN
      UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (v_ids);
      CONTINUE;
    END IF;
    v_tz := public.event_timezone(ev.id);
    v_series := NULL;
    IF ev.event_type = 'game' THEN SELECT g.series_id INTO v_series FROM public.games g WHERE g.event_id = ev.id; END IF;
    v_title_en := public.kan981_event_title(ev.id, 'en');
    v_title_ar := public.kan981_event_title(ev.id, 'ar');

    -- collapse: first old, last new, per field; drop fields that ended where they started
    SELECT coalesce(jsonb_object_agg(c.field, jsonb_build_object('o', c.o, 'n', c.n)), '{}'::jsonb) INTO v_c
      FROM (SELECT x.field,
                   (array_agg(x.old_value ORDER BY x.id))[1]      AS o,
                   (array_agg(x.new_value ORDER BY x.id DESC))[1] AS n
              FROM public.event_changes x WHERE x.id = ANY (v_ids) GROUP BY x.field) c
     WHERE c.o IS DISTINCT FROM c.n;

    -- cancel of a series occurrence (single events are sent at once by trg_game_updated_notify)
    IF ev.is_cancelled AND v_c ? 'is_cancelled' THEN
      SELECT max(x.id) INTO v_ec FROM public.event_changes x WHERE x.id = ANY (v_ids) AND x.field = 'is_cancelled';
      v_kind := CASE WHEN v_series IS NOT NULL THEN 'game.occurrence_cancelled' ELSE ev.event_type || '.cancelled' END;
      v_args := jsonb_build_object('title_en', v_title_en, 'title_ar', v_title_ar,
                                   'when_en', public.kan981_fmt_span(ev.start_at, ev.end_at, v_tz, 'en'),
                                   'when_ar', public.kan981_fmt_span(ev.start_at, ev.end_at, v_tz, 'ar'));
      FOR u IN SELECT r FROM public.kan981_recipients(ev.id) AS r WHERE r <> ALL (v_actors) LOOP
        v_id := public.notify_v2(u, v_kind, v_args, ev.event_type, ev.id, coalesce(v_actors[1], ev.creator_user_id),
                                 'event_changes:' || v_ec, 'w1_b3:cancel:' || v_ec, 'event:' || ev.id, NULL);
        IF v_id IS NOT NULL THEN v_sent := v_sent + 1; END IF;
      END LOOP;
      v_notices := v_notices + 1;
      UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (v_ids);
      CONTINUE;
    END IF;

    -- a cancelled event gets no change notice; a past event neither
    IF ev.is_cancelled
       OR (ev.start_at < p_now AND coalesce((v_c #>> '{start_at,o}')::timestamptz, ev.start_at) < p_now) THEN
      UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (v_ids);
      v_silent := v_silent + 1;
      CONTINUE;
    END IF;

    f_en := '{}'; f_ar := '{}'; o_en := '{}'; o_ar := '{}'; n_en := '{}'; n_ar := '{}';
    v_time := false; v_place := false;

    IF v_c ? 'start_at' OR v_c ? 'end_at' THEN
      o_start := CASE WHEN v_c ? 'start_at' THEN (v_c #>> '{start_at,o}')::timestamptz ELSE ev.start_at END;
      o_end   := CASE WHEN v_c ? 'end_at'   THEN (v_c #>> '{end_at,o}')::timestamptz   ELSE ev.end_at   END;
      v_time := true;
      f_en := f_en || public.kan981_value_label('field', 'time', 'en');
      f_ar := f_ar || public.kan981_value_label('field', 'time', 'ar');
      o_en := o_en || public.kan981_fmt_span(o_start, o_end, v_tz, 'en');
      o_ar := o_ar || public.kan981_fmt_span(o_start, o_end, v_tz, 'ar');
      n_en := n_en || public.kan981_fmt_span(ev.start_at, ev.end_at, v_tz, 'en');
      n_ar := n_ar || public.kan981_fmt_span(ev.start_at, ev.end_at, v_tz, 'ar');
    END IF;

    IF v_c ? 'venue_id' OR v_c ? 'area_id' OR v_c ? 'geo_location_id' THEN
      o_venue := CASE WHEN v_c ? 'venue_id' THEN (v_c #>> '{venue_id,o}')::uuid ELSE ev.venue_id END;
      o_area  := CASE WHEN v_c ? 'area_id'  THEN (v_c #>> '{area_id,o}')::uuid  ELSE ev.area_id  END;
      v_o := public.kan981_place_name(o_venue, o_area, 'en');
      v_n := public.kan981_place_name(ev.venue_id, ev.area_id, 'en');
      IF v_o IS DISTINCT FROM v_n THEN
        v_place := true;
        f_en := f_en || public.kan981_value_label('field', 'place', 'en');
        f_ar := f_ar || public.kan981_value_label('field', 'place', 'ar');
        o_en := o_en || v_o;
        n_en := n_en || v_n;
        o_ar := o_ar || public.kan981_place_name(o_venue, o_area, 'ar');
        n_ar := n_ar || public.kan981_place_name(ev.venue_id, ev.area_id, 'ar');
      END IF;
    END IF;

    IF v_c ? 'capacity' THEN
      f_en := f_en || public.kan981_value_label('field', 'capacity', 'en');
      f_ar := f_ar || public.kan981_value_label('field', 'capacity', 'ar');
      o_en := o_en || public.kan981_value_label('capacity', v_c #>> '{capacity,o}', 'en');
      o_ar := o_ar || public.kan981_value_label('capacity', v_c #>> '{capacity,o}', 'ar');
      n_en := n_en || public.kan981_value_label('capacity', ev.capacity::text, 'en');
      n_ar := n_ar || public.kan981_value_label('capacity', ev.capacity::text, 'ar');
    END IF;

    IF v_c ? 'join_policy' THEN
      f_en := f_en || public.kan981_value_label('field', 'join_policy', 'en');
      f_ar := f_ar || public.kan981_value_label('field', 'join_policy', 'ar');
      o_en := o_en || public.kan981_value_label('join_policy', v_c #>> '{join_policy,o}', 'en');
      o_ar := o_ar || public.kan981_value_label('join_policy', v_c #>> '{join_policy,o}', 'ar');
      n_en := n_en || public.kan981_value_label('join_policy', ev.join_policy, 'en');
      n_ar := n_ar || public.kan981_value_label('join_policy', ev.join_policy, 'ar');
    END IF;

    IF v_c ? 'joining_rule' OR v_c ? 'cost_cover' THEN
      v_o := coalesce(v_c #>> '{joining_rule,o}', ev.joining_rule);
      v_n := coalesce(v_c #>> '{cost_cover,o}', ev.cost_cover);
      f_en := f_en || public.kan981_value_label('field', 'joining_rule', 'en');
      f_ar := f_ar || public.kan981_value_label('field', 'joining_rule', 'ar');
      o_en := o_en || (public.kan981_value_label('joining_rule', v_o, 'en')
                       || CASE WHEN v_n <> v_o THEN ' (' || public.kan981_value_label('joining_rule', v_n, 'en') || ')' ELSE '' END);
      o_ar := o_ar || (public.kan981_value_label('joining_rule', v_o, 'ar')
                       || CASE WHEN v_n <> v_o THEN ' (' || public.kan981_value_label('joining_rule', v_n, 'ar') || ')' ELSE '' END);
      n_en := n_en || (public.kan981_value_label('joining_rule', ev.joining_rule, 'en')
                       || CASE WHEN ev.cost_cover <> ev.joining_rule
                               THEN ' (' || public.kan981_value_label('joining_rule', ev.cost_cover, 'en') || ')' ELSE '' END);
      n_ar := n_ar || (public.kan981_value_label('joining_rule', ev.joining_rule, 'ar')
                       || CASE WHEN ev.cost_cover <> ev.joining_rule
                               THEN ' (' || public.kan981_value_label('joining_rule', ev.cost_cover, 'ar') || ')' ELSE '' END);
    END IF;

    IF v_c ? 'min_skill' OR v_c ? 'max_skill' THEN
      v_o := CASE WHEN coalesce(v_c #>> '{min_skill,o}', ev.min_skill::text) IS NULL
                   AND coalesce(v_c #>> '{max_skill,o}', ev.max_skill::text) IS NULL THEN NULL
                  ELSE coalesce(CASE WHEN v_c ? 'min_skill' THEN v_c #>> '{min_skill,o}' ELSE ev.min_skill::text END, '1')
                       || '–' ||
                       coalesce(CASE WHEN v_c ? 'max_skill' THEN v_c #>> '{max_skill,o}' ELSE ev.max_skill::text END, '10') END;
      v_n := CASE WHEN ev.min_skill IS NULL AND ev.max_skill IS NULL THEN NULL
                  ELSE coalesce(ev.min_skill::text, '1') || '–' || coalesce(ev.max_skill::text, '10') END;
      f_en := f_en || public.kan981_value_label('field', 'skill', 'en');
      f_ar := f_ar || public.kan981_value_label('field', 'skill', 'ar');
      o_en := o_en || coalesce(v_o, 'Any');      o_ar := o_ar || coalesce(v_o, 'أي مستوى');
      n_en := n_en || coalesce(v_n, 'Any');      n_ar := n_ar || coalesce(v_n, 'أي مستوى');
    END IF;

    IF cardinality(f_en) = 0 THEN
      UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (v_ids);
      v_silent := v_silent + 1;
      CONTINUE;
    END IF;

    v_kind := ev.event_type || CASE WHEN v_time THEN '.time_changed' WHEN v_place THEN '.venue_changed'
                                    ELSE '.details_changed' END;
    v_args := jsonb_build_object(
      'title_en', v_title_en, 'title_ar', v_title_ar,
      'field_en', array_to_string(f_en, ', '), 'field_ar', array_to_string(f_ar, '، '),
      'old_en', array_to_string(o_en, ' · '), 'old_ar', array_to_string(o_ar, ' · '),
      'new_en', array_to_string(n_en, ' · '), 'new_ar', array_to_string(n_ar, ' · '),
      'changes', (SELECT jsonb_agg(jsonb_build_object('field_en', f_en[i], 'field_ar', f_ar[i],
                                                      'old_en', o_en[i], 'old_ar', o_ar[i],
                                                      'new_en', n_en[i], 'new_ar', n_ar[i]) ORDER BY i)
                    FROM generate_subscripts(f_en, 1) AS i),
      'schedule_revision', ev.schedule_revision);

    FOR u IN SELECT r FROM public.kan981_recipients(ev.id) AS r WHERE r <> ALL (v_actors) LOOP
      v_id := public.notify_v2(u, v_kind, v_args, ev.event_type, ev.id,
                               coalesce(v_actors[array_upper(v_actors, 1)], ev.creator_user_id),
                               'event_changes:' || v_ids[1] || '-' || v_max,
                               'w1_b3:change:' || ev.id || ':' || v_max, 'event:' || ev.id, NULL);
      IF v_id IS NOT NULL THEN v_sent := v_sent + 1; END IF;
    END LOOP;
    v_notices := v_notices + 1;
    UPDATE public.event_changes x SET consumed_by = x.consumed_by || v_mark WHERE x.id = ANY (v_ids);
  END LOOP;

  RETURN jsonb_build_object('notices', v_notices, 'series', v_series_n, 'silent', v_silent, 'sent', v_sent);
END
$function$;

-- 6. kinds ---------------------------------------------------------------------------------------------------------------
UPDATE public.notification_kinds SET is_active = true
 WHERE key IN ('game.cancelled', 'game.time_changed', 'game.venue_changed', 'game.details_changed',
               'game.occurrence_cancelled', 'game.series_changed',
               'meetup.time_changed', 'meetup.venue_changed', 'meetup.details_changed');
UPDATE public.notification_kinds SET is_active = false WHERE key = 'game.updated';

-- 7. grants ------------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.kan981_recipients(uuid)                          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan981_fmt_span(timestamptz, timestamptz, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan981_value_label(text, text, text)             FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan981_place_name(uuid, uuid, text)              FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan981_event_title(uuid, text)                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan981_consume_event_changes(timestamptz, interval, interval) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kan981_consume_event_changes(timestamptz, interval, interval) TO service_role;

-- 8. schedule, and nothing older than this migration is announced --------------------------------------------------------
UPDATE public.event_changes x SET consumed_by = x.consumed_by || jsonb_build_object('w1_b3', now())
 WHERE NOT (x.consumed_by ? 'w1_b3');

SELECT cron.schedule('kan981_event_changes_every_minute', '* * * * *',
                     $cron$SELECT public.kan981_consume_event_changes()$cron$);

-- 9. post asserts ------------------------------------------------------------------------------------------------------
DO $post$
DECLARE f text;
BEGIN
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('game.cancelled', 'game.time_changed', 'game.venue_changed', 'game.details_changed',
                     'game.occurrence_cancelled', 'game.series_changed', 'meetup.time_changed',
                     'meetup.venue_changed', 'meetup.details_changed', 'meetup.cancelled') AND is_active) <> 10
     OR (SELECT is_active FROM public.notification_kinds WHERE key = 'game.updated')
     OR (SELECT count(*) FROM public.notification_kinds
          WHERE key IN ('meetup.occurrence_cancelled', 'meetup.series_changed') AND NOT is_active) <> 2 THEN
    RAISE EXCEPTION 'kan981 post: kind states not as intended';
  END IF;
  IF (SELECT pg_get_triggerdef(t.oid) FROM pg_trigger t
       WHERE t.tgrelid = 'public.events'::regclass AND t.tgname = 'trg_kan947_events_game_updated_notify')
     IS DISTINCT FROM 'CREATE TRIGGER trg_kan947_events_game_updated_notify AFTER UPDATE ON public.events FOR EACH ROW WHEN ((old.is_cancelled IS DISTINCT FROM new.is_cancelled)) EXECUTE FUNCTION trg_game_updated_notify()'
     OR (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND NOT tgisinternal) <> 13 THEN
    RAISE EXCEPTION 'kan981 post: events trigger set not as intended';
  END IF;
  f := pg_get_functiondef('public.trg_game_updated_notify()'::regprocedure);
  IF position('game.updated' IN f) > 0 OR position('process_notification_event' IN f) > 0
     OR position('process_notification_event' IN pg_get_functiondef('public.rpc_meetup_cancel_kan712_inner(uuid)'::regprocedure)) > 0 THEN
    RAISE EXCEPTION 'kan981 post: an old sender is still in place';
  END IF;
  IF has_function_privilege('anon', 'public.kan981_consume_event_changes(timestamptz,interval,interval)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.kan981_consume_event_changes(timestamptz,interval,interval)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.kan981_recipients(uuid)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.kan981_recipients(uuid)', 'EXECUTE')
     OR (SELECT proacl::text FROM pg_proc WHERE oid = 'public.rpc_meetup_cancel_kan712_inner(uuid)'::regprocedure)
        IS DISTINCT FROM '{postgres=X/postgres}' THEN
    RAISE EXCEPTION 'kan981 post: function ACLs not as intended';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan981_event_changes_every_minute' AND schedule = '* * * * *' AND active)
     OR to_regclass('public.event_changes_w1_b3_pending_idx') IS NULL THEN
    RAISE EXCEPTION 'kan981 post: cron job or index missing';
  END IF;
END $post$;
