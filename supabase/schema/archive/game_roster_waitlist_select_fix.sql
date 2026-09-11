-- Fix roster/waitlist visibility: players list only ever showed yourself.
--
-- Both game_roster and game_waitlist had SELECT policies of the form
--   user_id = auth.uid() OR EXISTS (select 1 from games where ... 'public')
-- but the EXISTS subquery runs under the caller's RLS on games — which has
-- RLS enabled with no policies — so it was ALWAYS false for app users.
-- Net effect: every viewer (including the host) could only see their own
-- roster/waitlist row. That's why an approved join request never appeared
-- in the Players list.
--
-- _can_view_game is the SECURITY DEFINER equivalent of the v_game_card
-- visibility gate (creator / admin / participant / scope pass) so the
-- roster is readable exactly by whoever can see the game itself. Being
-- SECURITY DEFINER (owner: postgres) it bypasses RLS internally, which
-- also avoids policy recursion (game_roster policy → helper → game_roster).

create or replace function public._can_view_game(p_game_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.games g
    where g.id = p_game_id
      and (
        g.creator_user_id = auth.uid()
        or public.is_admin(auth.uid())
        or exists (
             select 1 from public.game_roster gr
             where gr.game_id = g.id
               and gr.user_id = auth.uid()
               and gr.status = 'active'
           )
        or exists (
             select 1 from public.game_waitlist gw
             where gw.game_id = g.id
               and gw.user_id = auth.uid()
           )
        or public.can_view_with_scope(
             auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id
           )
      )
  );
$$;

drop policy if exists roster_select_public_or_self on public.game_roster;
create policy roster_select_visible on public.game_roster
for select using (
  user_id = auth.uid()
  or public._can_view_game(game_id)
);

drop policy if exists waitlist_select_public_or_self on public.game_waitlist;
create policy waitlist_select_visible on public.game_waitlist
for select using (
  user_id = auth.uid()
  or public._can_view_game(game_id)
);
