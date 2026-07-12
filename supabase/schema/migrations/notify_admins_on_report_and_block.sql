-- Applied to remote as migration version 20260701171138.
--
-- Guideline 1.2: the developer must be notified of reported/blocked
-- content so it can be actioned in a timely manner. Reuse the existing
-- notifications table + push pipeline (trg_push_on_notification_insert
-- already fires push for any insert into public.notifications) by
-- fanning a notification out to every row in public.app_admins whenever
-- a moderation report is submitted or a user is blocked.

INSERT INTO public.notification_kinds (key, label_en, label_ar, default_priority, default_channels, is_active)
VALUES
  ('moderation.report_submitted', 'New content report', 'بلاغ جديد عن محتوى', 'high', '{inapp,push}', true),
  ('moderation.user_blocked', 'User block recorded', 'تم تسجيل حظر مستخدم', 'low', '{inapp}', true)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.notify_admins_of_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.notifications (to_user_id, kind_key, title, body, context, priority)
  SELECT
    a.user_id,
    'moderation.report_submitted',
    'New content report',
    format('%s reported for %s', NEW.target_type::text, NEW.reason::text),
    jsonb_build_object(
      'report_id', NEW.id,
      'target_type', NEW.target_type,
      'target_id', NEW.target_id,
      'reason', NEW.reason
    ),
    'high'
  FROM public.app_admins a;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_notify_admins_of_report
  AFTER INSERT ON public.moderation_reports
  FOR EACH ROW EXECUTE FUNCTION public.notify_admins_of_report();

CREATE OR REPLACE FUNCTION public.notify_admins_of_block()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.notifications (to_user_id, kind_key, title, body, context, priority)
  SELECT
    a.user_id,
    'moderation.user_blocked',
    'User block recorded',
    'A user blocked another user.',
    jsonb_build_object(
      'blocker_user_id', NEW.blocker_user_id,
      'blocked_user_id', NEW.blocked_user_id
    ),
    'low'
  FROM public.app_admins a;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_notify_admins_of_block
  AFTER INSERT ON public.user_blocks
  FOR EACH ROW EXECUTE FUNCTION public.notify_admins_of_block();
