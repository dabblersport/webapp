-- KAN-799 (supporting KAN-772 / KAN-719, Epic KAN-708): the two D04 BLOCKER functions that are absent from the local
-- chain (supabase/tests/events_p4/KAN718_D04_DISPOSITION.md rows 27/28, "baseline only") now read their shared
-- fields from public.events, so they keep working after KAN-719 Z01
-- (20261105100000_kan719_z01_remove_replaced_columns.sql) drops those columns from public.games.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (schema_change).
-- Local proof: supabase/tests/events_p4/kan799_d04_remove_recreate_test.sql (throwaway PG16; it installs the
-- baseline pre-images as a fixture because the local chain has neither function).
--
-- No DROP, no table/column/grant/policy change, no row written, no write path changed. Two bodies are replaced in
-- place (CREATE OR REPLACE, same signature, so owner and ACL are kept; asserted in section 3):
--
--   function                              field(s) now read from events                         pre-image
--   rpc_remove_player(uuid,uuid)          creator_user_id, is_cancelled                         baseline 20260829080500:14839-14902
--   rpc_recreate_from_game(uuid,boolean)  sport_id, start_at, end_at, capacity,                 baseline 20260829080500:14783-14817
--                                         listing_visibility, join_policy, title, creator_user_id
--
-- Only those reads change; every other byte of each body is the pre-image's. Subtype-only fields stay on the
-- subtype: games.id, games.venue_space_id (retained by Z01), game_roster, game_waitlist. The parent is joined as
-- `public.events ev ON ev.id = <games alias>.event_id AND ev.event_type = 'game'` (INNER: event_id is NOT NULL and
-- FK-validated since the KAN-712 cutover and events.id is the PK, so the join neither drops nor doubles a row;
-- section 0 also refuses if any game lacks its typed parent). rpc_recreate_from_game keeps its record variable `g`,
-- so its games alias is `gm` (a table alias `g` would collide with the PL/pgSQL record of the same name).
--
-- KAN-712 INTERACTION: neither function writes public.games or public.events. rpc_remove_player writes
-- game_roster / game_waitlist / notifications; rpc_recreate_from_game creates a content_drafts row through
-- rpc_draft_create (a draft, not a game: the game is made later by the draft-publish path). So there is no write
-- to route through the KAN-712 contract and none is added (no dual write). Section 0 refuses if either has been put
-- on the KAN-712 wrap list (kan712_wrapped_rpcs).
--
-- KAN-714 PART 2 INTERACTION: 20261105110000_kan714_events_parent_reads_2.sql drift-pins these two functions'
-- md5(prosrc) to the same baseline values pinned below. Once this file is applied, that file's drift pin refuses
-- for these two (by design: re-author it from pg_get_functiondef, or drop them from its list).
--
-- T-058 SUBSTITUTE (as KAN-772): production is not read here. Section 0 pins md5(prosrc), SECURITY, volatility and
-- search_path of each pre-image as authored from the repository baseline (the same md5 values KAN-714 part 2 pinned
-- independently); any drift fails closed -- re-author from pg_get_functiondef on the live catalogue in that case.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_bad text;
  v_n bigint;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'KAN-799 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  if to_regclass('public.events') is null then
    raise exception 'KAN-799 pre: public.events missing (KAN-710 not applied)';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass
                  and tgname = 'trg_zz_kan712_events_compat_mirror' and tgenabled <> 'D') then
    raise exception 'KAN-799 pre: KAN-712 cutover not live (compat mirror trigger on events missing or disabled)';
  end if;
  if to_regclass('public.kan712_wrapped_rpcs') is not null and exists (
       select 1 from public.kan712_wrapped_rpcs w where w.name in ('rpc_remove_player', 'rpc_recreate_from_game')) then
    raise exception 'KAN-799 pre: a target function is on the KAN-712 wrap list; re-triage';
  end if;

  -- Pre-image pins: md5(prosrc) | SECURITY DEFINER | volatility | proconfig
  select string_agg(t.f || ' (' || coalesce(md5(p.prosrc) || '|' || p.prosecdef::text || '|' || p.provolatile::text || '|' || p.proconfig::text, 'absent') || ')', '; ')
    into v_bad
    from (values
      ('public.rpc_remove_player(uuid,uuid)',           'ab3b5239eb5bb283622679c842ba9cd7'),
      ('public.rpc_recreate_from_game(uuid,boolean)',   '6e410ca16771fbdf20a6f37553131e6c')
    ) t(f, src)
    left join pg_proc p on p.oid = to_regprocedure(t.f)
   where p.oid is null or md5(p.prosrc) <> t.src or not p.prosecdef or p.provolatile <> 'v'
      or p.proconfig is distinct from array['search_path=public'];
  if v_bad is not null then
    raise exception 'KAN-799 pre: pre-image drift (re-author from pg_get_functiondef on this catalogue): %', v_bad;
  end if;

  -- Every game has exactly its typed parent (KAN-712 cutover invariant).
  select count(*) into v_n
    from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game'
   where e.id is null;
  if v_n <> 0 then
    raise exception 'KAN-799 pre: % game row(s) without their typed events parent', v_n;
  end if;

  -- No value this file starts reading from events may differ from the legacy mirror.
  select count(*) into v_n
    from public.games g join public.events e on e.id = g.event_id
   where (g.creator_user_id, g.is_cancelled, g.sport_id, g.start_at, g.end_at, g.capacity, g.listing_visibility,
          g.join_policy, g.title)
         is distinct from
         (e.creator_user_id, e.is_cancelled, e.sport_id, e.start_at, e.end_at, e.capacity, e.listing_visibility,
          e.join_policy, e.title);
  if v_n <> 0 then
    raise exception 'KAN-799 pre: % game row(s) differ from events on a field this migration starts reading; reconcile first (KAN-711 parity)', v_n;
  end if;
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image attributes (asserted unchanged in section 3).
-- ---------------------------------------------------------------------------------------------------------
create temp table kan799_pre on commit drop as
select p.oid, p.oid::regprocedure::text as fn, pg_get_function_identity_arguments(p.oid) as args,
       pg_get_function_result(p.oid) as res, p.prorettype, p.prosecdef, p.provolatile, p.proconfig, p.proacl,
       p.proowner, p.proretset, p.proisstrict, p.proparallel, p.pronargdefaults
  from pg_proc p
 where p.oid in ('public.rpc_remove_player(uuid,uuid)'::regprocedure,
                 'public.rpc_recreate_from_game(uuid,boolean)'::regprocedure);

