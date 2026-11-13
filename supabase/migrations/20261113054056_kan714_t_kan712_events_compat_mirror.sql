-- KAN-924 (Epic KAN-708, KAN-714 chain T; KAN-718 phase 2): drop trigger public.events.trg_zz_kan712_events_compat_mirror
-- and its function public.kan712_events_compat_mirror().
--
-- Live catalogue, 2026-11-13 (project wtncuzcskpigqpmnxwws):
--   * The mirror copied a direct events UPDATE onto games / meetups. The only SQL writers of public.events are
--     kan712_legacy_guard (its own events UPDATE runs with kan712.routing set, which the mirror already skips),
--     kan718_game_event_sync (writes events after games, both already equal) and kan712_update_event_shared
--     (no caller; prosrc grep). Meetups: their writes go through the meetups guard, which the mirror skipped,
--     so the meetups write path does not change.
--   * events grants INSERT/UPDATE/DELETE to postgres and service_role only; authenticated and anon cannot write it.
--   * The function is used by this one trigger only (pg_trigger) and named in no other function body.
--   * After this migration kan712_update_event_shared fails closed with 55000 kan712_not_cut_over (its own
--     guard checks for this trigger). It has no caller; it is left as is.
-- No CASCADE. The guard refuses on drift.
-- Test: supabase/tests/events_p4/kan714_t_kan712_events_compat_mirror_test.sql.
do $guard$
declare v_oid oid := to_regprocedure('public.kan712_events_compat_mirror()');
begin
  if v_oid is null or md5(pg_get_functiondef(v_oid)) <> '60edfc4c7ffe6939a00c7811fbfdbc42' then
    raise exception 'KAN-924 pre: kan712_events_compat_mirror() absent or drifted';
  end if;
  if (select count(*) from pg_trigger where tgfoid = v_oid) <> 1
     or not exists (select 1 from pg_trigger where tgfoid = v_oid and tgname = 'trg_zz_kan712_events_compat_mirror'
                    and tgrelid = 'public.events'::regclass and tgenabled = 'O') then
    raise exception 'KAN-924 pre: trg_zz_kan712_events_compat_mirror is not the single, enabled user of the function';
  end if;
  if exists (select 1 from pg_proc where prosrc ~ 'kan712_events_compat_mirror\(' and oid <> v_oid) then
    raise exception 'KAN-924 pre: another function calls kan712_events_compat_mirror()';
  end if;
end
$guard$;

DROP TRIGGER trg_zz_kan712_events_compat_mirror ON public.events;
DROP FUNCTION public.kan712_events_compat_mirror();

