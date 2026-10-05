-- KAN-431 WP5 -- Meetups notifications: the three v1 pushes.
--
-- AUTHORED, NOT APPLIED. Applying is a CEO-approved step (G-002 / T-020). This file
-- inserts catalogue rows (new keys only) and adds two triggers + two trigger
-- functions. It deletes, truncates and rewrites NO existing row.
--
-- WHY THIS EXISTS (spike: /Users/moataz/.claude/jobs/1ee27200/tmp/result-kan431-spike.md).
-- The meetup RPCs call public.emit_event('meetup.*', ...). emit_event is a
-- no-op shim (baseline 20260829080500 line 5430-5439: "no-op shim for dev",
-- `return;`), so NO meetup.* event ever becomes a notification or a push. The
-- only things that notify today are (1) trg_meetup_invite_notify and (2) the
-- chain meetup_rsvps INSERT status='going' -> fn_meetup_rsvps_activity_sync ->
-- public_activities 'meetup_join' -> fn_public_activities_notify ->
-- meetup.player_joined. Nothing handles request / approve / decline / cancel.
--
-- WHAT THIS DOES (games precedent: trg_game_join_request_notify,
-- trg_game_updated_notify, rpc_decide_join_request all call
-- public.process_notification_event directly, not emit_event):
--   1. Five notification_kinds rows (EN + Modern Standard Arabic labels):
--      meetup.rsvp_received, meetup.request_received, meetup.request_approved,
--      meetup.request_declined, meetup.cancelled. normal / {inapp,push}.
--   2. trg_meetup_rsvps_notify (AFTER INSERT OR UPDATE OF status ON meetup_rsvps):
--        host told when an attendee flips to 'going' (re-RSVP, see below) or
--        asks to join ('pending'); attendee told when the HOST approves
--        (pending -> going | interested) or declines (pending -> cancelled/declined).
--   3. trg_meetups_cancel_notify (AFTER UPDATE OF is_cancelled ON meetups):
--        every going / interested / pending attendee except the actor is told.
--
-- WHY TRIGGERS AND NOT EDITS TO THE KAN-427 RPCs. The RPC bodies (rpc_meetup_rsvp,
-- rpc_meetup_decide_request, rpc_meetup_cancel, rpc_meetup_remove_attendee) are
-- NOT restated here, so none of their fixes can be lost. Every state change
-- lands on a meetup_rsvps / meetups row, which the triggers see regardless of
-- which RPC wrote it.
--
-- DEDUPLICATION AGAINST THE EXISTING 'going' CHAIN. A fresh INSERT of a 'going'
-- row already notifies the host through meetup.player_joined (the activity
-- chain above). This migration therefore does NOT notify on INSERT ... 'going';
-- it only covers the 'going' transitions that chain never sees (UPDATE
-- interested/cancelled/declined/pending -> going, which is what the
-- ON CONFLICT DO UPDATE branch of rpc_meetup_rsvp produces). One notification
-- per recipient per event. The host's own 'going' row (rpc_create_meetup) is an
-- INSERT by the host about the host: never notified by either path.
--
-- ACTOR RULES. The actor is auth.uid() (never caller-supplied).
--   * approve / decline are recognised as "somebody other than the attendee
--     changed a pending row": auth.uid() IS NOT NULL AND <> NEW.user_id. A
--     self-cancel of a pending request (auth.uid() = NEW.user_id) therefore
--     never produces a "declined" notice. rpc_meetup_remove_attendee on a
--     pending row also reads as a decline: the attendee's request is gone.
--   * the recipient is never the actor (host-self requests, host-self RSVPs and
--     the host cancelling their own meet-up are all skipped).
--   * auth.uid() IS NULL (service role / maintenance SQL) sends nothing for
--     approve/decline; it does notify attendees of a cancel.
--
-- SETTINGS. Delivery goes through public.process_notification_event, which
-- inserts the in-app notifications row; trg_push_on_notification_insert (baseline
-- line 18204) then enforces push_enabled, muted_kinds and quiet hours before any
-- net.http_post. Nothing is re-implemented here, so there is nothing to drift.
--
-- PERMISSIONS. process_notification_event is executable only by postgres and
-- service_role (KAN-182). Both trigger functions are SECURITY DEFINER, owned by
-- postgres, search_path pinned, and revoked from PUBLIC/anon/authenticated
-- (pg_default_acl grants anon on new functions by name; asserted below).
--
-- BEFORE APPLYING: diff against the live catalogue (T-058), see the spike note
-- section "Diff before apply": process_notification_event (body + proacl),
-- fn_meetup_rsvps_activity_sync, fn_public_activities_notify,
-- trg_push_on_notification_insert, trgfn_meetups_outbox, the notification_kinds
-- column list, and the absence of the five new keys and the two new triggers.

