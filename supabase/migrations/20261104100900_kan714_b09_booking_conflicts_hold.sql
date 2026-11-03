-- KAN-728 (KAN-714 piece B09, Epic KAN-708) — booking reads: rpc_booking_hold_for_meetup owner_user_id blocker fixed,
-- creator read from public.events; _slot_conflicts_game reads start/end/cancelled from public.events where the caller
-- may read events (orchestrator decision, option (a), the KAN-713 has_table_privilege branch). Nothing else changed.
--
-- AUTHORED, NOT APPLIED. Local proof only: supabase/tests/events_p2/kan714_b09_booking_conflicts.sql.
-- Rollback: supabase/tests/events_p2/rollback_kan714_b09.sql (restores the pre-image below, verbatim).
--
-- PRE-IMAGES: authored from pg_get_functiondef on the KAN-713 stage catalogue (T-058), not from a migration file.
-- Latest definitions: rpc_booking_hold_for_meetup baseline 20260829080500_baseline_schema.sql:11180;
-- _slot_conflicts_game baseline 20260829080500_baseline_schema.sql; no later migration redefines either.
--
-- INVENTORY — every booking reader of games/meetups (pg_proc + view + policy scan, KAN-714 manifest "booking" rows):
--   rpc_booking_hold_for_meetup(uuid,uuid,timestamptz,timestamptz)
--       CHANGED. Pre-image reads m.owner_user_id from `select * from meetups`; meetups has no such column, so every
--       call that passes the not-found checks raises 42703 (test H1/H2 pre). Now the creator comes from the events
--       parent: meetups mt JOIN events e ON e.id = mt.event_id AND e.event_type = 'meetup'. Only that read changes;
--       the authorisation expression, the two not-found checks, the insert, and the return are the pre-image verbatim.
--       Not KAN-712-wrapped (asserted below), so CREATE OR REPLACE is the legal path.
--   _slot_conflicts_game(uuid,timestamptz,timestamptz)
--       CHANGED (orchestrator decision, option (a)). The one time-conflict reader of games. SECURITY INVOKER, EXECUTE
--       granted to PUBLIC/anon/authenticated; public.events is FORCE RLS, zero policies, no API grant. So, as in
--       KAN-713 (_can_view_game_for_join): IF has_table_privilege('public.events','SELECT') — owner/superuser,
--       service_role, and any SECURITY DEFINER caller owned by such a role — start_at, end_at, is_cancelled come from
--       games g JOIN events e ON e.id = g.event_id AND e.event_type = 'game'. ELSE (anon/authenticated invoker) the
--       pre-image predicate on the games mirror, unchanged. The filter g.venue_space_id stays on games (games-only
--       column, not a shared fact). Signature, result, owner, ACL, SECURITY INVOKER, search_path ('public','pg_temp')
--       and STABLE are captured before and asserted equal after.
--       ONE ATTRIBUTE CHANGES: LANGUAGE sql -> plpgsql. Postgres checks permission on every relation in a statement's
--       range table at executor start, so a single SQL statement that merely mentions events raises 42501 for
--       authenticated even on the branch that would not read it (test C3b proves this on a sql-language copy). In
--       plpgsql each branch is its own statement, planned and permission-checked only when reached.
--       A role that holds SELECT on events but is subject to its RLS would see zero events rows (no conflicts); the
--       guard and post-conditions assert every non-pg_ role with SELECT on events is superuser or BYPASSRLS.
--       No function body calls it today (pinned): it is reached directly by API callers.
--   rpc_booking_hold_for_game(...) / rpc_booking_hold_for_game_kan712_inner(...)
--       UNCHANGED — ACCEPTED EXCEPTION under the KAN-712 wrap (orchestrator decision). Reads games.creator_user_id as an
--       auth gate (not a conflict read) and writes games.venue_space_id. Changing it requires
--       kan712_unwrap_rpc/kan712_wrap_rpc, which DROP the wrapper; this piece is no-DROP. Pinned and asserted
--       untouched.
--   rpc_booking_cancel(uuid)
--       UNCHANGED. Reads creator_user_id of games/meetups as an auth gate, not a conflict read. Out of this piece.
--   _game_belongs_to_venue(uuid,uuid)
--       UNCHANGED. Reads only games.id and games.venue_space_id (no events column), so there is nothing to repoint.
--   Meetups have no time-conflict reader: meetups has no venue_space_id; meetup holds are conflict-checked only by the
--   venue_bookings exclusion constraint (baseline), which reads venue_bookings, not meetups.
--
-- JOIN: by mt.id = p_meetup_id (PK); events.id is the PK, so 1:0..1. The stage guard proves exactly one meetup parent
-- for every meetups row. A row whose parent is missing or of type 'game' becomes meetup_not_found (none exists today).
-- STRUCTURE: the local m stays `record`; it now carries (id, creator_user_id). auth.uid() NULL semantics unchanged.
--
-- ACCESS: rpc_booking_hold_for_meetup stays SECURITY DEFINER, owner postgres (superuser: reads events past FORCE RLS),
-- search_path public. _slot_conflicts_game stays SECURITY INVOKER. CREATE OR REPLACE FUNCTION keeps owner and ACL;
-- captured before and asserted equal after for both. public.events stays FORCE RLS, zero policies, no API grants.
-- No grant is added or changed.
--
-- No DROP, no CASCADE, no data mutation, no grant change. Single transaction.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  v_missing text[] := '{}';
  v_has boolean;
  v_list text;
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-728: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-728: public.events missing (KAN-710 not applied)';
  END IF;

  -- KAN-712 stage B (cutover) and KAN-713 markers.
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.games',   'trg_zz_kan712_games_guard'),
      ('public.games',   'trg_zz_kan712_games_after_delete'),
      ('public.meetups', 'trg_zz_kan712_meetups_guard'),
      ('public.meetups', 'trg_zz_kan712_meetups_after_delete'),
      ('public.events',  'trg_kan713_events_location'),
      ('public.games',   'trg_kan713_games_a_location'),
      ('public.games',   'trg_kan713_games_b_joining'),
      ('public.games',   'trg_kan713_games_c_venue_geo'),
      ('public.meetups', 'trg_kan713_meetups_a_location'),
      ('public.meetups', 'trg_kan713_meetups_b_joining')) AS t(rel, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.rel::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      v_missing := v_missing || (r.rel || '.' || r.tg);
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    v_missing := v_missing || 'public.kan712_wrapped_rpcs'::text;
  ELSE
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs)' INTO v_has;
    IF NOT v_has THEN
      v_missing := v_missing || 'public.kan712_wrapped_rpcs (empty: stage B not run)'::text;
    END IF;
  END IF;
  IF to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    v_missing := v_missing || 'public.kan713_meetup_visible(uuid)'::text;
  END IF;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'KAN-728: prerequisite stage missing: %', array_to_string(v_missing, ', ');
  END IF;

  -- rpc_booking_hold_for_meetup is not KAN-712-wrapped: a bare CREATE OR REPLACE is legal only while that holds.
  EXECUTE $q$SELECT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_booking_hold_for_meetup')$q$ INTO v_has;
  IF v_has OR to_regproc('public.rpc_booking_hold_for_meetup_kan712_inner') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-728: rpc_booking_hold_for_meetup is KAN-712-wrapped — use the unwrap/wrap path (KAN712_CONTRACT.md), stop';
  END IF;
  -- The game hold IS wrapped and is deliberately not touched here; prove the wrapper is still the one KAN-712 made.
  EXECUTE $q$SELECT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = 'rpc_booking_hold_for_game'
                              AND inner_name = 'rpc_booking_hold_for_game_kan712_inner')$q$ INTO v_has;
  IF NOT v_has THEN
    RAISE EXCEPTION 'KAN-728: rpc_booking_hold_for_game wrap record missing — KAN-712 state unexpected, re-assess';
  END IF;

  -- events still closed to the API.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR NOT (SELECT relforcerowsecurity AND relrowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-728: public.events is no longer closed (policy or API grant present) — re-assess';
  END IF;

  -- Every meetups row has exactly one parent of event_type 'meetup' (INNER JOIN loses and doubles nothing).
  IF EXISTS (SELECT 1 FROM public.meetups m LEFT JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
              WHERE e.id IS NULL) THEN
    RAISE EXCEPTION 'KAN-728: a meetups row has no events parent of event_type meetup';
  END IF;
  -- ... and the creator agrees (the compat mirror holds; a disagreement would change who may hold).
  IF EXISTS (SELECT 1 FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
              WHERE e.creator_user_id IS DISTINCT FROM m.creator_user_id) THEN
    RAISE EXCEPTION 'KAN-728: events.creator_user_id disagrees with meetups.creator_user_id — reconcile first';
  END IF;

  -- _slot_conflicts_game: every games row has exactly one parent of event_type 'game' (the events branch loses
  -- nothing), and the three facts it reads agree today (applying changes no answer on day one).
  IF EXISTS (SELECT 1 FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
              WHERE e.id IS NULL) THEN
    RAISE EXCEPTION 'KAN-728: a games row has no events parent of event_type game';
  END IF;
  IF EXISTS (SELECT 1 FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
              WHERE e.start_at IS DISTINCT FROM g.start_at OR e.end_at IS DISTINCT FROM g.end_at
                 OR e.is_cancelled IS DISTINCT FROM g.is_cancelled) THEN
    RAISE EXCEPTION 'KAN-728: events start_at/end_at/is_cancelled disagree with games — reconcile first';
  END IF;
  -- A role that may SELECT events but is subject to its RLS (FORCE, zero policies) would see no events rows and the
  -- events branch would report no conflicts. Every such role must bypass RLS.
  SELECT string_agg(rolname, ',' ORDER BY rolname) INTO v_list FROM pg_roles
   WHERE rolname !~ '^pg_' AND has_table_privilege(oid, 'public.events', 'SELECT') AND NOT (rolsuper OR rolbypassrls);
  IF v_list IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-728: roles % may SELECT public.events but not bypass its RLS — _slot_conflicts_game would see no rows', v_list;
  END IF;
  IF (SELECT prosecdef FROM pg_proc WHERE oid = 'public._slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)'::regprocedure) THEN
    RAISE EXCEPTION 'KAN-728: _slot_conflicts_game is SECURITY DEFINER — re-assess';
  END IF;

  -- The function owner must read events past FORCE RLS, and the function stay SECURITY DEFINER.
  FOR r IN SELECT p.oid::regprocedure::text AS fn, p.proowner AS own, p.prosecdef FROM pg_proc p
            WHERE p.oid = 'public.rpc_booking_hold_for_meetup(uuid,uuid,timestamp with time zone,timestamp with time zone)'::regprocedure LOOP
    IF NOT r.prosecdef THEN
      RAISE EXCEPTION 'KAN-728: % is no longer SECURITY DEFINER; reading events would break API callers — stop', r.fn;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE oid = r.own AND (rolsuper OR rolbypassrls)) THEN
      RAISE EXCEPTION 'KAN-728: owner of % cannot bypass RLS on public.events', r.fn;
    END IF;
  END LOOP;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Drift pins: md5 of pg_get_functiondef of the changed functions (already-applied state fails here too) and of
