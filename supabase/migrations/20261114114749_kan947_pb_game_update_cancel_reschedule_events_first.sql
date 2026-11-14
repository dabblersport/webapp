-- KAN-947 P-b: update, cancel and reschedule write events first, with the P-a pattern
-- (20261114114127_kan947_pa_game_create_events_first.sql): the shared fields are written to public.events, the
-- AFTER UPDATE mirror trg_zz_kan947_events_game_mirror copies them onto games until KAN-866 drops them, and the
-- cancel side effects (activity, game.updated notification, chat system line) fire once from the events triggers
-- P-a attached. games is written only for its retained columns, and before events, so the mirror's copy of
-- events.updated_at is the last word (parity).
--
-- Authored from the live pg_get_functiondef, 2026-11-14, project wtncuzcskpigqpmnxwws. Pre-image (functiondef md5):
--   rpc_cancel_game_kan712_inner(uuid,text)                         e0c6b7a80d650eef898b96023bdec52f
--   rpc_reschedule_game_kan712_inner(uuid,timestamptz,timestamptz)  749391bc89be90d74c9400429191e673
--   rpc_update_game_kan712_inner(17 args)                           14698e8b80623b1aa0c318e0eaa18add
--   rpc_update_game_legacy_v1_kan712_inner(16 args)                 4379755305bbb2fa62a3cf58723c8e1a
-- CREATE OR REPLACE keeps owner, ACL, SECURITY, volatility and search_path; all are re-asserted below.
--
-- 1. cancel: the same UPDATE, on events (host/admin and not-yet-cancelled predicate unchanged, KAN-810 repeat
--    cancel unchanged). No kan718_game_event_sync.
-- 2. reschedule: the host/admin predicate now reads events.creator_user_id (it read games.creator_user_id); the
--    UPDATE sets start_at/end_at on events.
-- 3. update (both): same validations in the same order; the row is read and locked (events + games) under the same
--    predicate as the old UPDATE ... FROM events; location facts from kan947_game_derive(old events, new space,
--    -, old events, old space), which is kan718_game_derive's call with the games row swapped for the events row;
--    games gets venue_space_id, allow_spectators, allows_waitlist, rules[, price_aed]; events gets the shared
--    fields with the same expressions. The legacy_v1 inner read the shared fields from g; they now come from
--    events, which P-a and gate d (16316) showed equal.
-- Test: supabase/tests/events_p4/kan947_pb_game_writes_live_test.sql.

do $pre$
declare
  k record;
begin
  for k in select * from (values
    ('public.rpc_cancel_game_kan712_inner(uuid,text)', 'e0c6b7a80d650eef898b96023bdec52f'),
    ('public.rpc_reschedule_game_kan712_inner(uuid,timestamp with time zone,timestamp with time zone)', '749391bc89be90d74c9400429191e673'),
    ('public.rpc_update_game_kan712_inner(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)', '14698e8b80623b1aa0c318e0eaa18add'),
    ('public.rpc_update_game_legacy_v1_kan712_inner(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer)', '4379755305bbb2fa62a3cf58723c8e1a')) v(fn, pre)
  loop
    if md5(pg_get_functiondef(to_regprocedure(k.fn))) is distinct from k.pre then
      raise exception 'KAN-947 P-b pre: % absent or drifted', k.fn;
    end if;
  end loop;
  if to_regprocedure('public.kan947_game_derive(public.events,uuid,uuid,public.events,uuid)') is null
     or not exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass and tgname = 'trg_zz_kan947_events_game_mirror' and tgenabled = 'O') then
    raise exception 'KAN-947 P-b pre: P-a is not applied';
  end if;
end
$pre$;

CREATE OR REPLACE FUNCTION public.rpc_cancel_game_kan712_inner(p_game_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_e public.events;
BEGIN
  -- KAN-947: the cancel is written to the events parent; trg_zz_kan947_events_game_mirror copies it onto games and
  -- the events triggers send the activity update, the game.updated notifications and the chat system line once.
  UPDATE public.events e
  SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
  WHERE e.event_type = 'game'
    AND e.id IN (SELECT g.event_id FROM public.games g WHERE g.id = p_game_id)
    AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
    AND e.is_cancelled IS NOT TRUE   -- KAN-810: a repeat cancel keeps the first cancel's cancelled_at / reason
  RETURNING * INTO v_e;
  IF NOT FOUND THEN
    -- KAN-810: already cancelled, and the caller may cancel it: same result as before, nothing rewritten.
    IF EXISTS (SELECT 1 FROM public.games g
                 JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-913
                WHERE g.id = p_game_id
                  AND e.is_cancelled IS TRUE
                  AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))) THEN
      RETURN 'cancelled';
    END IF;
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  RETURN 'cancelled';
END$function$;