BEGIN;

-- ============================================================================
-- (a) notification_kinds. Column list matches live: key, label_en, label_ar,
--     default_priority, default_channels, route_template, timing, is_active
--     (created_at defaults). New keys only; ON CONFLICT DO NOTHING means a
--     re-run never touches an existing row.
--     Arabic: Modern Standard Arabic, one register; for content-2 review.
-- ============================================================================
INSERT INTO public.notification_kinds
  (key, label_en, label_ar, default_priority, default_channels, route_template, timing, is_active)
VALUES
  ('meetup.rsvp_received',
   'Someone is going to your meet-up',
   'شخص سيحضر لقاءك',
   'normal'::public.notify_priority, '{inapp,push}'::public.notify_channel[],
   '/meetups/{entity_id}', NULL, true),
  ('meetup.request_received',
   'Someone asked to join your meet-up',
   'شخص طلب الانضمام إلى لقائك',
   'normal'::public.notify_priority, '{inapp,push}'::public.notify_channel[],
   '/meetups/{entity_id}', NULL, true),
  ('meetup.request_approved',
   'Your request to join a meet-up was approved',
   'تمت الموافقة على طلب انضمامك إلى اللقاء',
   'normal'::public.notify_priority, '{inapp,push}'::public.notify_channel[],
   '/meetups/{entity_id}', NULL, true),
  ('meetup.request_declined',
   'Your request to join a meet-up was declined',
   'تم رفض طلب انضمامك إلى اللقاء',
   'normal'::public.notify_priority, '{inapp,push}'::public.notify_channel[],
   '/meetups/{entity_id}', NULL, true),
  ('meetup.cancelled',
   'A meet-up you signed up for was cancelled',
   'تم إلغاء لقاء كنت قد سجّلت فيه',
   'normal'::public.notify_priority, '{inapp,push}'::public.notify_channel[],
   '/meetups/{entity_id}', NULL, true)
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- (b) meetup_rsvps -> host (going re-RSVP, request) and attendee (approve, decline)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_meetup_rsvps_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor      uuid := auth.uid();
  v_host_uid   uuid;
  v_title      text;
  v_name       text;
  v_old        text;
BEGIN
  -- OLD is unassigned on INSERT, so read it once, guarded.
  IF TG_OP = 'UPDATE' THEN v_old := OLD.status; END IF;

  -- Only status changes (and brand-new rows) are events.
  IF TG_OP = 'UPDATE' AND v_old IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT m.creator_user_id, m.title INTO v_host_uid, v_title
    FROM public.meetups m WHERE m.id = NEW.meetup_id;
  IF v_host_uid IS NULL THEN RETURN NEW; END IF;

  SELECT p.display_name INTO v_name
    FROM public.profiles p
   WHERE p.user_id = NEW.user_id AND p.is_active = true
   LIMIT 1;
  v_name := COALESCE(v_name, 'Someone');

  -- Someone asks to join (request policy): tell the host. Never the host's own row.
  IF NEW.status = 'pending'
     AND v_old IS DISTINCT FROM 'pending'
  THEN
    IF NEW.user_id <> v_host_uid THEN
      PERFORM public.process_notification_event(
        v_host_uid, 'meetup.request_received', 'meetup', NEW.meetup_id, NEW.user_id,
        v_name || ' asked to join your meet-up', v_title);
    END IF;
    RETURN NEW;
  END IF;

  -- Attendee flips to 'going' themselves (UPDATE only: a fresh INSERT is covered
  -- by the existing meetup.player_joined chain; see header).
  IF TG_OP = 'UPDATE' AND NEW.status = 'going'
     AND v_actor IS NOT NULL AND v_actor = NEW.user_id
  THEN
    IF NEW.user_id <> v_host_uid THEN
      PERFORM public.process_notification_event(
        v_host_uid, 'meetup.rsvp_received', 'meetup', NEW.meetup_id, NEW.user_id,
        v_name || ' is going to your meet-up', v_title);
    END IF;
    RETURN NEW;
  END IF;

  -- Somebody else (the host or an admin) decides a pending request: tell the attendee.
  IF TG_OP = 'UPDATE' AND v_old = 'pending'
     AND v_actor IS NOT NULL AND v_actor <> NEW.user_id
  THEN
    IF NEW.status = 'going' THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_approved', 'meetup', NEW.meetup_id, v_actor,
        'You''re in! Your request to join was approved', v_title);
    ELSIF NEW.status = 'interested' THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_approved', 'meetup', NEW.meetup_id, v_actor,
        'Your request was approved, but the meet-up is full', v_title);
    ELSIF NEW.status IN ('cancelled', 'declined') THEN
      PERFORM public.process_notification_event(
        NEW.user_id, 'meetup.request_declined', 'meetup', NEW.meetup_id, v_actor,
        'Your request to join was declined', v_title);
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