--    every booking reader left untouched; plus the exact list of public functions whose body calls a changed one.
-- ---------------------------------------------------------------------------------------------------------
DO $pins$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_booking_hold_for_meetup(uuid,uuid,timestamp with time zone,timestamp with time zone)',           '446285fd3e9d6b814fbed14af8121c27'),
      ('public._slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)',                       '42729f5c67c2b2fa453addf51fec26c6'),
      ('public.rpc_booking_hold_for_game(uuid,uuid,timestamp with time zone,timestamp with time zone)',             '5857515b031fcb57926549d754af89a5'),
      ('public.rpc_booking_hold_for_game_kan712_inner(uuid,uuid,timestamp with time zone,timestamp with time zone)', 'ddb9fe12e37d1a651c0ee3104988ec6b'),
      ('public.rpc_booking_cancel(uuid)',                                                                            '97e9c289b9d768ff7212529876ecff08'),
      ('public._game_belongs_to_venue(uuid,uuid)',                                                                   '6e5901ff6904c44012897b99d5b0c830')) AS t(fn, md)
  LOOP
    IF to_regprocedure(r.fn) IS NULL THEN
      RAISE EXCEPTION 'KAN-728 pin: % missing', r.fn;
    END IF;
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-728 pin: % definition drifted (md5 % expected %) — already applied, or the pre-image moved',
        r.fn, v, r.md;
    END IF;
  END LOOP;
  SELECT string_agg(p.oid::regprocedure::text, ',' ORDER BY p.oid::regprocedure::text) INTO v
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.prosrc ~ 'rpc_booking_hold_for_meetup'
     AND p.proname <> 'rpc_booking_hold_for_meetup';
  IF v IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-728 pin: callers of rpc_booking_hold_for_meetup drifted (got %) — re-assess', v;
  END IF;
  SELECT string_agg(p.oid::regprocedure::text, ',' ORDER BY p.oid::regprocedure::text) INTO v
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.prosrc ~ '_slot_conflicts_game'
     AND p.proname <> '_slot_conflicts_game';
  IF v IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-728 pin: callers of _slot_conflicts_game drifted (got %) — re-assess', v;
  END IF;
