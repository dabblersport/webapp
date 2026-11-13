-- KAN-806 (Epic KAN-708; KAN718_RUNBOOK.md F5): kan712_update_event_shared(uuid, jsonb), the service_role ops/admin
-- write path, refuses 55000 kan712_not_cut_over after KAN-719 Z01 (20261105100000_kan719_z01_remove_replaced_columns.sql).
-- Cause: its first statement requires an ENABLED trg_zz_kan712_events_compat_mirror, and Z01 seq 334 drops that
-- trigger (it must: Z01 also drops every games/meetups column the mirror writes, seq 601-623 and 701-724).
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan806_write_path_after_z01.sql.
--
-- No DROP, no table/column/grant/policy/trigger change, no row written, no dual write, no other function touched.
-- One body is replaced in place (CREATE OR REPLACE, same signature, so oid, owner and ACL are kept; asserted in
-- section 3). The ONLY change is the cut-over guard (the first IF). Everything else is byte-identical to the
-- pre-image (asserted in section 3 by reversing the guard and comparing md5(prosrc) to the section 0 pin).
--
--   state                                              mirror trigger      mirrored legacy cols   was     now
--   pre-Z01, cut over (KAN-712 cutover applied)        present, 'O'        present                open    open
--   pre-Z01, mirror disabled                           present, not 'O'    present                55000   55000
--   stage 1 / rolled back (rollback_kan712.sql)        absent              present                55000   55000
--   post-Z01 (phase 4)                                 absent              ALL absent             55000   open
--   partial / inconsistent (mirror gone, any col left) absent              some present           55000   55000
--
-- Contract meaning is unchanged. KAN712_CONTRACT.md:37 gives the guard's purpose: "so a rolled-back database cannot
-- drift" -- an events-only write must never leave a legacy copy behind. The new open state is exactly the state in
-- which no legacy copy exists: every one of the 42 columns the mirror writes (22 on games, 20 on meetups, listed
-- verbatim from the mirror body, 20261103100000:230-285) is gone, so there is nothing to drift from. A disabled
-- mirror still refuses, because a present trigger means the legacy columns are expected to be written. The column
-- lists are the mirror's write targets, not Z01's drop list, so a Z01 that held back a mirrored column would keep
-- the path closed (fail closed). Z01's held columns (704 meetups.description, 722 location_name, 723 is_indoor)
-- are not mirror targets.
--
-- Z01 ORDER: this file is valid BEFORE Z01 (the path stays on the mirror, behaviour identical) and AFTER Z01.
--
-- T-058: authored from pg_get_functiondef on the local chain (baseline + KAN-712 write contract + cutover); no
-- later migration in this tree redefines the function. Section 0 pins md5(prosrc), SECURITY DEFINER, volatility,
-- proconfig and owner. Any drift fails closed: re-author from pg_get_functiondef on the live catalogue.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_bad text;
begin
  if to_regclass('public.events') is null or to_regclass('public.games') is null or to_regclass('public.meetups') is null then
    raise exception 'KAN-806 pre: public.events, public.games or public.meetups missing';
  end if;
  if not exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'event_id'
                  and attnum > 0 and not attisdropped)
     or not exists (select 1 from pg_attribute where attrelid = 'public.meetups'::regclass and attname = 'event_id'
                  and attnum > 0 and not attisdropped) then
    raise exception 'KAN-806 pre: games.event_id or meetups.event_id missing (KAN-711 not applied)';
  end if;

  -- Pre-image pin: md5(prosrc) | SECURITY DEFINER | volatility | proconfig | owner
  select coalesce(md5(p.prosrc) || '|' || p.prosecdef::text || '|' || p.provolatile::text || '|'
                  || p.proconfig::text || '|' || p.proowner::regrole::text, 'absent')
    into v_bad
    from (select 1) d
    left join pg_proc p on p.oid = to_regprocedure('public.kan712_update_event_shared(uuid,jsonb)')
   where p.oid is null
      or md5(p.prosrc) <> 'e25772a438b80fa09833eaf87fb82860'
      or not p.prosecdef
      or p.provolatile <> 'v'
      or p.proconfig is distinct from array['search_path=""']
      or p.proowner <> 'postgres'::regrole;
  if v_bad is not null then
    raise exception 'KAN-806 pre: pre-image absent or drifted (re-author from pg_get_functiondef on the live catalogue): %', v_bad;
  end if;
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Capture what must not change.
-- ---------------------------------------------------------------------------------------------------------
create temp table kan806_pre on commit drop as
select p.oid, p.proargtypes::text as argtypes, p.prorettype, p.prosecdef, p.provolatile, p.proconfig, p.proacl,
       p.proowner, p.proretset, p.proisstrict, p.proparallel, p.pronargdefaults,
       pg_get_function_arguments(p.oid) as args, pg_get_function_result(p.oid) as res
  from pg_proc p
 where p.oid = 'public.kan712_update_event_shared(uuid,jsonb)'::regprocedure;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Replacement. Header identical to the pre-image; body changed only at the cut-over guard.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.kan712_update_event_shared(p_event_id uuid, p_patch jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_allowed constant text[] := ARRAY['title', 'start_at', 'end_at', 'capacity', 'listing_visibility',
    'join_policy', 'is_cancelled', 'cancelled_at', 'cancelled_reason', 'sport_id', 'area_id',
    'geo_location_id', 'venue_id', 'min_skill', 'max_skill', 'joining_rule', 'cost_cover'];
  v_bad text[];
  e public.events;
  n public.events;
BEGIN
  -- Fail closed unless the cutover is live: without the compat mirror an events-only write would leave
  -- the legacy row behind (stage 1 before cutover, or after rollback_kan712.sql keeps stage 1).
  -- KAN-806: after phase 4 (Z01) the mirror is gone AND so is every legacy column it wrote, so no legacy row is left
  -- behind; the path is open then. A disabled mirror, or a missing mirror with any mirrored column left, still refuses.
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
                  WHERE tgrelid = 'public.events'::regclass AND tgname = 'trg_zz_kan712_events_compat_mirror' AND tgenabled = 'O')
     AND (EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
                   WHERE tgrelid = 'public.events'::regclass AND tgname = 'trg_zz_kan712_events_compat_mirror')
          OR EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a
                      WHERE a.attnum > 0 AND NOT a.attisdropped
                        AND ((a.attrelid = 'public.games'::regclass AND a.attname::text = ANY (ARRAY['creator_profile_id',
                               'creator_user_id', 'title', 'start_at', 'end_at', 'capacity', 'listing_visibility', 'join_policy',
                               'is_cancelled', 'cancelled_at', 'cancelled_reason', 'sport_id', 'area_id', 'geo_location_id',
                               'venue_id', 'min_skill', 'max_skill', 'joining_rule', 'cost_cover', 'request_id', 'created_at',
                               'updated_at']))
                          OR (a.attrelid = 'public.meetups'::regclass AND a.attname::text = ANY (ARRAY['creator_profile_id',
                               'creator_user_id', 'title', 'start_at', 'end_at', 'capacity', 'listing_visibility', 'rsvp_policy',
                               'is_cancelled', 'sport_id', 'area_id', 'geo_location_id', 'venue_id', 'min_skill', 'max_skill',
                               'joining_rule', 'cost_cover', 'request_id', 'created_at', 'updated_at']))))) THEN
    RAISE EXCEPTION USING ERRCODE = '55000', MESSAGE = 'kan712_not_cut_over',
      DETAIL = 'public.events has no enabled trg_zz_kan712_events_compat_mirror; the ops path is closed.';
  END IF;
  IF p_event_id IS NULL OR p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'kan712_patch_invalid';
  END IF;
  SELECT array_agg(k ORDER BY k) INTO v_bad FROM jsonb_object_keys(p_patch) k WHERE k <> ALL (v_allowed);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'kan712_patch_key_not_allowed', DETAIL = array_to_string(v_bad, ',');
  END IF;
  SELECT * INTO e FROM public.events WHERE id = p_event_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'kan712_event_not_found';
  END IF;
  n := jsonb_populate_record(e, p_patch);
  UPDATE public.events SET
    title = n.title, start_at = n.start_at, end_at = n.end_at, capacity = n.capacity,
    listing_visibility = n.listing_visibility, join_policy = n.join_policy, is_cancelled = n.is_cancelled,
    cancelled_at = n.cancelled_at, cancelled_reason = n.cancelled_reason, sport_id = n.sport_id,
    area_id = n.area_id, geo_location_id = n.geo_location_id, venue_id = n.venue_id,
    min_skill = n.min_skill, max_skill = n.max_skill, joining_rule = n.joining_rule, cost_cover = n.cost_cover
  WHERE id = p_event_id
  RETURNING * INTO e;
  RETURN to_jsonb(e) - 'search_tsv';
