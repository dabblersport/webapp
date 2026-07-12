-- User-level follow semantics for unfollow + follow-state.
--
-- Users have multiple persona profiles (player / organiser), so a single
-- user pair can hold several profile_follows edges (up to follower profiles
-- × followed profiles). Followers-only game visibility is user-level (any
-- edge grants access), but the app's unfollow deleted only the single
-- (active profile → viewed profile) pair — leaving other edges behind, so
-- a followers-only game stayed visible after "unfollowing".
--
-- rpc_unfollow_user deletes ALL edges from any of the caller's profiles to
-- any profile of the target profile's owner. rpc_is_following_user reports
-- follow-state at the same granularity so the Follow/Following button
-- matches what visibility checks actually use.

create or replace function public.rpc_unfollow_user(p_target_profile_id uuid)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_target_user uuid;
  v_count integer;
begin
  select user_id into v_target_user
  from public.profiles where id = p_target_profile_id;
  if v_target_user is null then
    raise exception using errcode='P0001', message='profile_not_found';
  end if;

  delete from public.profile_follows pf
  using public.profiles fp, public.profiles op
  where fp.id = pf.follower_profile_id
    and op.id = pf.following_profile_id
    and fp.user_id = auth.uid()
    and op.user_id = v_target_user;

  get diagnostics v_count = row_count;
  return v_count;
end$$;

create or replace function public.rpc_is_following_user(p_target_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1
    from public.profile_follows pf
    join public.profiles fp on fp.id = pf.follower_profile_id
    join public.profiles op on op.id = pf.following_profile_id
    where fp.user_id = auth.uid()
      and op.user_id = (
        select user_id from public.profiles where id = p_target_profile_id
      )
  );
$$;
