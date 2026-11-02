-- KAN-728 (KAN-714 piece B09) — ROLLBACK of 20261104100900_kan714_b09_booking_conflicts_hold.sql.
-- LOCAL THROWAWAY POSTGRES ONLY. One transaction. No DROP, no CASCADE, no data mutation, no grant change.
-- Restores the pre-image of public.rpc_booking_hold_for_meetup verbatim (pg_get_functiondef of the KAN-713 stage
-- catalogue) with CREATE OR REPLACE, which keeps the oid, owner and ACL. It is NOT a wrapped function
-- (kan712_wrapped_rpcs has no row for it), so no KAN-712 unwrap/wrap path applies.
-- Refuses unless the live definition is exactly the migration's post-image (md5 9d113b77...), so a second run, or a run
-- against a DB that never had the migration, raises instead of rewriting anything.
-- Verify afterwards with: psql -v expect=pre -f supabase/tests/events_p2/kan714_b09_booking_conflicts.sql
\set ON_ERROR_STOP 1
BEGIN;

DO $guard$
DECLARE v text;
BEGIN
  v := md5(pg_get_functiondef('public.rpc_booking_hold_for_meetup(uuid,uuid,timestamptz,timestamptz)'::regprocedure));
  IF v IS DISTINCT FROM '9d113b77a82df489569a765ad30445f7' THEN
    RAISE EXCEPTION 'KAN-728 rollback refused: rpc_booking_hold_for_meetup md5 % is not the B09 post-image 9d113b77a82df489569a765ad30445f7 (not applied, already rolled back, or drifted)', v;
  END IF;
END $guard$;

CREATE TEMP TABLE kan728_rb_attr ON COMMIT DROP AS
  SELECT p.oid, p.proowner, p.proacl::text AS acl, p.prosecdef, p.provolatile, p.proconfig, pg_get_function_result(p.oid) AS res
    FROM pg_proc p WHERE p.oid = 'public.rpc_booking_hold_for_meetup(uuid,uuid,timestamptz,timestamptz)'::regprocedure;

CREATE OR REPLACE FUNCTION public.rpc_booking_hold_for_meetup(p_meetup_id uuid, p_space_id uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  m record;
  vid uuid;
  bid uuid;
begin
  select * into m from public.meetups where id = p_meetup_id;
  if not found then raise exception using errcode='P0001', message='meetup_not_found'; end if;

  select s.venue_id into vid from public.venue_spaces s where s.id = p_space_id;
  if vid is null then raise exception using errcode='P0001', message='space_not_found'; end if;

  if not (m.owner_user_id = auth.uid() or public.is_venue_admin(auth.uid(), vid) or public.is_admin(auth.uid())) then
    raise exception using errcode='P0001', message='not_authorized';
  end if;

  insert into public.venue_bookings(venue_space_id, starts_at, ends_at, source_type, source_id, status, created_by)
  values (p_space_id, p_start, p_end, 'meetup', p_meetup_id, 'confirmed', auth.uid())
  returning id into bid;

  -- (optional) store human location on meetup side already; no FK change here.
  return bid;
end;
$function$;

DO $post$
DECLARE v text; n int;
BEGIN
  v := md5(pg_get_functiondef('public.rpc_booking_hold_for_meetup(uuid,uuid,timestamptz,timestamptz)'::regprocedure));
  IF v IS DISTINCT FROM '446285fd3e9d6b814fbed14af8121c27' THEN
    RAISE EXCEPTION 'KAN-728 rollback post: md5 % is not the pre-image 446285fd3e9d6b814fbed14af8121c27', v;
  END IF;
  SELECT count(*) INTO n FROM pg_proc p JOIN kan728_rb_attr a USING (oid)
   WHERE p.proowner = a.proowner AND p.proacl::text = a.acl AND p.prosecdef = a.prosecdef AND p.provolatile = a.provolatile
     AND p.proconfig IS NOT DISTINCT FROM a.proconfig AND pg_get_function_result(p.oid) = a.res;
  IF n <> 1 THEN RAISE EXCEPTION 'KAN-728 rollback post: oid/owner/ACL/SECURITY DEFINER/volatility/search_path/result changed'; END IF;
  SELECT count(*) INTO n FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_booking_hold_for_meetup';
  IF n <> 1 THEN RAISE EXCEPTION 'KAN-728 rollback post: % overloads of rpc_booking_hold_for_meetup', n; END IF;
END $post$;

COMMIT;