END
$pins$;

-- Attribute capture for the post-conditions (ON COMMIT DROP: nothing persists).
CREATE TEMP TABLE kan728_pre ON COMMIT DROP AS
  SELECT p.oid, p.proowner, p.proacl::text AS acl, p.prosecdef, p.provolatile, p.proconfig, p.prolang,
         pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS res
    FROM pg_proc p
   WHERE p.oid IN ('public.rpc_booking_hold_for_meetup(uuid,uuid,timestamp with time zone,timestamp with time zone)'::regprocedure,
                   'public._slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)'::regprocedure);
CREATE TEMP TABLE kan728_pre_events ON COMMIT DROP AS
  SELECT relacl::text AS acl, relrowsecurity, relforcerowsecurity FROM pg_class WHERE oid = 'public.events'::regclass;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Function
-- ---------------------------------------------------------------------------------------------------------
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
  -- KAN-728: the creator comes from the events parent (pre-image read meetups.owner_user_id, which does not exist).
  select mt.id, e.creator_user_id into m
    from public.meetups mt join public.events e on e.id = mt.event_id and e.event_type = 'meetup'
   where mt.id = p_meetup_id;
  if not found then raise exception using errcode='P0001', message='meetup_not_found'; end if;

  select s.venue_id into vid from public.venue_spaces s where s.id = p_space_id;
  if vid is null then raise exception using errcode='P0001', message='space_not_found'; end if;

  if not (m.creator_user_id = auth.uid() or public.is_venue_admin(auth.uid(), vid) or public.is_admin(auth.uid())) then
    raise exception using errcode='P0001', message='not_authorized';
  end if;

  insert into public.venue_bookings(venue_space_id, starts_at, ends_at, source_type, source_id, status, created_by)
  values (p_space_id, p_start, p_end, 'meetup', p_meetup_id, 'confirmed', auth.uid())
  returning id into bid;

  -- (optional) store human location on meetup side already; no FK change here.
  return bid;
