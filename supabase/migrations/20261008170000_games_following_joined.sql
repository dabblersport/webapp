-- Games card note "N following": rpc_games_following_joined (team Luxor).
--
-- Record of what was applied to project wtncuzcskpigqpmnxwws on 2026-10-08 with
-- execute_sql steps (no DROP, no apply_migration, and no test writes to the
-- live database):
--   1. CREATE FUNCTION (below), later REPLACED once with the same signature after
--      a read-only check found a defect (see "Defect found" below).
--   2. ALTER FUNCTION ... OWNER TO postgres; REVOKE ALL ... FROM PUBLIC, anon;
--      GRANT EXECUTE ... TO authenticated.
--
-- Meaning (CEO 2026-10-08): "N following" = the number of people the VIEWER
-- follows (one-way profile_follows, any of the viewer's profiles) who are active
-- in that game. Count only: no names, no avatars. Mutual friends come later.
--
-- Rules, all inside the function:
--   * SECURITY DEFINER, search_path pinned to 'public, pg_temp', auth.uid() only
--     (no user parameter); anon / no uid -> no rows; EXECUTE only for authenticated
--     (service_role and postgres keep theirs); one overload.
--   * Visibility is re-checked per game with public._can_view_game(game_id), and
--     cancelled games are dropped, so the RPC is not an oracle for hidden games.
--   * Roster: status = 'active', role in (host, player, sub); spectators and
--     waitlist are not counted; the viewer is excluded.
--   * Blocks: the viewer's blocked set (either direction) is computed once in a CTE.
--   * Privacy: users whose privacy_settings.show_game_history = false are excluded.
--   * Input is capped at the first 200 ids.
--
-- Defect found by a read-only check against real data and fixed (CREATE OR REPLACE):
-- a viewer with two profiles who followed the same person from both profiles was
-- counted twice (14 counted vs 7 expected). Followed profiles are now DISTINCT and
-- the count is count(distinct user_id).
-- After the fix, the live RPC matches an independent recount for a real viewer:
-- 7 games, total 7, 0 games differ.

CREATE OR REPLACE FUNCTION public.rpc_games_following_joined(p_game_ids uuid[])
RETURNS TABLE(game_id uuid, following_count integer)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  with me as (
    select auth.uid() as uid
  ),
  my_following as (
    select distinct pf.following_profile_id as profile_id
    from public.profile_follows pf
    join public.profiles p on p.id = pf.follower_profile_id
    where p.user_id = (select uid from me)
  ),
  blocked as (
    select case when ub.blocker_user_id = (select uid from me)
                then ub.blocked_user_id else ub.blocker_user_id end as other_user_id
    from public.user_blocks ub
    where ub.blocker_user_id = (select uid from me)
       or ub.blocked_user_id = (select uid from me)
  ),
  visible as (
    select g.id
    from public.games g
    where (select uid from me) is not null
      and g.id = any (p_game_ids[1:200])
      and g.is_cancelled = false
      and public._can_view_game(g.id)
  )
  select gr.game_id, count(distinct gr.user_id)::int as following_count
  from public.game_roster gr
  join visible v on v.id = gr.game_id
  join my_following mf on mf.profile_id = gr.profile_id
  where gr.status = 'active'
    and gr.role in ('host', 'player', 'sub')
    and gr.user_id <> (select uid from me)
    and not exists (select 1 from blocked b where b.other_user_id = gr.user_id)
    and not exists (select 1 from public.privacy_settings ps
                    where ps.user_id = gr.user_id and ps.show_game_history = false)
  group by gr.game_id;
$function$;

ALTER FUNCTION public.rpc_games_following_joined(uuid[]) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_games_following_joined(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_games_following_joined(uuid[]) TO authenticated;
