-- KAN-1054: is_benched read user_benches/benches (neither exists); posts_mapping_check read posts.sport_key (gone).
-- Rollback: supabase/rollbacks/20261127140000_kan1054_is_benched_rollback.sql
-- Callers of is_benched (2026-11-27, prosrc): rpc_squad_create (app: lib/data/repositories/squads_repository_impl.dart),
-- rpc_squad_request_join, rpc_squad_respond_invite, is_profile_publicly_visible, can_view_post(uuid,posts),
-- allow_social_visibility, allow_social_write, allow_social_notifications, can_receive_friend_requests,
-- vibes_base_candidates, fn_is_benched. No trigger, policy or cron.job references either function; no lib/ or
-- supabase/functions hit. posts_mapping_check has no caller anywhere (diagnostic).
-- Signatures, SECURITY mode (both INVOKER), search_path and grants are unchanged (CREATE OR REPLACE keeps the ACL).
BEGIN;

-- is_benched: "benched" is the self-chosen bench mode (KAN-706) stored in public.user_status, written by
-- rpc_toggle_bench / rpc_end_bench. Active while is_benched = true and bench_until is unset or in the future.
-- Still SECURITY INVOKER: an authenticated caller sees only its own user_status row (user_status_select_self), so
-- for another user it answers false unless the caller is a SECURITY DEFINER function.
CREATE OR REPLACE FUNCTION public.is_benched(p_user uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_status us
    WHERE us.user_id = p_user
      AND us.is_benched = true
      AND (us.bench_until IS NULL OR us.bench_until > now())
  );
END
$function$;

-- posts_mapping_check: posts.sport_key became posts.sport_id (uuid). Report on sport_id; the body key is still
-- counted for context. The mismatch count is no longer computable (uuid vs a sport key string) and is null.
CREATE OR REPLACE FUNCTION public.posts_mapping_check()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_sport_filled int;
  v_sport_body_present int;
  v_time_like_cols jsonb;
  v_body_time_samples jsonb;
  v_total int;
begin
  select count(*) into v_total from public.posts;

  select count(*) into v_sport_filled from public.posts where sport_id is not null;

  select count(*) into v_sport_body_present
  from public.posts
  where public.try_jsonb(body) is not null
    and jsonb_typeof(public.try_jsonb(body))='object'
    and (public.try_jsonb(body) ? 'sport_key');

  select coalesce(
           jsonb_agg(jsonb_build_object('column', c.column_name, 'type', c.data_type) order by c.ordinal_position),
           '[]'::jsonb)
  into v_time_like_cols
  from information_schema.columns c
  where c.table_schema='public' and c.table_name='posts'
    and (c.data_type like 'timestamp%' or c.data_type like 'time%' or c.column_name ilike '%time%'
         or c.column_name in ('kickoff_at','start_at','start_time','game_time'));

  select coalesce(jsonb_agg(x.val) filter (where x.val is not null), '[]'::jsonb)
  into v_body_time_samples
  from (
    select distinct (public.try_jsonb(body)->>'time') as val
    from public.posts
    where public.try_jsonb(body) is not null
      and jsonb_typeof(public.try_jsonb(body))='object'
      and (public.try_jsonb(body) ? 'time')
    limit 10
  ) x;

  return jsonb_build_object(
    'total_rows', v_total,
    'sport_id', jsonb_build_object(
      'column_exists', true,
      'filled_rows', v_sport_filled,
      'body_has_sport_key_rows', v_sport_body_present,
      'mismatches', null),
    'time_like_columns', v_time_like_cols,
    'body_time_samples', v_body_time_samples
  );
end;
$function$;

COMMIT;
