-- KAN-1014: an organiser removing someone chooses remove-only, ban-from-this-event (a game series
-- covers every occurrence) or ban-from-all-my-events. The ban is enforced by BEFORE triggers on the
-- four join tables, so every join/RSVP/request/invite/approve path (RPC or direct) is refused with
-- 'banned'. The removal notification payload is unchanged: it never carries the ban scope.

create table if not exists public.organiser_bans (
  id                 uuid primary key default gen_random_uuid(),
  organiser_user_id  uuid not null references auth.users(id) on delete cascade,
  banned_user_id     uuid not null references auth.users(id) on delete cascade,
  scope              text not null check (scope in ('event','organiser')),
  event_id           uuid references public.events(id) on delete cascade,
  series_id          uuid,
  created_at         timestamptz not null default now(),
  constraint organiser_bans_event_scope check ((scope = 'event') = (event_id is not null)),
  constraint organiser_bans_not_self check (organiser_user_id <> banned_user_id)
);
create unique index if not exists organiser_bans_org_uq
  on public.organiser_bans(organiser_user_id, banned_user_id) where scope = 'organiser';
create unique index if not exists organiser_bans_event_uq
  on public.organiser_bans(organiser_user_id, banned_user_id, event_id) where scope = 'event';
create index if not exists organiser_bans_banned_idx on public.organiser_bans(banned_user_id, organiser_user_id);

alter table public.organiser_bans enable row level security;
revoke all on public.organiser_bans from public, anon, authenticated;
grant select, insert, delete on public.organiser_bans to authenticated;

create policy organiser_bans_select_own on public.organiser_bans
  for select to authenticated using (organiser_user_id = (select auth.uid()));
create policy organiser_bans_delete_own on public.organiser_bans
  for delete to authenticated using (organiser_user_id = (select auth.uid()));
-- authenticated cannot read public.events directly, so the event-ownership check is a definer helper.
create or replace function public.kan1014_is_my_event(p_event_id uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from public.events e where e.id = p_event_id and e.creator_user_id = auth.uid());
$$;
revoke all on function public.kan1014_is_my_event(uuid) from public, anon;
grant execute on function public.kan1014_is_my_event(uuid) to authenticated;
create policy organiser_bans_insert_own on public.organiser_bans
  for insert to authenticated with check (
    organiser_user_id = (select auth.uid())
    and (scope = 'organiser' or public.kan1014_is_my_event(event_id)));

-- Is p_user banned from p_event (by its organiser)?
create or replace function public.kan1014_is_banned(p_event_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1
      from public.events e
      join public.organiser_bans b on b.organiser_user_id = e.creator_user_id and b.banned_user_id = p_user_id
     where e.id = p_event_id and e.creator_user_id <> p_user_id
       and (b.scope = 'organiser'
            or b.event_id = e.id
            or (b.series_id is not null
                and b.series_id = (select g.series_id from public.games g where g.event_id = e.id limit 1))));
$$;

create or replace function public.kan1014_ban_guard()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
  v_user  uuid;
  v_event uuid;
begin
  if tg_table_name = 'game_roster' then
    if new.status <> 'active' or new.role = 'host' then return new; end if;
    if tg_op = 'UPDATE' and old.status = 'active' then return new; end if;
    v_user := coalesce(new.user_id, (select p.user_id from public.profiles p where p.id = new.profile_id));
    select g.event_id into v_event from public.games g where g.id = new.game_id;
  elsif tg_table_name = 'game_waitlist' then
    v_user := coalesce(new.user_id, (select p.user_id from public.profiles p where p.id = new.profile_id));
    select g.event_id into v_event from public.games g where g.id = new.game_id;
  elsif tg_table_name = 'game_join_requests' then
    if new.status <> 'pending' then return new; end if;
    if tg_op = 'UPDATE' and old.status = 'pending' then return new; end if;
    v_user := coalesce(new.from_user_id, (select p.user_id from public.profiles p where p.id = new.from_profile_id));
    select g.event_id into v_event from public.games g where g.id = new.game_id;
  elsif tg_table_name = 'meetup_rsvps' then
    if new.status not in ('going','interested','pending') then return new; end if;
    if tg_op = 'UPDATE' and old.status is not distinct from new.status then return new; end if;
    v_user := new.user_id;
    select mt.event_id into v_event from public.meetups mt where mt.id = new.meetup_id;
  else
    return new;
  end if;

  if v_user is not null and v_event is not null and public.kan1014_is_banned(v_event, v_user) then
    raise exception using errcode = 'P0001', message = 'banned';
  end if;
  return new;
end$$;

drop trigger if exists trg_zzz_kan1014_ban_guard on public.game_roster;
create trigger trg_zzz_kan1014_ban_guard before insert or update of status on public.game_roster
  for each row execute function public.kan1014_ban_guard();
