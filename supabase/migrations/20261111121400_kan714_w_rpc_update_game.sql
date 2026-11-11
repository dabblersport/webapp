-- KAN-912 (KAN-714 chain stage W, KAN-866 follow-up; Epic KAN-708, Events P4): the 17-argument
-- public.rpc_update_game_kan712_inner(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,
-- integer,boolean,jsonb,integer,integer,numeric) stops READING the games columns that KAN-866
-- (20261111120000_kan719b_drop_client_read_games_columns.sql) removes. Its writes to games are not touched.
--
-- WHERE THE BODY COMES FROM. 20261008140000_game_price_meetup_setting.sql:283-354 created it as public.rpc_update_game
-- (17 args, with p_price_aed). 20261103110000_kan712_cutover.sql wrapped it: kan712_wrap_rpc renamed it to
-- rpc_update_game_kan712_inner (prosrc unchanged), revoked every API grant from it (owner-only EXECUTE) and created the
-- same-signature public.rpc_update_game wrapper. No later file replaces it (20260829080500 baseline holds only the
-- 16-arg ancestor, 20261008180000 only revokes on the public 17-arg, 20261104110800 adds the 18-arg KAN-809 overload,
-- which calls the public 17-arg wrapper). md5(prosrc) of that body is 4529d87f1cbb5b5ff856fa39f33bb75f.
--
-- WHY. KAN-866 removes 22 games columns (creator_profile_id, creator_user_id, title, start_at, end_at, capacity,
-- listing_visibility, join_policy, is_cancelled, cancelled_at, cancelled_reason, sport_id, area_id, geo_location_id,
-- venue_id, min_skill, max_skill, joining_rule, cost_cover, request_id, created_at, updated_at). The body READS nine
-- of them through g (is_cancelled, end_at, creator_user_id, title, listing_visibility, join_policy, min_skill,
-- max_skill, capacity), at nine sites:
--   WHERE  g.is_cancelled = false, g.end_at > now(), (g.creator_user_id = auth.uid() or public.is_admin(auth.uid()))
--   SET    coalesce(nullif(p_title,''), g.title), coalesce(p_listing_visibility, g.listing_visibility),
--          coalesce(p_join_policy, g.join_policy), coalesce(p_min_skill, g.min_skill), coalesce(p_max_skill, g.max_skill),
--          coalesce(p_max_players, g.capacity)
-- READ RULE (QA ruling): a mention of one of the 22 stays on games only as the bare SET target or a FOR UPDATE target
-- (this body has no FOR UPDATE); every other mention is a read and moves to public.events e.
--
-- WHAT. UPDATE public.games g SET ... FROM public.events e WHERE e.id = g.event_id AND e.event_type = 'game'
-- AND g.id = p_game_id AND <the three predicates on e.*>, and the six COALESCE fallbacks read e.<col>. The admin branch
-- (or public.is_admin(auth.uid())) is kept verbatim. Unchanged: every SET target, WHERE g.id = p_game_id, the game-only
-- reads g.venue_space_id, g.allow_spectators, g.allows_waitlist, g.rules, the game_roster count, every guard and
-- message; one comment line is added. events.id is its primary key, so the join matches at most one row: the UPDATE
-- touches the same row or none, exactly as before, while games and events agree (KAN-711 parity, which KAN-866
-- requires before it drops the columns). Signature, defaults, RETURNS text, LANGUAGE plpgsql, VOLATILE,
-- SECURITY DEFINER, SET search_path TO 'public' are unchanged; CREATE OR REPLACE keeps oid, owner and ACL.
-- No DROP, no CASCADE, no GRANT/REVOKE, no ALTER OWNER, no table, column, policy, trigger or row touched.
-- Neither the public 17-arg wrapper (events lock + call to this inner, no games read) nor the 18-arg KAN-809 overload
-- (reads only events.updated_at FOR UPDATE, then calls the wrapper) is touched.
--
-- ONLY WHERE PRESENT. If the inner is absent this migration raises a notice and does nothing.
--
-- T-058 SUBSTITUTE. Production is not read here. The guard pins md5(prosrc) to the pre-image above and refuses on
-- drift; re-author from pg_get_functiondef if it fires. The post check pins the new body and asserts that no
-- g.<KAN-866 column> remains (SET targets are bare names and do not match); post md5(prosrc) 6638b5cfed53f133eed91385f72284a5.
-- No BEGIN/COMMIT: the Supabase CLI runs each migration in one transaction (with psql use --single-transaction).
--
-- AUTHORED ONLY. Memphis applies it (D-043). Local proof:
--   supabase/tests/events_p4/kan714_w_rpc_update_game_test.sql
--
-- ROLLBACK (after COMMIT). Run uncommented, in one transaction, as postgres. Pre-image, as pg_get_functiondef gives it
-- for 20261008140000:283-354 after the KAN-712 rename (md5(prosrc) 4529d87f1cbb5b5ff856fa39f33bb75f):
-- KAN912-ROLLBACK-BEGIN
-- CREATE OR REPLACE FUNCTION public.rpc_update_game_kan712_inner(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_clear_venue boolean DEFAULT false, p_listing_visibility text DEFAULT NULL::text, p_join_policy text DEFAULT NULL::text, p_allow_spectators boolean DEFAULT NULL::boolean, p_allows_waitlist boolean DEFAULT NULL::boolean, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_clear_skill boolean DEFAULT false, p_rules jsonb DEFAULT NULL::jsonb, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric)
--  RETURNS text
--  LANGUAGE plpgsql
--  SECURITY DEFINER
--  SET search_path TO 'public'
-- AS $function$
-- declare
--   v_roster_count integer;
-- begin
--   if p_end_at <= p_start_at then
--     raise exception using errcode='P0001', message='invalid_time_range';
--   end if;
--   -- CEO 2026-10-08: saving a game needs a price (0 is "Free"); an old game with no
--   -- price gets one the first time its host saves it.
--   if p_price_aed is null or p_price_aed < 0 then
--     raise exception using errcode='P0001', message='price_required';
--   end if;
--   if p_max_players is not null and p_max_players < 1 then
--     raise exception using errcode='P0001', message='invalid_max_players';
--   end if;
--   if p_min_players is not null and p_min_players < 1 then
--     raise exception using errcode='P0001', message='invalid_min_players';
--   end if;
--   if p_min_players is not null and p_max_players is not null
--      and p_min_players > p_max_players then
--     raise exception using errcode='P0001', message='invalid_player_range';
--   end if;
--
--   select count(*) into v_roster_count
--   from public.game_roster
--   where game_id = p_game_id and status = 'active';
--
--   update public.games g
--   set start_at           = p_start_at,
--       end_at             = p_end_at,
--       title              = coalesce(nullif(p_title, ''), g.title),
--       venue_space_id     = case
--                              when p_clear_venue then null
--                              else coalesce(p_venue_space_id, g.venue_space_id)
--                            end,
--       listing_visibility = coalesce(p_listing_visibility, g.listing_visibility),
--       join_policy        = coalesce(p_join_policy, g.join_policy),
--       allow_spectators   = coalesce(p_allow_spectators, g.allow_spectators),
--       allows_waitlist    = coalesce(p_allows_waitlist, g.allows_waitlist),
--       min_skill          = case when p_clear_skill then null
--                                 else coalesce(p_min_skill, g.min_skill) end,
--       max_skill          = case when p_clear_skill then null
--                                 else coalesce(p_max_skill, g.max_skill) end,
--       capacity           = greatest(
--                              coalesce(p_max_players, g.capacity),
--                              v_roster_count
--                            ),
--       rules              = coalesce(p_rules, g.rules, '{}'::jsonb)
--                            || case when p_min_players is not null
--                                 then jsonb_build_object('min_players', p_min_players)
--                                 else '{}'::jsonb end
--                            || case when p_max_players is not null
--                                 then jsonb_build_object('max_players', p_max_players)
--                                 else '{}'::jsonb end,
--       price_aed          = round(p_price_aed, 2)
--   where g.id = p_game_id
--     and g.is_cancelled = false
--     and g.end_at > now()
--     and (g.creator_user_id = auth.uid() or public.is_admin(auth.uid()));
--
--   if not found then
--     raise exception using errcode='P0001', message='not_host_or_not_found';
--   end if;
--
--   return 'updated';
-- end$function$;
-- KAN912-ROLLBACK-END

