-- Rollback for KAN-1054 (20261127140000_kan1054_is_benched.sql).
-- Bodies are pg_get_functiondef output captured 2026-11-27 before the migration. CREATE OR REPLACE keeps the ACL;
-- the captured ACL is noted per function and was {=X,postgres=X,anon=X,authenticated=X,service_role=X} for both.
BEGIN;
SET LOCAL check_function_bodies = off;

-- is_benched(uuid)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.is_benched(p_user uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE res boolean := false;
BEGIN
  IF to_regclass('public.user_benches') IS NOT NULL THEN
    BEGIN
      SELECT EXISTS(SELECT 1 FROM public.user_benches WHERE user_id = p_user AND (COALESCE(is_active, true) = true OR COALESCE(until, now()) > now())) INTO res;
    EXCEPTION WHEN undefined_column THEN
      SELECT EXISTS(SELECT 1 FROM public.user_benches WHERE user_id = p_user AND COALESCE(until, now()) > now()) INTO res;
    END;
    RETURN COALESCE(res, false);
  END IF;
  IF to_regclass('public.benches') IS NOT NULL THEN
    BEGIN
      SELECT EXISTS(SELECT 1 FROM public.benches WHERE user_id = p_user AND (COALESCE(is_active, true) = true OR COALESCE(until, now()) > now())) INTO res;
      RETURN COALESCE(res, false);
    EXCEPTION WHEN undefined_column THEN RETURN false;
    END;
  END IF;
  RETURN false;
END
$function$;

-- posts_mapping_check()  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.posts_mapping_check()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_has_sport boolean;
  v_sport_filled int := null;
  v_sport_body_present int := null;
  v_sport_mismatches int := null;
  v_time_like_cols jsonb;
  v_body_time_samples jsonb;
  v_total int;
begin
  -- total rows (for context)
  select count(*) into v_total from public.posts;

  -- sport_key summary (only if column exists)
  select exists(
           select 1
           from information_schema.columns
           where table_schema='public' and table_name='posts' and column_name='sport_key'
         )
  into v_has_sport;

  if v_has_sport then
    execute $q$ select count(*) from public.posts where sport_key is not null $q$
      into v_sport_filled;

    execute $q$
      select count(*)
      from public.posts
      where public.try_jsonb(body) is not null
        and jsonb_typeof(public.try_jsonb(body))='object'
        and (public.try_jsonb(body) ? 'sport_key')
    $q$
      into v_sport_body_present;

    execute $q$
      select count(*)
      from public.posts
      where sport_key is not null
        and public.try_jsonb(body) is not null
        and jsonb_typeof(public.try_jsonb(body))='object'
        and (public.try_jsonb(body) ? 'sport_key')
        and sport_key::text is distinct from (public.try_jsonb(body)->>'sport_key')
    $q$
      into v_sport_mismatches;
  end if;

  -- enumerate "time-like" columns on posts (by type or name)
  select coalesce(
           jsonb_agg(
             jsonb_build_object('column', c.column_name, 'type', c.data_type)
             order by c.ordinal_position
           ),
           '[]'::jsonb
         )
  into v_time_like_cols
  from information_schema.columns c
  where c.table_schema='public' and c.table_name='posts'
    and (
      c.data_type like 'timestamp%' or
      c.data_type like 'time%' or
      c.column_name ilike '%time%' or
      c.column_name in ('kickoff_at','start_at','start_time','game_time')
    );

  -- sample of body->>'time' values to help choose target column
  select coalesce(
           jsonb_agg(x.val) filter (where x.val is not null),
           '[]'::jsonb
         )
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
    'sport_key', case when v_has_sport then
                  jsonb_build_object(
                    'column_exists', true,
                    'filled_rows', v_sport_filled,
                    'body_has_key_rows', v_sport_body_present,
                    'mismatches', v_sport_mismatches
                  )
                else
                  jsonb_build_object('column_exists', false)
                end,
    'time_like_columns', v_time_like_cols,
    'body_time_samples', v_body_time_samples
  );
end;
$function$;

COMMIT;