drop trigger if exists trg_zzz_kan1014_ban_guard on public.game_waitlist;
create trigger trg_zzz_kan1014_ban_guard before insert on public.game_waitlist
  for each row execute function public.kan1014_ban_guard();
drop trigger if exists trg_zzz_kan1014_ban_guard on public.game_join_requests;
create trigger trg_zzz_kan1014_ban_guard before insert or update of status on public.game_join_requests
  for each row execute function public.kan1014_ban_guard();
drop trigger if exists trg_zzz_kan1014_ban_guard on public.meetup_rsvps;
create trigger trg_zzz_kan1014_ban_guard before insert or update of status on public.meetup_rsvps
  for each row execute function public.kan1014_ban_guard();

-- Records the ban and clears the banned person's waiting/pending places in scope, so a later
-- waitlist promotion or request approval never trips the guard.
create or replace function public.kan1014_apply_ban(p_organiser uuid, p_user uuid, p_event_id uuid, p_scope text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_series uuid;
begin
  if p_scope = 'none' then return; end if;
  if p_scope = 'event' then
    select g.series_id into v_series from public.games g where g.event_id = p_event_id limit 1;
    insert into public.organiser_bans(organiser_user_id, banned_user_id, scope, event_id, series_id)
    values (p_organiser, p_user, 'event', p_event_id, v_series)
    on conflict (organiser_user_id, banned_user_id, event_id) where scope = 'event' do nothing;
  else
    insert into public.organiser_bans(organiser_user_id, banned_user_id, scope)
    values (p_organiser, p_user, 'organiser')
    on conflict (organiser_user_id, banned_user_id) where scope = 'organiser' do nothing;
  end if;

  delete from public.game_waitlist w using public.games g
   where w.game_id = g.id and w.user_id = p_user and public.kan1014_is_banned(g.event_id, p_user);
  delete from public.game_join_requests r using public.games g
   where r.game_id = g.id and r.from_user_id = p_user and r.status = 'pending'
     and public.kan1014_is_banned(g.event_id, p_user);
end$$;

revoke all on function public.kan1014_is_banned(uuid,uuid) from public, anon, authenticated;
revoke all on function public.kan1014_ban_guard() from public, anon, authenticated;
revoke all on function public.kan1014_apply_ban(uuid,uuid,uuid,text) from public, anon, authenticated;

-- Removal RPCs gain p_ban_scope (default 'none' keeps existing callers). Bodies from pg_get_functiondef.
drop function if exists public.rpc_remove_player(uuid,uuid,text);
create function public.rpc_remove_player(p_game_id uuid, p_profile_id uuid, p_reason text DEFAULT NULL::text, p_ban_scope text DEFAULT 'none')
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_creator uuid;
  v_title   text;
  v_event   uuid;
  v_target  record;
  v_reason  text := nullif(btrim(p_reason), '');
  v_name    text;
  v_before  int;
  v_after   int;
  v_left_at timestamptz;
  v_scope   text := coalesce(nullif(btrim(p_ban_scope), ''), 'none');
begin
  if v_scope not in ('none','event','organiser') then
    raise exception using errcode='P0001', message='invalid_ban_scope';
  end if;
  select ev.creator_user_id, ev.title, ev.id into v_creator, v_title, v_event
  from public.games g
  join public.events ev on ev.id = g.event_id and ev.event_type = 'game'
  where g.id = p_game_id and ev.is_cancelled = false;
  if v_creator is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  if v_creator <> auth.uid() and not public.is_admin(auth.uid()) then
    raise exception using errcode='P0001', message='not_host';
  end if;
  -- KAN-982b: a reason is optional until the app sends one (TODO: enforce reason_required, SCHEMA §21).
  if char_length(v_reason) > 500 then
    raise exception using errcode='P0001', message='reason_too_long';
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

  select count(*) into v_before from public.game_waitlist where game_id = p_game_id;

  -- the roster trigger promotes the next person on the waitlist
  update public.game_roster
     set status = 'kicked', left_at = now()
   where game_id = p_game_id and profile_id = p_profile_id
  returning left_at into v_left_at;

  -- KAN-1014: the ban belongs to the event's organiser, whoever (host or admin) removed.
  perform public.kan1014_apply_ban(v_creator,
    coalesce(v_target.user_id, (select p.user_id from public.profiles p where p.id = p_profile_id)),
    v_event, v_scope);

  -- KAN-1014: the payload never carries the ban scope.
  v_name := public.kan982_display_name(auth.uid());
  perform public.kan982_notify(v_target.user_id, 'game.removed',
    jsonb_build_object('title', v_title)
      || case when v_reason is not null
              then jsonb_build_object('reason', v_reason, 'reason_line', ': ' || v_reason)
              else '{}'::jsonb end
      || case when v_name is not null then jsonb_build_object('organiser', v_name)
              else jsonb_build_object('organiser_en', 'The organiser', 'organiser_ar', 'المنظّم') end,
    'game', p_game_id, auth.uid(),
    'game.removed:' || v_target.id || ':' || public.kan982_tkey(v_left_at));

  select count(*) into v_after from public.game_waitlist where game_id = p_game_id;
  if v_after < v_before then return 'removed_promoted_waitlist'; end if;
  return 'removed';
end$function$;

drop function if exists public.rpc_meetup_remove_attendee(uuid,uuid,text);
create function public.rpc_meetup_remove_attendee(p_meetup_id uuid, p_user_id uuid, p_reason text DEFAULT NULL::text, p_ban_scope text DEFAULT 'none')
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  me       uuid := auth.uid();
  m        record;
  v_reason text := nullif(btrim(p_reason), '');
  v_rsvp   record;
  v_name   text;
  v_scope  text := coalesce(nullif(btrim(p_ban_scope), ''), 'none');
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;
  if v_scope not in ('none','event','organiser') then
    raise exception using errcode='P0001', message='invalid_ban_scope';
  end if;

  select mt.id, mt.event_id, e.creator_user_id, e.title into m
    from public.meetups mt
    join public.events e on e.id = mt.event_id and e.event_type = 'meetup'
   where mt.id = p_meetup_id for update of mt;
  if not found then
    raise exception using errcode='P0001', message='meetup_not_found';
  end if;

  if not (m.creator_user_id = me or public.is_admin(me)) then
    raise exception using errcode='P0001', message='not_host';
  end if;

  if p_user_id = m.creator_user_id then
    raise exception using errcode='P0001', message='cannot_remove_host';
  end if;

  -- KAN-982b: a reason is optional until the app sends one (TODO: enforce reason_required, SCHEMA §21).
  if char_length(v_reason) > 500 then
    raise exception using errcode='P0001', message='reason_too_long';
  end if;

  update public.meetup_rsvps
     set status = 'removed', updated_at = now()
   where meetup_id = p_meetup_id and user_id = p_user_id
     and status in ('going','interested','pending')
  returning * into v_rsvp;
  if not found then
    raise exception using errcode='P0001', message='attendee_not_found';
  end if;

  perform public.kan1014_apply_ban(m.creator_user_id, p_user_id, m.event_id, v_scope);

  -- KAN-1014: the payload never carries the ban scope.
  v_name := public.kan982_display_name(me);
  perform public.kan982_notify(p_user_id, 'meetup.removed',
    jsonb_build_object('title', m.title)
      || case when v_reason is not null
              then jsonb_build_object('reason', v_reason, 'reason_line', ': ' || v_reason)
              else '{}'::jsonb end
      || case when v_name is not null then jsonb_build_object('organiser', v_name)
              else jsonb_build_object('organiser_en', 'The organiser', 'organiser_ar', 'المنظّم') end,
    'meetup', p_meetup_id, me,
    'meetup.removed:' || v_rsvp.id || ':' || public.kan982_tkey(v_rsvp.updated_at));
  return 'removed';
end;
$function$;

-- The organiser's ban list.
create or replace function public.rpc_list_my_bans()
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'ban_id', b.id,
           'banned_user_id', b.banned_user_id,
           'banned_profile_id', p.id,
           'display_name', p.display_name,
           'username', p.username,
           'avatar_url', p.avatar_url,
           'scope', b.scope,
           'event_id', b.event_id,
           'event_type', e.event_type,
           'event_title', e.title,
           'series_id', b.series_id,
           'created_at', b.created_at) order by b.created_at desc), '[]'::jsonb)
    from public.organiser_bans b
    left join public.events e on e.id = b.event_id
    left join lateral (select pr.id, pr.display_name, pr.username, pr.avatar_url
                         from public.profiles pr where pr.user_id = b.banned_user_id
                        order by pr.is_active desc, pr.created_at asc limit 1) p on true
   where b.organiser_user_id = auth.uid();
$$;

create or replace function public.rpc_lift_ban(p_ban_id uuid)
returns text language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;
  delete from public.organiser_bans where id = p_ban_id and organiser_user_id = auth.uid();
  if not found then
    raise exception using errcode='P0001', message='ban_not_found';
  end if;
  return 'lifted';
end$$;

revoke all on function public.rpc_remove_player(uuid,uuid,text,text) from public, anon;
revoke all on function public.rpc_meetup_remove_attendee(uuid,uuid,text,text) from public, anon;
revoke all on function public.rpc_list_my_bans() from public, anon;
revoke all on function public.rpc_lift_ban(uuid) from public, anon;
grant execute on function public.rpc_remove_player(uuid,uuid,text,text) to authenticated, service_role;
grant execute on function public.rpc_meetup_remove_attendee(uuid,uuid,text,text) to authenticated, service_role;
grant execute on function public.rpc_list_my_bans() to authenticated, service_role;
grant execute on function public.rpc_lift_ban(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';