-- ROLLBACK (verbatim from pg_get_triggerdef / pg_get_functiondef, 2026-11-13; owner postgres,
-- ACL {postgres=X/postgres}):
-- CREATE OR REPLACE FUNCTION public.kan712_events_compat_mirror()
--  RETURNS trigger
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO ''
-- AS $function$
-- BEGIN
--   -- Skip only the row the guard is routing right now. The guard is a trigger, so its events UPDATE fires
--   -- this one at depth > 1; a session-level SET kan712.routing followed by a direct events write runs
--   -- at depth 1 and is mirrored normally (no spoofed divergence).
--   IF pg_trigger_depth() > 1 AND coalesce(current_setting('kan712.routing', true), '') = NEW.id::text THEN
--     RETURN NULL;
--   END IF;
--   PERFORM set_config('kan712.compat', NEW.id::text, true);
--   IF NEW.event_type = 'game' THEN
--     UPDATE public.games g SET
--       creator_profile_id = NEW.creator_profile_id, creator_user_id = NEW.creator_user_id, title = NEW.title,
--       start_at = NEW.start_at, end_at = NEW.end_at, capacity = NEW.capacity,
--       listing_visibility = NEW.listing_visibility, join_policy = NEW.join_policy,
--       is_cancelled = NEW.is_cancelled, cancelled_at = NEW.cancelled_at, cancelled_reason = NEW.cancelled_reason,
--       sport_id = NEW.sport_id, area_id = NEW.area_id, geo_location_id = NEW.geo_location_id,
--       venue_id = NEW.venue_id, min_skill = NEW.min_skill, max_skill = NEW.max_skill,
--       joining_rule = NEW.joining_rule, cost_cover = NEW.cost_cover, request_id = NEW.request_id,
--       created_at = NEW.created_at, updated_at = NEW.updated_at
--     WHERE g.id = NEW.id
--       AND ROW(g.creator_profile_id, g.creator_user_id, g.title, g.start_at, g.end_at, g.capacity,
--               g.listing_visibility, g.join_policy, g.is_cancelled, g.cancelled_at, g.cancelled_reason,
--               g.sport_id, g.area_id, g.geo_location_id, g.venue_id, g.min_skill, g.max_skill,
--               g.joining_rule, g.cost_cover, g.request_id, g.created_at, g.updated_at)
--           IS DISTINCT FROM
--           ROW(NEW.creator_profile_id, NEW.creator_user_id, NEW.title, NEW.start_at, NEW.end_at, NEW.capacity,
--               NEW.listing_visibility, NEW.join_policy, NEW.is_cancelled, NEW.cancelled_at, NEW.cancelled_reason,
--               NEW.sport_id, NEW.area_id, NEW.geo_location_id, NEW.venue_id, NEW.min_skill::integer,
--               NEW.max_skill::integer, NEW.joining_rule, NEW.cost_cover, NEW.request_id, NEW.created_at,
--               NEW.updated_at);
--   ELSE
--     UPDATE public.meetups mt SET
--       creator_profile_id = NEW.creator_profile_id, creator_user_id = NEW.creator_user_id, title = NEW.title,
--       start_at = NEW.start_at, end_at = NEW.end_at, capacity = NEW.capacity,
--       listing_visibility = NEW.listing_visibility, rsvp_policy = NEW.join_policy,
--       is_cancelled = NEW.is_cancelled,
--       sport_id = NEW.sport_id, area_id = NEW.area_id, geo_location_id = NEW.geo_location_id,
--       venue_id = NEW.venue_id, min_skill = NEW.min_skill, max_skill = NEW.max_skill,
--       joining_rule = NEW.joining_rule, cost_cover = NEW.cost_cover, request_id = NEW.request_id,
--       created_at = NEW.created_at, updated_at = NEW.updated_at
--     WHERE mt.id = NEW.id
--       AND ROW(mt.creator_profile_id, mt.creator_user_id, mt.title, mt.start_at, mt.end_at, mt.capacity,
--               mt.listing_visibility, mt.rsvp_policy, mt.is_cancelled,
--               mt.sport_id, mt.area_id, mt.geo_location_id, mt.venue_id, mt.min_skill, mt.max_skill,
--               mt.joining_rule, mt.cost_cover, mt.request_id, mt.created_at, mt.updated_at)
--           IS DISTINCT FROM
--           ROW(NEW.creator_profile_id, NEW.creator_user_id, NEW.title, NEW.start_at, NEW.end_at, NEW.capacity,
--               NEW.listing_visibility, NEW.join_policy, NEW.is_cancelled,
--               NEW.sport_id, NEW.area_id, NEW.geo_location_id, NEW.venue_id, NEW.min_skill::integer,
--               NEW.max_skill::integer, NEW.joining_rule, NEW.cost_cover, NEW.request_id, NEW.created_at,
--               NEW.updated_at);
--   END IF;
--   PERFORM set_config('kan712.compat', '', true);
--   RETURN NULL;
-- END $function$;
-- REVOKE ALL ON FUNCTION public.kan712_events_compat_mirror() FROM PUBLIC, anon, authenticated, service_role;
-- CREATE TRIGGER trg_zz_kan712_events_compat_mirror AFTER UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION kan712_events_compat_mirror();
