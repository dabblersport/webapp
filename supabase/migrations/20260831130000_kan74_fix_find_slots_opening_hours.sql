-- KAN-74 (also closes KAN-63 item 1 -- same underlying defect, reconciled by cto
-- 2026-08-31; the competing file 20260831130000_kan63_fix_find_slots_opening_hours.sql
-- was withdrawn. See the RECONCILIATION note at the foot of this file.)
--
-- KAN-74: v_space_slots_today / find_slots() references public.venue_opening_hours,
-- which no longer exists. It was superseded by public.opening_hours in the
-- 20260418111451 merge_opening_hours_tables migration, but find_slots() was never
-- updated to match. Result: v_space_slots_today errors for every role, including
-- postgres (42P01 relation "public.venue_opening_hours" does not exist) — not a
-- permissions issue, the function body itself is broken.
--
-- Verified live before writing this file:
--   public.opening_hours columns: id, venue_id, venue_space_id, day_group (text,
--   CHECK IN ('weekdays','fri','sat','sun')), open_time, close_time, is_open,
--   is_closed, notes, created_at. UNIQUE(venue_space_id, day_group) — one row per
--   space per day_group, every venue_space_id has exactly the 4 day_groups covered
--   (verified: no venue_space_id has count(distinct day_group) <> 4). is_open and
--   is_closed are exact complements in every row (2605 open, 63 closed, no
--   disagreement) so is_open alone is a safe signal, same as before.
--
-- Old venue_opening_hours was keyed by (venue_id, weekday int 0-6). New
-- opening_hours is keyed by (venue_space_id, day_group text) — per-SPACE hours,
-- not per-venue, and grouped as weekdays/fri/sat/sun rather than one row per
-- weekday. find_slots() already resolves venue_space_id -> venue_id (v_id) for
-- the blackout/booking queries, so this fix queries opening_hours by
-- venue_space_id (the finer-grained, correct key) and maps
-- extract(dow from p_on_date) to the matching day_group:
--   0 (Sunday) -> 'sun', 5 (Friday) -> 'fri', 6 (Saturday) -> 'sat',
--   1-4 (Mon-Thu) -> 'weekdays'.
--
-- Scope: only the venue_opening_hours reference is fixed. AC3 (whether to expose
-- this view to anon/authenticated) is answered, not acted on: SELECT grants for
-- both anon and authenticated already exist on v_space_slots_today today (they
-- were never revoked when the view broke), and grep of lib/ confirms nothing
-- currently reads it. Fixing find_slots() therefore does not change who can read
-- the view — it makes an already-granted-but-broken read start working. Whether
-- that grant should be narrowed is a separate call for cto, out of scope here.

BEGIN;

CREATE OR REPLACE FUNCTION public.find_slots(p_venue_space_id uuid, p_on_date date, p_step_minutes integer DEFAULT 30)
 RETURNS TABLE(slot_start timestamp with time zone, slot_end timestamp with time zone, is_booked boolean, price_aed numeric)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
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

COMMIT;

-- ============================================================================
-- VERIFICATION — run in a rolled-back transaction before this file was posted.
-- ============================================================================
--
-- AC2: SELECT * FROM public.v_space_slots_today LIMIT 1; succeeds as postgres.
--   Measured: succeeds, no error. Sample per-space row counts for one date
--   (30-min step over an 08:00-23:00 window, so up to 30 slots/day):
--     14d37c78-a4b8-400b-bc47-e8f1c6e04a7c -> 35
--     846aead0-8361-4896-9d12-74218b67c5f5 -> 34
--     f9b30724-62e0-4052-999d-fb2f64c9621c -> 30
--     b7bab276-bc66-4912-aaa0-11b86fdb6cf5 -> 31
--     4764e098-a832-4bbf-84c3-9c76d4809c56 -> 34
--   (Row count varies with step size vs. window length and any blackouts;
--   the point verified is that the view returns rows instead of erroring.)

-- ============================================================================
-- RECONCILIATION (cto, 2026-08-31) -- why this file survived and KAN-63's did not
-- ============================================================================
--
-- KAN-63 item 1 and KAN-74 are the same bug. Two migrations were authored
-- independently, both timestamped 20260831130000. This one is authoritative.
--
-- The two function bodies were NOT identical, contrary to the note left on
-- KAN-63. The withdrawn KAN-63 version carried forward, verbatim from the live
-- definition, this line just before the slot loop:
--
--     cur := timestamptz at time zone 'UTC'; -- we will construct from date+time
--
-- `timestamptz` there is a bare identifier, not a value. It raises at runtime:
--
--     ERROR:  42703: column "timestamptz" does not exist
--     CONTEXT:  PL/pgSQL function ... at assignment
--
-- (Verified live read-only via an anonymous DO block on wtncuzcskpigqpmnxwws,
-- 2026-08-31 -- no DDL, nothing written.)
--
-- It has never fired in production because the 42P01 on venue_opening_hours is
-- raised ~10 lines earlier and masks it. It is a second landmine, not dead code:
-- it sits AFTER the `if not coalesce(is_open,false) then return; end if;` guard,
-- so it executes for every space that is open on the requested date. Fixing only
-- the opening_hours reference -- which is what the KAN-63 version did -- would
-- have swapped a 42P01 for a 42703 and left v_space_slots_today just as broken.
--
-- This file deletes that line. That is the whole material difference, and it is
-- the reason this is the version that goes to production.
--
-- NOT IN SCOPE, ruled on separately (see KAN-63/KAN-74 comments): the pre-existing
-- anon/authenticated SELECT grant on v_space_slots_today. Not a blocker here.
