-- KAN-981 rollback: undoes 20261117102109_kan981_event_change_notices, nothing else.
-- Run as postgres on wtncuzcskpigqpmnxwws only if KAN-981 must be undone. Restores the pre-image read 2026-11-17
-- (Jira KAN-981 claim 16431): the game.updated cancel loop, the game-only trigger, the meetup cancel loop inside
-- rpc_meetup_cancel_kan712_inner and the kind states. Notifications already sent stay in the inbox.
BEGIN;
SELECT cron.unschedule('kan981_event_changes_every_minute');
DROP FUNCTION public.kan981_consume_event_changes(timestamptz, interval, interval);
DROP INDEX public.event_changes_w1_b3_pending_idx;

DROP TRIGGER trg_kan947_events_game_updated_notify ON public.events;
CREATE OR REPLACE FUNCTION public.trg_game_updated_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_player RECORD;
BEGIN
  IF OLD.is_cancelled = false AND NEW.is_cancelled = true THEN
    FOR v_player IN
      SELECT user_id FROM public.game_roster WHERE game_id = NEW.id AND user_id <> NEW.creator_user_id
    LOOP
      PERFORM public.process_notification_event(v_player.user_id, 'game.updated', 'game', NEW.id, NEW.creator_user_id);
    END LOOP;
  END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_kan947_events_game_updated_notify AFTER UPDATE ON public.events FOR EACH ROW
  WHEN (((new.event_type = 'game'::text) AND (old.is_cancelled IS DISTINCT FROM new.is_cancelled)))
  EXECUTE FUNCTION trg_game_updated_notify();

CREATE OR REPLACE FUNCTION public.rpc_meetup_cancel_kan712_inner(p_meetup_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_creator uuid;
  v_title   text;
  v_rcpt    record;
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
    -- KAN-862: what trg_meetups_cancel_notify sent (it fired on UPDATE OF meetups.is_cancelled, which is no longer named).
    for v_rcpt in
      select distinct s.user_id
        from public.meetup_rsvps s
       where s.meetup_id = p_meetup_id
         and s.status in ('going', 'interested', 'pending')
         and s.user_id is distinct from auth.uid()
    loop
      perform public.process_notification_event(
        v_rcpt.user_id, 'meetup.cancelled', 'meetup', p_meetup_id,
        coalesce(auth.uid(), v_creator),
        'A meet-up you signed up for was cancelled', v_title);
    end loop;
    perform public.emit_event('meetup.cancelled','meetup', p_meetup_id, auth.uid(), '{}');
  end if;
  return 'ok';
end;
$function$;

DROP FUNCTION public.kan981_recipients(uuid);
DROP FUNCTION public.kan981_fmt_span(timestamptz, timestamptz, text, text);
DROP FUNCTION public.kan981_value_label(text, text, text);
DROP FUNCTION public.kan981_place_name(uuid, uuid, text);
DROP FUNCTION public.kan981_event_title(uuid, text);

UPDATE public.notification_kinds SET is_active = false
 WHERE key IN ('game.cancelled', 'game.time_changed', 'game.venue_changed', 'game.details_changed',
               'game.occurrence_cancelled', 'game.series_changed',
               'meetup.time_changed', 'meetup.venue_changed', 'meetup.details_changed');
UPDATE public.notification_kinds SET is_active = true WHERE key = 'game.updated';
COMMIT;
