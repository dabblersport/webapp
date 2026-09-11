-- KAN-104 AC2 (T-044, cto ruling 2026-09-01): option (a).
--
-- v_space_slots_today's is_booked reads false for every anon and non-privileged
-- authenticated caller, deterministically, because find_slots() is SECURITY
-- INVOKER and its internal `SELECT EXISTS(...) FROM venue_bookings` is filtered
-- by venue_bookings_select's RLS predicate (can_view_venue_bookings), which
-- denies all rows to those callers regardless of whether a booking exists.
-- Confirmed by static policy analysis, posted as a KAN-104 comment 2026-09-01
-- (venue_bookings has 0 live rows and KAN-74 was not yet applied at analysis
-- time, so an empirical row-count reproduction wasn't available).
--
-- Fix: make find_slots() SECURITY DEFINER so booking OCCUPANCY (a boolean) is
-- computed with elevated privilege, without exposing booking ROWS to the
-- caller -- only is_booked crosses the privilege boundary, same shape as the
-- table's own can_view_venue_bookings(), which is SECURITY DEFINER returning
-- only a boolean and is verified live today as
-- prosecdef=true, proconfig={search_path=public,row_security=off}.
--
-- This migration MUST be applied after 20260831130000_kan74_fix_find_slots_
-- opening_hours.sql and restates that file's corrected body in full (the
-- opening_hours/day_group fix), not just adds SECURITY DEFINER on top of the
-- old broken body. CREATE OR REPLACE FUNCTION without SECURITY DEFINER
-- silently resets prosecdef to false -- the function analogue of the
-- CREATE OR REPLACE VIEW / security_invoker trap (CONVENTIONS §6c, now
-- extended to cover functions per cto). If KAN-74 is re-run after this file,
-- it will silently drop this elevation -- KAN-74's file must not be reapplied
-- once this one has landed.
--
-- Conditions attached to this ruling (T-044), carried forward:
--   1. The DEFINER boundary is justified only by the return signature
--      (slot_start, slot_end, is_booked, price_aed). Any new return column or
--      new relation added to this function body later needs a fresh cto ruling.
--   2. `is_active = true` stays on the venue_spaces lookup -- it is the only
--      thing bounding which spaces an anon caller can enumerate.
--   3. This file restates the whole body and sorts after KAN-74's.
--   4. Verification asserts prosecdef/proconfig on the function and
--      security_invoker on the view -- a row-count check alone proves nothing.
--
-- Rejected -- (b) a narrow anon/authenticated SELECT policy on venue_bookings.
-- Not implementable as scoped: an RLS policy is a row filter, it cannot
-- restrict which columns are exposed. "Only the columns availability needs"
-- would require a second mechanism (a column GRANT) on top of it -- more
-- moving parts for the same outcome as (a).
--
-- Rejected -- (c) revoke the anon/authenticated grant on the view. find_slots
-- holds EXECUTE from both PUBLIC (=X/postgres) and explicitly anon=X/postgres
-- -- revoking the view's grant leaves the RPC path (`rpc.find_slots`) open and
-- still returning a wrong is_booked to anon. That hides the symptom on one
-- entry point while leaving the underlying defect reachable through another.
--
-- Full reasoning: docs/DECISIONS.md T-044; Jira KAN-104 comment 10377.

BEGIN;

CREATE OR REPLACE FUNCTION public.find_slots(p_venue_space_id uuid, p_on_date date, p_step_minutes integer DEFAULT 30)
 RETURNS TABLE(slot_start timestamp with time zone, slot_end timestamp with time zone, is_booked boolean, price_aed numeric)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
declare
  v_id uuid;
  vdow int;
  v_day_group text;
  open_t time;
  close_t time;
  is_open boolean;
  cur timestamptz;
  nxt timestamptz;
  blk int;
  booked boolean;
  p numeric;
begin
  -- Get venue + hours
  select s.venue_id into v_id from public.venue_spaces s where s.id=p_venue_space_id and s.is_active=true;
  if not found then
    return;
  end if;

  vdow := extract(dow from p_on_date); -- 0..6, 0=Sunday
  v_day_group := case vdow
    when 0 then 'sun'
    when 5 then 'fri'
    when 6 then 'sat'
    else 'weekdays'
  end;

  select oh.open_time, oh.close_time, oh.is_open
    into open_t, close_t, is_open
  from public.opening_hours oh
  where oh.venue_space_id = p_venue_space_id and oh.day_group = v_day_group;

  if not coalesce(is_open, false) then
    return; -- closed that day
  end if;

  cur := (p_on_date::timestamptz + open_t);
  while cur < (p_on_date::timestamptz + close_t) loop
    nxt := cur + make_interval(mins => p_step_minutes);

    -- Skip past-end partial
    if nxt > (p_on_date::timestamptz + close_t) then
      exit;
    end if;

    -- Blackouts?
    select count(*) into blk
    from public.venue_blackouts b
    where b.venue_id = v_id
      and (b.venue_space_id is null or b.venue_space_id = p_venue_space_id)
      and tstzrange(b.starts_at, b.ends_at, '[)') && tstzrange(cur, nxt, '[)');

    if blk = 0 then
      -- Booked?
      select exists (
        select 1 from public.venue_bookings bk
        where bk.venue_space_id = p_venue_space_id
          and bk.status in ('tentative','confirmed')
          and tstzrange(bk.starts_at, bk.ends_at, '[)') && tstzrange(cur, nxt, '[)')
      ) into booked;

      -- Price hint: pick first rule matching DOW + time
      select pr.price_aed into p
      from public.venue_price_rules pr
      where pr.venue_space_id = p_venue_space_id
        and (pr.dow is null or vdow = any(pr.dow))
        and pr.start_time <= (cur::time)
        and pr.end_time   >  (cur::time)
      order by pr.start_time desc
      limit 1;

      slot_start := cur;
      slot_end   := nxt;
      is_booked  := booked;
      price_aed  := p;
      return next;
    end if;

    cur := nxt;
  end loop;
end;
$function$;

ALTER VIEW public.v_space_slots_today SET (security_invoker = true);

COMMIT;

-- ============================================================================
-- VERIFICATION -- to be run by whoever applies this (cto/PO), not run here.
-- ============================================================================
-- 1. select prosecdef, proconfig from pg_proc where proname = 'find_slots';
--      -- prosecdef must be true; proconfig must contain both
--      -- search_path=public and row_security=off.
-- 2. select (reloptions is not null and 'security_invoker=true' = any(reloptions))
--    from pg_class where relname = 'v_space_slots_today';
--      -- must be true.
-- 3. AC1 regression check (per T-044, open until this is run): seed one
--    `tentative` venue_bookings row covering a known slot, then:
--      SET LOCAL ROLE anon;
--      SELECT is_booked FROM public.v_space_slots_today
--        WHERE venue_space_id = <space> AND slot_start = <slot>;
--      -- must read true. A row-count check alone (e.g. "the view returns
--      -- rows") proves nothing about this bug and must not be substituted.
-- 4. SET LOCAL ROLE anon; SELECT * FROM public.venue_bookings LIMIT 1;
--      -- must still fail permission denied -- this migration must not open
--      -- the underlying booking rows, only the computed is_booked boolean.