end;
$function$;

-- _slot_conflicts_game: LANGUAGE sql -> plpgsql (the one changed attribute, see header); everything else as before.
CREATE OR REPLACE FUNCTION public._slot_conflicts_game(p_space uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- KAN-728: a caller that may read events (owner/superuser, service_role, a SECURITY DEFINER caller) takes start,
  -- end and cancelled from the events parent. venue_space_id is games-only and stays on games.
  if has_table_privilege('public.events', 'SELECT') then
    return exists(
      select 1 from public.games g
      join public.events e on e.id = g.event_id and e.event_type = 'game'
      where g.venue_space_id = p_space
        and e.is_cancelled = false
        and tstzrange(e.start_at, e.end_at, '[)') && tstzrange(p_start, p_end, '[)')
    );
  end if;
  -- Caller cannot read events (anon / authenticated invoker): the pre-image predicate on the games mirror, unchanged.
  return exists(
    select 1 from public.games g
    where g.venue_space_id = p_space
      and g.is_cancelled = false
      and tstzrange(g.start_at, g.end_at, '[)') && tstzrange(p_start, p_end, '[)')
  );
end;
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record; v text;
BEGIN
  -- Exact new definition; every untouched booking reader byte-identical.
  FOR r IN SELECT * FROM (VALUES
      ('public.rpc_booking_hold_for_meetup(uuid,uuid,timestamp with time zone,timestamp with time zone)',           '9d113b77a82df489569a765ad30445f7'),
      ('public._slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)',                       '6b55caf2dd120676bef075536014370b'),
      ('public.rpc_booking_hold_for_game(uuid,uuid,timestamp with time zone,timestamp with time zone)',             '5857515b031fcb57926549d754af89a5'),
      ('public.rpc_booking_hold_for_game_kan712_inner(uuid,uuid,timestamp with time zone,timestamp with time zone)', 'ddb9fe12e37d1a651c0ee3104988ec6b'),
      ('public.rpc_booking_cancel(uuid)',                                                                            '97e9c289b9d768ff7212529876ecff08'),
      ('public._game_belongs_to_venue(uuid,uuid)',                                                                   '6e5901ff6904c44012897b99d5b0c830')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-728 post: % definition md5 % (expected %)', r.fn, v, r.md;
    END IF;
  END LOOP;

  -- Signature, result, owner, ACL, SECURITY DEFINER/INVOKER, volatility, search_path identical to the pre-image, for
  -- both changed functions; language identical except _slot_conflicts_game, which is now exactly plpgsql (was sql).
  IF EXISTS (SELECT 1 FROM pg_temp.kan728_pre p JOIN pg_proc c ON c.oid = p.oid
              WHERE c.proowner <> p.proowner OR c.proacl::text IS DISTINCT FROM p.acl
                 OR c.prosecdef <> p.prosecdef OR c.provolatile <> p.provolatile
                 OR c.proconfig IS DISTINCT FROM p.proconfig
                 OR pg_get_function_identity_arguments(c.oid) <> p.args
                 OR pg_get_function_result(c.oid) <> p.res
                 OR (c.oid <> 'public._slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)'::regprocedure
                     AND c.prolang <> p.prolang))
     OR (SELECT count(*) FROM pg_temp.kan728_pre) <> 2 THEN
    RAISE EXCEPTION 'KAN-728 post: signature / owner / ACL / SECURITY DEFINER / search_path changed';
  END IF;
  IF (SELECT l.lanname || ':' || p.prosecdef FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
       WHERE p.oid = 'public._slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)'::regprocedure)
     IS DISTINCT FROM 'plpgsql:false'
     OR (SELECT l.lanname FROM pg_temp.kan728_pre p JOIN pg_language l ON l.oid = p.prolang
          WHERE p.oid = 'public._slot_conflicts_game(uuid,timestamp with time zone,timestamp with time zone)'::regprocedure)
     IS DISTINCT FROM 'sql'
     OR (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = '_slot_conflicts_game') <> 1 THEN
    RAISE EXCEPTION 'KAN-728 post: _slot_conflicts_game language is not sql -> plpgsql, it became DEFINER, or an overload appeared';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname !~ '^pg_' AND has_table_privilege(oid, 'public.events', 'SELECT')
                AND NOT (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-728 post: a role may SELECT public.events without bypassing its RLS';
  END IF;
  -- No overload appeared; still not wrapped.
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
        AND proname = 'rpc_booking_hold_for_meetup') <> 1
     OR to_regproc('public.rpc_booking_hold_for_meetup_kan712_inner') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-728 post: overload count changed or an inner appeared';
  END IF;

  -- events still closed to the API, attributes identical.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT')
     OR EXISTS (SELECT 1 FROM pg_temp.kan728_pre_events p, pg_class c
                 WHERE c.oid = 'public.events'::regclass
                   AND (c.relacl::text IS DISTINCT FROM p.acl OR NOT c.relrowsecurity OR NOT c.relforcerowsecurity)) THEN
    RAISE EXCEPTION 'KAN-728 post: public.events opened to the API or its posture changed';
  END IF;
END
$post$;

COMMIT;
