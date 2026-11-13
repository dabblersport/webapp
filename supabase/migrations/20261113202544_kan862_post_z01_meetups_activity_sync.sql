-- KAN-862 post-Z01 fix-forward: meetup creation raised 23503 public_activities_parent_activity_id_fkey after Z01
-- (20261113202013). Z01 seq 320 dropped tr_meetups_activity_sync, whose INSERT branch writes the meetup's own
-- public_activities row (id = meetup id, 'meetup_create'). The host RSVP that every meetup writer inserts fires
-- tr_meetup_rsvps_activity_sync, which inserts a 'meetup_join' activity with parent_activity_id = meetup id, so without
-- the parent row every create failed. Found by supabase/tests/events_p4/kan862_post_z01_smoke_test.sql (call 1).
--
-- Fix: the trigger function re-authored from the live pg_get_functiondef (md5 0de4811d894c72255b51eba5b8b0108d),
-- reading the values Z01 removed from public.events (the events parent is written before the meetups row, and
-- kan712/events parity means the values are those the old NEW.* carried). Same name, attributes (SECURITY DEFINER,
-- search_path public), owner and ACL; the trigger is re-created exactly as in the baseline (AFTER INSERT OR UPDATE).
-- The UPDATE branch keeps its meaning: is_deleted follows events.is_cancelled.
DO $pre$
BEGIN
  IF md5(pg_get_functiondef('public.fn_meetups_activity_sync()'::regprocedure)) IS DISTINCT FROM '0de4811d894c72255b51eba5b8b0108d' THEN
    RAISE EXCEPTION 'KAN-862 fix: fn_meetups_activity_sync is not the pre-image this was authored from';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.meetups'::regclass AND tgname = 'tr_meetups_activity_sync') THEN
    RAISE EXCEPTION 'KAN-862 fix: tr_meetups_activity_sync already exists';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attname = 'creator_user_id' AND NOT attisdropped) THEN
    RAISE EXCEPTION 'KAN-862 fix: Z01 has not been applied';
  END IF;
END $pre$;

CREATE OR REPLACE FUNCTION public.fn_meetups_activity_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  e public.events%ROWTYPE;   -- KAN-862 post-Z01: the shared meetup values live on events
BEGIN
  SELECT * INTO e FROM public.events WHERE id = NEW.id AND event_type = 'meetup';
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.public_activities
      (id, activity_type, source_table,
       actor_user_id, actor_profile_id, target_profile_id,
       visibility, sport_id, area_id, geo_location_id,
       is_deleted, is_hidden_admin, is_pinned,
       occurred_at, created_at, updated_at)
    VALUES (
      NEW.id, 'meetup_create', 'meetups',
      e.creator_user_id, e.creator_profile_id, e.creator_profile_id,
      'public', e.sport_id, e.area_id, e.geo_location_id,
      false, false, false,
      e.created_at, e.created_at, e.updated_at
    )
    ON CONFLICT (id) DO NOTHING;

  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.public_activities
    SET is_deleted = COALESCE(e.is_cancelled, false),
        updated_at = e.updated_at
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER tr_meetups_activity_sync AFTER INSERT OR UPDATE ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.fn_meetups_activity_sync();

DO $post$
BEGIN
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.fn_meetups_activity_sync()'::regprocedure) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
     OR NOT (SELECT prosecdef FROM pg_proc WHERE oid = 'public.fn_meetups_activity_sync()'::regprocedure)
     OR (SELECT proconfig::text FROM pg_proc WHERE oid = 'public.fn_meetups_activity_sync()'::regprocedure) IS DISTINCT FROM '{search_path=public}'
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.meetups'::regclass AND tgname = 'tr_meetups_activity_sync' AND tgenabled = 'O') THEN
    RAISE EXCEPTION 'KAN-862 fix post: ACL/attributes changed or trigger missing';
  END IF;
END $post$;