CREATE OR REPLACE FUNCTION public.rpc_reschedule_game_kan712_inner(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_e public.events;
BEGIN
  IF p_end_at <= p_start_at THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_time_range';
  END IF;
  -- KAN-947: written to the events parent; the host check reads events.creator_user_id.
  UPDATE public.events e
  SET start_at = p_start_at, end_at = p_end_at
  WHERE e.event_type = 'game'
    AND e.id IN (SELECT g.event_id FROM public.games g WHERE g.id = p_game_id)
    AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
  RETURNING * INTO v_e;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  RETURN 'rescheduled';
END$function$;

CREATE OR REPLACE FUNCTION public.rpc_update_game_kan712_inner(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_clear_venue boolean DEFAULT false, p_listing_visibility text DEFAULT NULL::text, p_join_policy text DEFAULT NULL::text, p_allow_spectators boolean DEFAULT NULL::boolean, p_allows_waitlist boolean DEFAULT NULL::boolean, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_clear_skill boolean DEFAULT false, p_rules jsonb DEFAULT NULL::jsonb, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_roster_count integer;
  v_o     public.events;
  v_d     public.events;
  v_g     public.games;
  v_space uuid;
begin
  if p_end_at <= p_start_at then
    raise exception using errcode='P0001', message='invalid_time_range';
  end if;
  -- CEO 2026-10-08: saving a game needs a price (0 is "Free"); an old game with no
  -- price gets one the first time its host saves it.
  if p_price_aed is null or p_price_aed < 0 then
    raise exception using errcode='P0001', message='price_required';
  end if;
  if p_max_players is not null and p_max_players < 1 then
    raise exception using errcode='P0001', message='invalid_max_players';
  end if;
  if p_min_players is not null and p_min_players < 1 then
    raise exception using errcode='P0001', message='invalid_min_players';
  end if;
  if p_min_players is not null and p_max_players is not null
     and p_min_players > p_max_players then
    raise exception using errcode='P0001', message='invalid_player_range';
  end if;

  select count(*) into v_roster_count
  from public.game_roster
  where game_id = p_game_id and status = 'active';

  -- KAN-947: read and lock under the old UPDATE's predicate; shared facts from events, game-only from games.
  select e.* into v_o
    from public.events e
    join public.games g on g.event_id = e.id
   where e.event_type = 'game'
     and g.id = p_game_id
     and e.is_cancelled = false
     and e.end_at > now()
     and (e.creator_user_id = auth.uid() or public.is_admin(auth.uid()))
   for update of e, g;
  if not found then
    raise exception using errcode='P0001', message='not_host_or_not_found';
  end if;
  select * into v_g from public.games where id = p_game_id;
  v_space := case when p_clear_venue then null else coalesce(p_venue_space_id, v_g.venue_space_id) end;
  -- KAN-718 location facts from the new space (the KAN-718 derive on the events row: old row + new space, old row).
  v_d := public.kan947_game_derive(v_o, v_space, v_g.sport_variant_id, v_o, v_g.venue_space_id);

  -- games first (retained columns), then events: the mirror's copy of events.updated_at lands last.
  update public.games g
  set venue_space_id   = v_space,
      allow_spectators = coalesce(p_allow_spectators, g.allow_spectators),
      allows_waitlist  = coalesce(p_allows_waitlist, g.allows_waitlist),
      rules            = coalesce(p_rules, g.rules, '{}'::jsonb)
                         || case when p_min_players is not null
                              then jsonb_build_object('min_players', p_min_players)
                              else '{}'::jsonb end
                         || case when p_max_players is not null
                              then jsonb_build_object('max_players', p_max_players)
                              else '{}'::jsonb end,
      price_aed        = round(p_price_aed, 2)
  where g.id = p_game_id;

  update public.events e
  set start_at           = p_start_at,
      end_at             = p_end_at,
      title              = coalesce(nullif(p_title, ''), e.title),
      venue_id           = v_d.venue_id,
      geo_location_id    = v_d.geo_location_id,
      area_id            = v_d.area_id,
      joining_rule       = v_d.joining_rule,
      cost_cover         = v_d.cost_cover,
      listing_visibility = coalesce(p_listing_visibility, e.listing_visibility),
      join_policy        = coalesce(p_join_policy, e.join_policy),
      min_skill          = case when p_clear_skill then null
                                else coalesce(p_min_skill::smallint, e.min_skill) end,
      max_skill          = case when p_clear_skill then null
                                else coalesce(p_max_skill::smallint, e.max_skill) end,
      capacity           = greatest(
                             coalesce(p_max_players, e.capacity),
                             v_roster_count
                           )
  where e.id = v_o.id;

  return 'updated';
end$function$;

CREATE OR REPLACE FUNCTION public.rpc_update_game_legacy_v1_kan712_inner(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_clear_venue boolean DEFAULT false, p_listing_visibility text DEFAULT NULL::text, p_join_policy text DEFAULT NULL::text, p_allow_spectators boolean DEFAULT NULL::boolean, p_allows_waitlist boolean DEFAULT NULL::boolean, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_clear_skill boolean DEFAULT false, p_rules jsonb DEFAULT NULL::jsonb, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_roster_count integer;
  v_o     public.events;
  v_d     public.events;
  v_g     public.games;
  v_space uuid;
begin
  if p_end_at <= p_start_at then
    raise exception using errcode='P0001', message='invalid_time_range';
  end if;
  if p_max_players is not null and p_max_players < 1 then
    raise exception using errcode='P0001', message='invalid_max_players';
  end if;
  if p_min_players is not null and p_min_players < 1 then
    raise exception using errcode='P0001', message='invalid_min_players';
  end if;
  if p_min_players is not null and p_max_players is not null
     and p_min_players > p_max_players then
    raise exception using errcode='P0001', message='invalid_player_range';
  end if;

  select count(*) into v_roster_count
  from public.game_roster
  where game_id = p_game_id and status = 'active';

  -- KAN-947: read and lock under the old UPDATE's predicate (now on events); game-only columns from games.
  select e.* into v_o
    from public.events e
    join public.games g on g.event_id = e.id
   where e.event_type = 'game'
     and g.id = p_game_id
     and e.is_cancelled = false
     and e.end_at > now()
     and (e.creator_user_id = auth.uid() or public.is_admin(auth.uid()))
   for update of e, g;
  if not found then
    raise exception using errcode='P0001', message='not_host_or_not_found';
  end if;
  select * into v_g from public.games where id = p_game_id;
  v_space := case when p_clear_venue then null else coalesce(p_venue_space_id, v_g.venue_space_id) end;
  v_d := public.kan947_game_derive(v_o, v_space, v_g.sport_variant_id, v_o, v_g.venue_space_id);

  update public.games g
  set venue_space_id   = v_space,
      allow_spectators = coalesce(p_allow_spectators, g.allow_spectators),
      allows_waitlist  = coalesce(p_allows_waitlist, g.allows_waitlist),
      rules            = coalesce(p_rules, g.rules, '{}'::jsonb)
                         || case when p_min_players is not null
                              then jsonb_build_object('min_players', p_min_players)
                              else '{}'::jsonb end
                         || case when p_max_players is not null
                              then jsonb_build_object('max_players', p_max_players)
                              else '{}'::jsonb end
  where g.id = p_game_id;

  update public.events e
  set start_at           = p_start_at,
      end_at             = p_end_at,
      title              = coalesce(nullif(p_title, ''), e.title),
      venue_id           = v_d.venue_id,
      geo_location_id    = v_d.geo_location_id,
      area_id            = v_d.area_id,
      joining_rule       = v_d.joining_rule,
      cost_cover         = v_d.cost_cover,
      listing_visibility = coalesce(p_listing_visibility, e.listing_visibility),
      join_policy        = coalesce(p_join_policy, e.join_policy),
      min_skill          = case when p_clear_skill then null
                                else coalesce(p_min_skill::smallint, e.min_skill) end,
      max_skill          = case when p_clear_skill then null
                                else coalesce(p_max_skill::smallint, e.max_skill) end,
      capacity           = greatest(
                             coalesce(p_max_players, e.capacity),
                             v_roster_count
                           )
  where e.id = v_o.id;

  return 'updated';
end$function$;

do $post$
declare
  r record;
  n int := 0;
begin
  for r in
    select p.oid::regprocedure::text fn, p.proacl::text acl, p.prosecdef, p.provolatile::text vol,
           array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own, p.prosrc
      from pg_proc p
     where p.oid in ('public.rpc_cancel_game_kan712_inner(uuid,text)'::regprocedure,
                     'public.rpc_reschedule_game_kan712_inner(uuid,timestamp with time zone,timestamp with time zone)'::regprocedure,
                     'public.rpc_update_game_kan712_inner(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)'::regprocedure,
                     'public.rpc_update_game_legacy_v1_kan712_inner(uuid,timestamp with time zone,timestamp with time zone,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer)'::regprocedure)
  loop
    n := n + 1;
    if r.acl <> '{postgres=X/postgres}' or r.prosecdef is not true or r.vol <> 'v'
       or r.cfg <> 'search_path=public' or r.own <> 'postgres' then
      raise exception 'KAN-947 P-b post: % attributes drifted: %', r.fn, r;
    end if;
    if r.prosrc ~ 'kan718_game_event_sync|kan718_game_derive' then
      raise exception 'KAN-947 P-b post: % still calls a games-typed helper', r.fn;
    end if;
  end loop;
  if n <> 4 then raise exception 'KAN-947 P-b post: % of 4 functions found', n; end if;
end
$post$;