ALTER FUNCTION public.trg_meetup_rsvps_notify() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.trg_meetup_rsvps_notify() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE TRIGGER trg_meetup_rsvps_notify
  AFTER INSERT OR UPDATE OF status ON public.meetup_rsvps
  FOR EACH ROW EXECUTE FUNCTION public.trg_meetup_rsvps_notify();

-- ============================================================================
-- (c) meetups cancelled -> going / interested / pending attendees except the actor
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_meetups_cancel_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  r       record;
BEGIN
  IF NOT (NEW.is_cancelled IS TRUE AND OLD.is_cancelled IS DISTINCT FROM TRUE) THEN
    RETURN NEW;
  END IF;

  FOR r IN
    SELECT DISTINCT s.user_id
      FROM public.meetup_rsvps s
     WHERE s.meetup_id = NEW.id
       AND s.status IN ('going', 'interested', 'pending')
       AND s.user_id IS DISTINCT FROM v_actor
  LOOP
    PERFORM public.process_notification_event(
      r.user_id, 'meetup.cancelled', 'meetup', NEW.id,
      COALESCE(v_actor, NEW.creator_user_id),
      'A meet-up you signed up for was cancelled', NEW.title);
  END LOOP;

  RETURN NEW;
END;
$function$;

ALTER FUNCTION public.trg_meetups_cancel_notify() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.trg_meetups_cancel_notify() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE TRIGGER trg_meetups_cancel_notify
  AFTER UPDATE OF is_cancelled ON public.meetups
  FOR EACH ROW
  WHEN (NEW.is_cancelled IS TRUE AND OLD.is_cancelled IS DISTINCT FROM TRUE)
  EXECUTE FUNCTION public.trg_meetups_cancel_notify();

-- ============================================================================
-- (d) Post-conditions: assert the resulting state, not that statements ran.
-- ============================================================================
DO $$
DECLARE
  v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM public.notification_kinds
   WHERE key IN ('meetup.rsvp_received','meetup.request_received','meetup.request_approved',
                 'meetup.request_declined','meetup.cancelled')
     AND is_active AND length(label_en) > 0 AND length(label_ar) > 0
     AND default_channels @> '{push}'::public.notify_channel[];
  IF v_n <> 5 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: % of 5 meetup notification kinds present and push-enabled', v_n;
  END IF;

  SELECT count(*) INTO v_n FROM pg_trigger t
   WHERE NOT t.tgisinternal AND t.tgenabled = 'O'
     AND ((t.tgname = 'trg_meetup_rsvps_notify' AND t.tgrelid = 'public.meetup_rsvps'::regclass)
       OR (t.tgname = 'trg_meetups_cancel_notify' AND t.tgrelid = 'public.meetups'::regclass));
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: % of 2 notification triggers installed and enabled', v_n;
  END IF;

  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.oid IN ('public.trg_meetup_rsvps_notify()'::regprocedure,
                   'public.trg_meetups_cancel_notify()'::regprocedure)
     AND p.prosecdef
     AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: trigger functions not definer / search_path pinned / revoked (% of 2)', v_n;
  END IF;

  IF has_function_privilege('authenticated',
       'public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'POST-CONDITION FAILED: authenticated can execute process_notification_event (KAN-182 regressed)';
  END IF;
END $$;

COMMIT;