END $function$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-checks: attributes, owner and ACL unchanged; body byte-identical outside the guard.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  v_bad text;
  v_src text;
  v_old_guard constant text := $g$  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
                  WHERE tgrelid = 'public.events'::regclass AND tgname = 'trg_zz_kan712_events_compat_mirror' AND tgenabled = 'O') THEN
$g$;
  v_start int;
  v_end int;
begin
  if (select count(*) from kan806_pre) <> 1 then
    raise exception 'KAN-806 post: captured % pre-image rows, expected 1', (select count(*) from kan806_pre);
  end if;
  select 'kan712_update_event_shared' into v_bad
    from kan806_pre b
    left join pg_proc p on p.oid = b.oid
   where p.oid is null
      or p.proargtypes::text <> b.argtypes
      or p.prorettype <> b.prorettype
      or p.prosecdef <> b.prosecdef
      or p.provolatile <> b.provolatile
      or p.proconfig is distinct from b.proconfig
      or p.proacl is distinct from b.proacl
      or p.proowner <> b.proowner
      or p.proretset <> b.proretset
      or p.proisstrict <> b.proisstrict
      or p.proparallel <> b.proparallel
      or p.pronargdefaults <> b.pronargdefaults
      or pg_get_function_arguments(p.oid) <> b.args
      or pg_get_function_result(p.oid) <> b.res;
  if v_bad is not null then
    raise exception 'KAN-806 post: signature/attribute/ACL/owner changed for: %', v_bad;
  end if;

  -- Byte identity outside the guard: cut the new guard (from the KAN-806 comment line to the end of its THEN line)
  -- and splice the pre-image guard back in; the result must hash to the section 0 pin.
  select prosrc into v_src from pg_proc where oid = 'public.kan712_update_event_shared(uuid,jsonb)'::regprocedure;
  v_start := strpos(v_src, '  -- KAN-806:');
  v_end := strpos(v_src, '))))) THEN' || chr(10));
  if v_start = 0 or v_end = 0 or v_end < v_start then
    raise exception 'KAN-806 post: new guard not found in the body';
  end if;
  if md5(left(v_src, v_start - 1) || v_old_guard || substr(v_src, v_end + length('))))) THEN' || chr(10))))
     <> 'e25772a438b80fa09833eaf87fb82860' then
    raise exception 'KAN-806 post: body differs from the pre-image outside the cut-over guard';
  end if;
end
$post$;

commit;
