-- game_join_requests was write-only for clients: RLS enabled with INSERT
-- (requester) and UPDATE (requester cancel) policies but NO SELECT policy.
-- The host had no way to list pending requests (and the requester's own
-- "pending request" check silently returned nothing).
--
-- _is_game_host must be SECURITY DEFINER: policies run with the caller's
-- rights and public.games is RLS-locked with no policies, so an inline
-- EXISTS against games (or the invoker-rights _user_hosted_game helper)
-- would always be false for regular users.

create or replace function public._is_game_host(p_game_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.games g
    where g.id = p_game_id
      and g.creator_user_id = auth.uid()
  );
$$;

drop policy if exists joinreq_select_requester_or_host on public.game_join_requests;
create policy joinreq_select_requester_or_host on public.game_join_requests
for select using (
  from_user_id = auth.uid()
  or public._is_game_host(game_id)
  or public.is_admin(auth.uid())
);
