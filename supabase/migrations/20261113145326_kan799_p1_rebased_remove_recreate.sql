-- KAN-799 rebased on live (KAN-862 package P1, backend-1; Epic KAN-708). Supersedes
-- supabase/migrations/_superseded/20261104110600_kan799_d04_blockers_remove_recreate.sql (authored, never applied).
--
-- WHAT: rpc_recreate_from_game reads sport_id, start_at, end_at, capacity, listing_visibility, join_policy, title
--   and the host from events; rpc_remove_player reads the host and is_cancelled from events. games keeps id, venue_space_id.
--
-- AUTHORED FROM THE LIVE CATALOGUE (T-058), wtncuzcskpigqpmnxwws, 2026-11-13: pg_get_functiondef of each target.
-- Each live md5(prosrc) was compared with the superseded file's pre-image pin; the body change is that file's
-- intent and nothing else. Live pre-image -> post-image md5(prosrc):
--   public.rpc_recreate_from_game(uuid,boolean)  6e410ca16771fbdf20a6f37553131e6c -> 1ff1447738e359d097002ac3ea5d2099
--   public.rpc_remove_player(uuid,uuid)  ab3b5239eb5bb283622679c842ba9cd7 -> ff739900a0cfc72e482e8f4c8543fbb0
--
-- HOW: CREATE OR REPLACE with the same signature keeps oid, owner, ACL, SECURITY, volatility and search_path; the
-- post block asserts them, and every trigger definition on them, unchanged. Definitions only: no row is written and
-- no column, table, policy or existing grant changes. Equivalence: the pre block refuses unless every games row has
-- its 'game' events parent and every games column whose read moves equals its events counterpart (KAN-711 parity;
-- checked only while the column exists). Any other live body refuses (re-author from pg_get_functiondef).
-- No BEGIN/COMMIT: apply_migration and the CLI wrap each migration in one transaction.
-- Live test: supabase/tests/events_p4/kan799_p1_live_test.sql (BEGIN ... ROLLBACK, TAP).

do $pre$
declare
  r record; c text; v_n bigint; v_attr jsonb := '{}'::jsonb;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'kan799 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  for r in select * from (values
    ('public.rpc_recreate_from_game(uuid,boolean)', '6e410ca16771fbdf20a6f37553131e6c', '1ff1447738e359d097002ac3ea5d2099'),
    ('public.rpc_remove_player(uuid,uuid)', 'ab3b5239eb5bb283622679c842ba9cd7', 'ff739900a0cfc72e482e8f4c8543fbb0')) t(fn, pin, post) loop
    if to_regprocedure(r.fn) is null then
      raise exception 'kan799 pre: % is absent', r.fn;
    end if;
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.pin then
      raise exception 'kan799 pre: pre-image drift on % (md5(prosrc) %, expected %); re-author from pg_get_functiondef',
        r.fn, (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.pin;
    end if;
    v_attr := v_attr || jsonb_build_object(r.fn, (
      select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
        from pg_proc p where p.oid = to_regprocedure(r.fn)));
  end loop;
  select count(*) into v_n from public.games g
    left join public.events e on e.id = g.event_id and e.event_type = 'game' where e.id is null;
  if v_n > 0 then
    raise exception 'kan799 pre: % games row(s) without a ''game'' events parent', v_n;
  end if;
  foreach c in array array['creator_user_id', 'is_cancelled', 'sport_id', 'start_at', 'end_at', 'capacity', 'listing_visibility', 'join_policy', 'title'] loop
    if exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = c and attnum > 0 and not attisdropped) then
      execute format('select count(*) from public.games x join public.events e on e.id = x.event_id and e.event_type = %L
                       where x.%I is distinct from e.%I', 'game', c, c) into v_n;
      if v_n > 0 then
        raise exception 'kan799 pre: % games row(s) differ from events on % (KAN-711 parity)', v_n, c;
      end if;
    end if;
  end loop;
  perform set_config('kan799.attr', v_attr::text, true);
end
$pre$;

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

do $post$
declare
  r record; v_attr jsonb := current_setting('kan799.attr')::jsonb; v_now jsonb;
begin
  for r in select * from (values
    ('public.rpc_recreate_from_game(uuid,boolean)', '6e410ca16771fbdf20a6f37553131e6c', '1ff1447738e359d097002ac3ea5d2099'),
    ('public.rpc_remove_player(uuid,uuid)', 'ab3b5239eb5bb283622679c842ba9cd7', 'ff739900a0cfc72e482e8f4c8543fbb0')) t(fn, pin, post) loop
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.post then
      raise exception 'kan799 post: % body md5 %, expected %', r.fn,
        (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.post;
    end if;
    select jsonb_build_array(pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
               p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset, p.proisstrict, p.proparallel,
               (select string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgname) from pg_trigger t
                 where t.tgfoid = p.oid and not t.tgisinternal))
      into v_now from pg_proc p where p.oid = to_regprocedure(r.fn);
    if v_now is distinct from v_attr -> r.fn then
      raise exception 'kan799 post: % signature/attributes/owner/ACL/trigger changed: % -> %', r.fn, v_attr -> r.fn, v_now;
    end if;
  end loop;
end
$post$;
