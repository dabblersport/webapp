-- rpc_remove_player — the game creator (or an admin) removes an active
-- player from the roster.
--
-- Mirrors rpc_leave_game's mechanics: the row is kept with status='kicked'
-- (already in game_roster_status_check) and the first waitlisted player is
-- promoted into the freed slot. The removed player gets an in-app + push
-- notification through process_notification_event ('game.removed' —
-- action_route is stamped automatically for game.* kinds, and the client
-- localizer falls back to the stored title for kinds it doesn't know).

create or replace function public.rpc_remove_player(
  p_game_id uuid,
  p_profile_id uuid
) returns text
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_creator uuid;
  v_target record;
  w_profile uuid;
  upsert_ct int := 0;
begin
  select creator_user_id into v_creator
  from public.games
  where id = p_game_id and is_cancelled = false;
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

  -- Promote the first waitlisted player into the freed slot.
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

-- notifications.kind_key is FK-constrained to notification_kinds — register
-- the new kind (in-app + push, high priority).
insert into public.notification_kinds
  (key, label_en, label_ar, default_priority, default_channels, route_template, timing, is_active)
values
  ('game.removed', 'Removed from game', 'تمت إزالتك من المباراة', 'high', '{inapp,push}', '/game/{game_id}', '{}', true)
on conflict (key) do nothing;