do $kan912$
declare
  c_sig  constant text := 'public.rpc_update_game_kan712_inner(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)';
  c_pre  constant text := '4529d87f1cbb5b5ff856fa39f33bb75f';
  c_post constant text := '6638b5cfed53f133eed91385f72284a5';
  v_oid  oid;
  v_md5  text;
  v_before jsonb;
  v_after  jsonb;
  v_bad  text;
begin
  v_oid := to_regprocedure(c_sig);
  if v_oid is null then
    raise notice 'KAN-912: 17-argument rpc_update_game_kan712_inner absent; nothing to convert';
    return;
  end if;

  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 <> c_pre then
    raise exception 'KAN-912 pre: pre-image drift on % (md5(prosrc) is %, expected %); re-author from pg_get_functiondef',
      c_sig, v_md5, c_pre;
  end if;

  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_before from pg_proc p where p.oid = v_oid;
  if not (v_before->>'secdef')::boolean then
    raise exception 'KAN-912 pre: % is SECURITY INVOKER; stop and re-measure', c_sig;
  end if;

  execute $ddl$
CREATE OR REPLACE FUNCTION public.rpc_update_game_kan712_inner(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_clear_venue boolean DEFAULT false, p_listing_visibility text DEFAULT NULL::text, p_join_policy text DEFAULT NULL::text, p_allow_spectators boolean DEFAULT NULL::boolean, p_allows_waitlist boolean DEFAULT NULL::boolean, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_clear_skill boolean DEFAULT false, p_rules jsonb DEFAULT NULL::jsonb, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_roster_count integer;
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

  -- KAN-912: shared facts read from events e (authoritative); game-only columns from g; SET targets unchanged.
  update public.games g
  set start_at           = p_start_at,
      end_at             = p_end_at,
      title              = coalesce(nullif(p_title, ''), e.title),
      venue_space_id     = case
                             when p_clear_venue then null
                             else coalesce(p_venue_space_id, g.venue_space_id)
                           end,
      listing_visibility = coalesce(p_listing_visibility, e.listing_visibility),
      join_policy        = coalesce(p_join_policy, e.join_policy),
      allow_spectators   = coalesce(p_allow_spectators, g.allow_spectators),
      allows_waitlist    = coalesce(p_allows_waitlist, g.allows_waitlist),
      min_skill          = case when p_clear_skill then null
                                else coalesce(p_min_skill, e.min_skill) end,
      max_skill          = case when p_clear_skill then null
                                else coalesce(p_max_skill, e.max_skill) end,
      capacity           = greatest(
                             coalesce(p_max_players, e.capacity),
                             v_roster_count
                           ),
      rules              = coalesce(p_rules, g.rules, '{}'::jsonb)
                           || case when p_min_players is not null
                                then jsonb_build_object('min_players', p_min_players)
                                else '{}'::jsonb end
                           || case when p_max_players is not null
                                then jsonb_build_object('max_players', p_max_players)
                                else '{}'::jsonb end,
      price_aed          = round(p_price_aed, 2)
  from public.events e
  where e.id = g.event_id
    and e.event_type = 'game'
    and g.id = p_game_id
    and e.is_cancelled = false
    and e.end_at > now()
    and (e.creator_user_id = auth.uid() or public.is_admin(auth.uid()));

  if not found then
    raise exception using errcode='P0001', message='not_host_or_not_found';
  end if;

  return 'updated';
end$function$
$ddl$;

  -- Post-conditions. Same oid (replaced in place), the authored body, unchanged attributes, no KAN-866 column read.
  if to_regprocedure(c_sig) is distinct from v_oid then
    raise exception 'KAN-912 post: % is not the same function oid after CREATE OR REPLACE', c_sig;
  end if;
  select md5(prosrc) into v_md5 from pg_proc where oid = v_oid;
  if v_md5 <> c_post then
    raise exception 'KAN-912 post: % body md5 is %, expected %', c_sig, v_md5, c_post;
  end if;
  select jsonb_build_object('owner', p.proowner, 'acl', p.proacl::text, 'secdef', p.prosecdef, 'vol', p.provolatile,
                            'config', p.proconfig, 'lang', p.prolang, 'res', pg_get_function_result(p.oid),
                            'args', pg_get_function_arguments(p.oid))
    into v_after from pg_proc p where p.oid = v_oid;
  if v_after is distinct from v_before then
    raise exception 'KAN-912 post: % attributes changed: % -> %', c_sig, v_before, v_after;
  end if;
  -- g is the only games alias in the body (update public.games g). SET targets are bare names and never match.
  select string_agg(distinct lower(m[1]), ', ') into v_bad
    from pg_proc p, regexp_matches(p.prosrc, '\mg\.([a-z_][a-z0-9_]*)', 'gi') m
   where p.oid = v_oid
     and lower(m[1]) = any ('{creator_profile_id,creator_user_id,title,start_at,end_at,capacity,listing_visibility,
                              join_policy,is_cancelled,cancelled_at,cancelled_reason,sport_id,area_id,geo_location_id,
                              venue_id,min_skill,max_skill,joining_rule,cost_cover,request_id,created_at,updated_at}'::text[]);
  if v_bad is not null then
    raise exception 'KAN-912 post: % still reads KAN-866 games column(s): %', c_sig, v_bad;
  end if;
end
$kan912$;