-- ---------------------------------------------------------------------------------------------------------
-- 2. Replacements. Pre-image bodies verbatim except the reads listed in the header.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_recreate_from_game(p_game_id uuid, p_shift_week boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
DECLARE g record; payload jsonb; did uuid;
BEGIN
  SELECT gm.id, ev.sport_id, gm.venue_space_id, ev.start_at, ev.end_at, ev.capacity, ev.listing_visibility, ev.join_policy, ev.title
  INTO g FROM public.games gm JOIN public.events ev ON ev.id = gm.event_id AND ev.event_type = 'game' WHERE gm.id = p_game_id;

  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_found'; END IF;

  IF NOT EXISTS(
    SELECT 1 FROM public.games gg JOIN public.events ev ON ev.id = gg.event_id AND ev.event_type = 'game'
    WHERE gg.id = p_game_id
      AND (ev.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_authorized';
  END IF;

  payload := jsonb_build_object(
    'sport_id',           g.sport_id,
    'venue_space_id',     g.venue_space_id,
    'start_at',           CASE WHEN p_shift_week THEN public._next_week_same_time(g.start_at) ELSE g.start_at END,
    'end_at',             CASE WHEN p_shift_week THEN public._next_week_same_time(g.end_at)   ELSE g.end_at   END,
    'capacity',           g.capacity,
    'listing_visibility', g.listing_visibility,
    'join_policy',        g.join_policy,
    'title',              g.title
  );

  did := public.rpc_draft_create('game', payload);
  RETURN did;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_remove_player(p_game_id uuid, p_profile_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
declare
  v_creator uuid;
  v_target record;
  w_profile uuid;
  upsert_ct int := 0;
begin
  select ev.creator_user_id into v_creator
  from public.games g
  join public.events ev on ev.id = g.event_id and ev.event_type = 'game'
  where g.id = p_game_id and ev.is_cancelled = false;
  if v_creator is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  if v_creator <> auth.uid() and not public.is_admin(auth.uid()) then
    raise exception using errcode='P0001', message='not_host';
  end if;

  select * into v_target
  from public.game_roster
  where game_id = p_game_id and profile_id = p_profile_id and status = 'active'
  for update;
  if not found then
    raise exception using errcode='P0001', message='player_not_on_roster';
  end if;
  if v_target.role = 'host' then
    raise exception using errcode='P0001', message='cannot_remove_host';
  end if;

  update public.game_roster
     set status = 'kicked', left_at = now()
   where game_id = p_game_id and profile_id = p_profile_id;

  if v_target.user_id is not null then
    perform public.process_notification_event(
      v_target.user_id,
      'game.removed',
      'game',
      p_game_id,
      auth.uid(),
      'You''ve been removed from a game'
    );
  end if;

  select wl.profile_id into w_profile
  from public.game_waitlist wl
  where wl.game_id = p_game_id
  order by wl.position asc
  limit 1;
  if w_profile is null then return 'removed'; end if;

  insert into public.game_roster (game_id, profile_id, role, status)
  values (p_game_id, w_profile, 'player', 'active')
  on conflict (game_id, profile_id) do update set status='active', left_at=null;
  get diagnostics upsert_ct = row_count;
  delete from public.game_waitlist
  where game_id = p_game_id and profile_id = w_profile;

  if upsert_ct > 0 then return 'removed_promoted_waitlist'; end if;
  return 'removed';
end$$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions: signature, result, security, volatility, search_path, owner and ACL unchanged.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare v_bad text;
begin
  select string_agg(b.fn, ', ') into v_bad
    from kan799_pre b
    left join pg_proc p on p.oid = b.oid
   where p.oid is null
      or (pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prorettype, p.prosecdef,
          p.provolatile, p.proconfig, p.proacl::text, p.proowner, p.proretset, p.proisstrict, p.proparallel,
          p.pronargdefaults)
         is distinct from
         (b.args, b.res, b.prorettype, b.prosecdef, b.provolatile, b.proconfig, b.proacl::text, b.proowner,
          b.proretset, b.proisstrict, b.proparallel, b.pronargdefaults);
  if v_bad is not null then
    raise exception 'KAN-799 post: attributes changed for %', v_bad;
  end if;

end
$post$;

commit;
