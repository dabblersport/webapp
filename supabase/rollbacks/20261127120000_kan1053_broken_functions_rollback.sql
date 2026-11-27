-- Rollback for KAN-1053 (20261127120000_kan1053_broken_functions.sql).
-- Every body below is pg_get_functiondef output captured 2026-11-27 before the migration. Replaced functions keep
-- their ACL through CREATE OR REPLACE; dropped ones are recreated and their captured ACL is re-applied.
-- Triggers trg_payment_to_ledger and trg_set_venue_space_sport_id were never dropped, so need no recreation.
BEGIN;
SET LOCAL check_function_bodies = off;

-- _get_skill_level(uuid,text)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public._get_skill_level(u uuid, sport text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare lvl int;
begin
  if to_regclass('public.sport_profiles') is null then
    return null;
  end if;

  select spm.skill_level
    into lvl
  from public.sport_profiles spm
  where spm.user_id = u
    and spm.sport = sport
  limit 1;

  return lvl;
end;
$function$;

-- _post_vibes_json(uuid)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public._post_vibes_json(p_post_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  has_vibes boolean := (to_regclass('public.vibes') is not null);
  has_pv    boolean := (to_regclass('public.post_vibes') is not null);
  j jsonb := '[]'::jsonb;
begin
  if has_vibes and has_pv then
    select coalesce(
             (select jsonb_agg(v.key order by v.sort_order)
              from public.post_vibes pv
              join public.vibes v on v.id = pv.vibe_id
              where pv.post_id = p_post_id),
             '[]'::jsonb
           )
    into j;
  end if;
  return j;
end
$function$;
REVOKE ALL ON FUNCTION public._post_vibes_json(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._post_vibes_json(uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public._post_vibes_json(uuid) TO postgres;
GRANT EXECUTE ON FUNCTION public._post_vibes_json(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._post_vibes_json(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._post_vibes_json(uuid) TO service_role;

-- _skill_level(uuid,text)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public._skill_level(u uuid, sport text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare lvl int;
begin
  if to_regclass('public.sport_profiles') is null then
    return null;
  end if;

  select sp.skill_level
    into lvl
  from public.sport_profiles sp
  where sp.user_id = u
    and sp.sport = sport
  limit 1;

  return lvl;
end;
$function$;

-- _vibes_momentum_nudge(uuid)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public._vibes_momentum_nudge(p_post_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  has_vibes   boolean := (to_regclass('public.vibes') is not null);
  has_theme   boolean := exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='vibes' and column_name='theme'
  );
  has_urgency boolean := exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='vibes' and column_name='urgency_level'
  );
  n numeric := 0.0;
begin
  if has_vibes and has_theme and has_urgency then
    if exists (
      select 1
      from public.post_vibes pv
      join public.vibes v on v.id = pv.vibe_id
      where pv.post_id = p_post_id
        and v.theme = 'momentum'
        and v.urgency_level > 0
    ) then
      n := 1.0;
    end if;
  end if;
  return n;
end
$function$;
REVOKE ALL ON FUNCTION public._vibes_momentum_nudge(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._vibes_momentum_nudge(uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public._vibes_momentum_nudge(uuid) TO postgres;
GRANT EXECUTE ON FUNCTION public._vibes_momentum_nudge(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public._vibes_momentum_nudge(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._vibes_momentum_nudge(uuid) TO service_role;

-- admin_fill_posts_sport_key()  ACL {postgres=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.admin_fill_posts_sport_key()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
declare
  v_count  int  := 0;
  v_sample jsonb := '[]'::jsonb;
begin
  with c as (
    select
      id,
      replace(
        lower( (regexp_match(body, '(?i)(Padel Doubles|Indoor Cricket|Football|Cricket|Padel)'))[1] ),
        ' ',
        '_'
      ) as sk
    from public.posts
    where sport_key is null
      and body is not null
      and body ~* '(Padel Doubles|Indoor Cricket|Football|Cricket|Padel)'
  ),
  u as (
    update public.posts p
       set sport_key = c.sk
    from c
    where p.id = c.id
      and c.sk is not null
      and c.sk <> ''
    returning p.id, left(p.body, 80) as body_prefix, p.sport_key
  )
  select
    coalesce((select count(*) from u), 0),
    coalesce((
      select jsonb_agg(jsonb_build_object('id', id, 'body_prefix', body_prefix, 'sport_key', sport_key))
      from (select * from u limit 12) s
    ), '[]'::jsonb)
  into v_count, v_sample;

  return jsonb_build_object('rows_updated', v_count, 'sample', v_sample);
end;
$function$;

-- admin_force_delete_auth_user(text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.admin_force_delete_auth_user(p_user_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_user_uuid UUID;
  v_deleted_sessions INTEGER := 0;
  v_deleted_identities INTEGER := 0;
  v_deleted_mfa_factors INTEGER := 0;
  v_deleted_refresh_tokens INTEGER := 0;
  v_deleted_user BOOLEAN := FALSE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin privileges required';
  END IF;

  -- Validate input and convert to UUID
  IF p_user_id IS NULL OR p_user_id = '' THEN
    RAISE EXCEPTION 'User ID cannot be null or empty';
  END IF;

  -- Cast to UUID to ensure type safety
  BEGIN
    v_user_uuid := p_user_id::UUID;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Invalid UUID format: %', p_user_id;
  END;

  -- Delete from auth.sessions
  EXECUTE format('DELETE FROM auth.sessions WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_sessions = ROW_COUNT;

  -- Delete from auth.identities
  EXECUTE format('DELETE FROM auth.identities WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_identities = ROW_COUNT;

  -- Delete from auth.mfa_factors
  EXECUTE format('DELETE FROM auth.mfa_factors WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_mfa_factors = ROW_COUNT;

  -- Delete from auth.refresh_tokens
  EXECUTE format('DELETE FROM auth.refresh_tokens WHERE user_id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_refresh_tokens = ROW_COUNT;

  -- Delete from auth.mfa_amr_claims if exists
  BEGIN
    EXECUTE format('DELETE FROM auth.mfa_amr_claims WHERE session_id IN (SELECT id FROM auth.sessions WHERE user_id::text = %L)', v_user_uuid::text);
  EXCEPTION
    WHEN undefined_table THEN NULL; -- Table might not exist
  END;

  -- Delete from auth.mfa_challenges if exists
  BEGIN
    EXECUTE format('DELETE FROM auth.mfa_challenges WHERE factor_id IN (SELECT id FROM auth.mfa_factors WHERE user_id::text = %L)', v_user_uuid::text);
  EXCEPTION
    WHEN undefined_table THEN NULL; -- Table might not exist
  END;

  -- Finally, delete the user from auth.users
  EXECUTE format('DELETE FROM auth.users WHERE id::text = %L', v_user_uuid::text);
  GET DIAGNOSTICS v_deleted_user = ROW_COUNT;

  IF v_deleted_user = 0 THEN
    RAISE EXCEPTION 'User not found in auth.users: %', p_user_id;
  END IF;

  -- Return summary
  RETURN jsonb_build_object(
    'success', TRUE,
    'user_id', v_user_uuid,
    'deleted', jsonb_build_object(
      'sessions', v_deleted_sessions,
      'identities', v_deleted_identities,
      'mfa_factors', v_deleted_mfa_factors,
      'refresh_tokens', v_deleted_refresh_tokens,
      'user', TRUE
    )
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error deleting auth user: %', SQLERRM;
END;
$function$;

-- award_top_host_weekly(text,jsonb)  ACL {postgres=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.award_top_host_weekly(p_badge_key text, p_params jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  top_n      int  := public._param_int(p_params,'top_n',10);
  min_hosted int  := public._param_int(p_params,'min_hosted',2);
  orderby    text := lower(public._param_txt(p_params,'orderby','fill_rate')); -- or 'games_hosted'
  target_isoy int := extract(isoyear from now())::int;
  target_isow int := extract(week    from now())::int;
  n int := 0;
  rec record;
  win_tag text := format('%s-W%02s', target_isoy, target_isow);
begin
  for rec in
    select user_id, games_hosted, fill_rate
    from public.v_host_weekly_metrics
    where isoy = target_isoy and isow = target_isow and games_hosted >= min_hosted
    order by case when orderby='games_hosted' then games_hosted end desc nulls last,
             case when orderby='fill_rate'   then fill_rate   end desc nulls last
    limit greatest(1, top_n)
  loop
    insert into public.user_badges(user_id, badge_key, reason, context)
    values (
      rec.user_id, p_badge_key,
      format('Week %s: hosted %s game(s), fill %.0f%%', win_tag, rec.games_hosted, 100*coalesce(rec.fill_rate,0)),
      jsonb_build_object('window', win_tag, 'games_hosted', rec.games_hosted, 'fill_rate', rec.fill_rate)
    )
    on conflict do nothing;
    n := n + 1;
  end loop;
  return n;
end;
$function$;

-- award_venue_dim_top(text,jsonb)  ACL {postgres=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.award_venue_dim_top(p_badge_key text, p_params jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  dim         text := public._param_txt(p_params,'dimension','lighting');
  v_district  text := public._param_txt(p_params,'district','Al Quoz');  -- renamed to avoid clash
  top_n       int  := public._param_int(p_params,'top_n',3);
  min_count   int  := public._param_int(p_params,'min_count',10);
  n           int := 0;
  rec         record;
  win_tag     text := to_char(current_date, 'YYYY-MM'); -- monthly cycle by default
begin
  for rec in
    select vdbd.venue_id, vdbd.avg_score, vdbd.ratings_count
    from public.v_venue_dimension_by_district vdbd
    where vdbd.dimension_key = dim
      and vdbd.district = v_district
      and vdbd.ratings_count >= min_count
    order by vdbd.avg_score desc, vdbd.ratings_count desc
    limit greatest(1, top_n)
  loop
    insert into public.user_badges(user_id,badge_key,reason,context)
    select vm.user_id, p_badge_key,
           format('%s in %s (avg %.2f, %s ratings)', initcap(dim), v_district, rec.avg_score, rec.ratings_count),
           jsonb_build_object('window', win_tag, 'venue_id', rec.venue_id, 'dimension', dim,
                              'district', v_district, 'avg', rec.avg_score, 'count', rec.ratings_count)
    from public.venue_members vm
    where vm.venue_id = rec.venue_id and vm.role in ('owner','manager')
    on conflict do nothing;

    get diagnostics n = row_count;
  end loop;

  return coalesce(n,0);
end;
$function$;

-- compute_challenge_fingerprint(jsonb)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.compute_challenge_fingerprint(p_payload jsonb)
 RETURNS TABLE(hash text, fields jsonb)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  sport text;
  kind text;                 -- 'round_robin'|'knockout'|'ladder'|'league'|...
  squads int;                -- number of squads
  rounds_per_week int;
  default_slot text;         -- preferred slot for fixtures (optional)
  f jsonb;
begin
  sport := lower(coalesce(p_payload->>'sport',''));
  kind  := lower(coalesce(p_payload->>'challenge_type',''));
  squads := coalesce((p_payload->>'squads')::int, 0);
  rounds_per_week := coalesce((p_payload->>'rounds_per_week')::int, 0);
  default_slot := coalesce(p_payload->>'default_slot', null);

  f := jsonb_build_object(
    'sport', sport,
    'challenge_type', kind,
    'squads', squads,
    'rounds_per_week', rounds_per_week,
    'default_slot', default_slot
  );

  hash := encode(digest(f::text,'sha256'),'hex');
  fields := f;
  return next;
end;
$function$;

-- compute_game_fingerprint(jsonb)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.compute_game_fingerprint(p_payload jsonb)
 RETURNS TABLE(hash text, fields jsonb)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  sport text; venue_space uuid; start_at timestamptz; end_at timestamptz;
  capacity int; listing text; joinp text; dur int; slot text; f jsonb;
BEGIN
  sport := lower(COALESCE(p_payload->>'sport', ''));
  venue_space := nullif(p_payload->>'venue_space_id', '')::uuid;
  start_at := (p_payload->>'start_at')::timestamptz;
  end_at := (p_payload->>'end_at')::timestamptz;
  capacity := COALESCE((p_payload->>'capacity')::int, 0);
  listing := COALESCE(p_payload->>'listing_visibility', 'public');
  joinp := COALESCE(p_payload->>'join_policy', 'request');
  dur := GREATEST(30, COALESCE(((extract(epoch from (end_at - start_at)) / 60)::int), 60));
  slot := public._slot_key(start_at, 30);
  f := jsonb_build_object(
    'sport', sport, 'venue_space_id', venue_space,
    'weekday', extract(dow from start_at)::int,
    'slot', slot, 'duration_mins', dur, 'capacity', capacity,
    'listing_visibility', listing, 'join_policy', joinp);
  hash := encode(digest(COALESCE(f::text, ''), 'sha256'), 'hex');
  fields := f;
  RETURN NEXT;
END;
$function$;

-- compute_meetup_fingerprint(jsonb)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.compute_meetup_fingerprint(p_payload jsonb)
 RETURNS TABLE(hash text, fields jsonb)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  cat text; venue_space uuid; start_at timestamptz; end_at timestamptz;
  dur int; slot text; listing text; f jsonb;
BEGIN
  cat := 'social';
  venue_space := nullif(p_payload->>'venue_space_id', '')::uuid;
  start_at := (p_payload->>'start_at')::timestamptz;
  end_at := (p_payload->>'end_at')::timestamptz;
  dur := GREATEST(30, COALESCE(((extract(epoch from (end_at - start_at)) / 60)::int), 60));
  slot := public._slot_key(start_at, 30);
  listing := COALESCE(p_payload->>'listing_visibility', 'public');
  f := jsonb_build_object(
    'category', cat, 'venue_space_id', venue_space,
    'weekday', extract(dow from start_at)::int,
    'slot', slot, 'duration_mins', dur,
    'listing_visibility', listing);
  hash := encode(digest(f::text, 'sha256'), 'hex');
  fields := f;
  RETURN NEXT;
END;
$function$;

-- generate_slot_grid_range(date,date,integer,text,text)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.generate_slot_grid_range(p_from date, p_to date, p_granularity_minutes integer DEFAULT 60, p_sport text DEFAULT NULL::text, p_city text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  rec record;           -- <- record variable
  d   date;
  total int := 0;
begin
  if p_to < p_from then
    raise exception using errcode='P0001', message='invalid_date_range';
  end if;

  for rec in
    select sp.id as space_id
    from public.venue_spaces sp
    join public.venues v on v.id = sp.venue_id
    where sp.is_active = true
      and v.is_active = true
      and (p_sport is null or sp.sport = p_sport)
      and (p_city  is null or v.city  = p_city)
  loop
    d := p_from;
    while d <= p_to loop
      total := total + public.generate_space_slot_grid(rec.space_id, d, p_granularity_minutes);
      d := d + 1;
    end loop;
  end loop;

  return total;
end;
$function$;

-- generate_space_slot_grid(uuid,date,integer)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.generate_space_slot_grid(p_space_id uuid, p_date date, p_granularity_minutes integer DEFAULT 60)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  tz text;
  wd int;
  open_t time; close_t time; open_flag boolean;
  day_start timestamptz; day_end timestamptz;
  cur timestamptz; nxt timestamptz;
  inserted int := 0;
begin
  if p_granularity_minutes not in (30,45,60,90,120) then
    raise exception using errcode='P0001', message='invalid_granularity';
  end if;

  select v.timezone into tz
  from public.venue_spaces s join public.venues v on v.id = s.venue_id
  where s.id = p_space_id;
  if tz is null then tz := 'Asia/Dubai'; end if;

  day_start := (p_date::timestamptz at time zone tz);
  day_end   := ((p_date + 1)::timestamptz at time zone tz);
  wd := extract(dow from day_start at time zone tz);

  select open_time, close_time, is_open
    into open_t, close_t, open_flag
  from public.opening_hours
  where venue_space_id = p_space_id and weekday = wd;

  delete from public.space_slot_grid
   where venue_space_id = p_space_id
     and slot_date = p_date
     and granularity_minutes = p_granularity_minutes
     and version = 1;

  if open_flag is distinct from true or open_t is null or close_t is null or close_t <= open_t then
    return 0;
  end if;

  cur := (date_trunc('day', day_start at time zone tz) + open_t) at time zone tz;
  nxt := cur + make_interval(mins => p_granularity_minutes);

  while nxt <= (date_trunc('day', day_start at time zone tz) + close_t) at time zone tz loop
    insert into public.space_slot_grid(
      venue_space_id, slot_date, slot_start, slot_end,
      granularity_minutes, base_price_aed, version
    )
    values (
      p_space_id, p_date, cur, nxt,
      p_granularity_minutes,
      public._compute_slot_price_for_window(p_space_id, cur, nxt),
      1
    )
    on conflict do nothing;

    inserted := inserted + 1;
    cur := nxt;
    nxt := cur + make_interval(mins => p_granularity_minutes);
  end loop;

  return inserted;
end;
$function$;

-- list_challenge_statuses()  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.list_challenge_statuses()
 RETURNS SETOF text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  t_oid   oid;
  atttyp  oid;
  def     text;
  vals    text[] := '{}';
begin
  select 'public.challenges'::regclass::oid into t_oid;
  select a.atttypid
  into atttyp
  from pg_attribute a
  where a.attrelid = t_oid and a.attname = 'status' and a.attnum > 0 and not a.attisdropped;

  -- If ENUM: return enum labels
  if atttyp::regtype::text !~* 'text' then
    return query
    select e.enumlabel
    from pg_enum e
    where e.enumtypid = atttyp
    order by e.enumsortorder;
    return;
  end if;

  -- Else parse CHECK constraints that mention status
  for def in
    select pg_get_constraintdef(c.oid)
    from pg_constraint c
    where c.conrelid = t_oid
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%status%'
  loop
    vals := vals || (
      select array_agg(m[1])
      from regexp_matches(def, '''([^'']+)''(?:::?[a-zA-Z0-9_.]+)?', 'g') m
    );
  end loop;

  if vals is not null and array_length(vals,1) is not null then
    return query select distinct v from unnest(vals) v;
  end if;

  return;
end;
$function$;

-- quote_space_slot_price(uuid,timestamp with time zone,timestamp with time zone)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.quote_space_slot_price(p_space_id uuid, p_start_utc timestamp with time zone, p_end_utc timestamp with time zone)
 RETURNS TABLE(venue_space_id uuid, venue_id uuid, venue_tz text, local_date date, local_weekday integer, local_start timestamp without time zone, local_end timestamp without time zone, minutes integer, is_open boolean, is_blackout boolean, hourly_aed numeric, price_aed numeric, reason text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_tz   text;
  v_vid  uuid;
  v_ls   timestamp;  -- local start (no tz)
  v_le   timestamp;  -- local end (no tz)
  v_wd   int;        -- 0..6
  v_open time;
  v_close time;
  v_rate numeric(10,2);
  v_minutes int;
  v_reason text := null;
  v_is_open boolean := false;
  v_is_blackout boolean := false;
begin
  if p_end_utc <= p_start_utc then
    venue_space_id := p_space_id;
    reason := 'end <= start';
    return next; return;
  end if;

  -- ✅ fixed alias here: s.venue_id (not v.venue_id)
  select s.venue_id, ven.timezone
  into v_vid, v_tz
  from public.venue_spaces s
  join public.venues ven on ven.id = s.venue_id
  where s.id = p_space_id;

  if v_tz is null then
    venue_space_id := p_space_id;
    reason := 'space_or_venue_not_found';
    return next; return;
  end if;

  v_ls := (p_start_utc at time zone v_tz);
  v_le := (p_end_utc   at time zone v_tz);

  if v_ls::date <> v_le::date then
    venue_space_id := p_space_id; venue_id := v_vid; venue_tz := v_tz;
    local_date := v_ls::date; local_weekday := extract(dow from v_ls)::int;
    local_start := v_ls; local_end := v_le; minutes := extract(epoch from (p_end_utc - p_start_utc))::int / 60;
    reason := 'slot_crosses_midnight_local';
    return next; return;
  end if;

  v_wd := extract(dow from v_ls)::int;

  select oh.open_time, oh.close_time
  into v_open, v_close
  from public.opening_hours oh
  where oh.venue_space_id = p_space_id and oh.weekday = v_wd;

  if v_open is null then
    venue_space_id := p_space_id; venue_id := v_vid; venue_tz := v_tz;
    local_date := v_ls::date; local_weekday := v_wd; local_start := v_ls; local_end := v_le;
    minutes := extract(epoch from (p_end_utc - p_start_utc))::int / 60;
    reason := 'no_opening_hours_for_weekday';
    return next; return;
  end if;

  v_is_open := (v_ls::time >= v_open) and (v_le::time <= v_close);

  select exists (
    select 1
    from public.blackouts b
    where b.venue_space_id = p_space_id
      and b.starts_at < p_end_utc
      and b.ends_at   > p_start_utc
  ) into v_is_blackout;

  select sp.price_per_hour_aed
  into v_rate
  from public.space_prices sp
  where sp.venue_space_id = p_space_id
    and sp.weekday = v_wd
    and sp.is_active = true
    and sp.start_time <= v_ls::time
    and sp.end_time   >= v_le::time
  order by sp.start_time asc
  limit 1;

  v_minutes := (extract(epoch from (p_end_utc - p_start_utc)) / 60)::int;

  if not v_is_open then
    v_reason := 'outside_opening_hours';
  elsif v_is_blackout then
    v_reason := 'blackout';
  elsif v_rate is null then
    v_reason := 'no_price_rule_covers_slot';
  end if;

  venue_space_id := p_space_id;
  venue_id := v_vid;
  venue_tz := v_tz;
  local_date := v_ls::date;
  local_weekday := v_wd;
  local_start := v_ls;
  local_end := v_le;
  minutes := v_minutes;
  is_open := v_is_open;
  is_blackout := v_is_blackout;
  hourly_aed := v_rate;
  price_aed := case when v_rate is not null and v_is_open and not v_is_blackout
                    then round((v_minutes::numeric / 60.0) * v_rate, 2)
                    else null end;
  reason := v_reason;

  return next;
end
$function$;

-- render_notification(text,uuid,jsonb)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.render_notification(p_type_key text, p_user uuid, p_context jsonb)
 RETURNS TABLE(title text, body text, action_route text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  loc text := coalesce((select locale from public.user_settings where user_id=p_user),'en');
  tt text; bt text; aroute text;
begin
  select title_template, body_template, action_route
  into tt, bt, aroute
  from public.notification_templates
  where key = p_type_key and locale = loc
  order by version desc
  limit 1;

  if tt is null then
    -- Fallback EN
    select title_template, body_template, action_route
    into tt, bt, aroute
    from public.notification_templates
    where key = p_type_key and locale = 'en'
    order by version desc
    limit 1;
  end if;

  -- VERY basic rendering: replace {{key}} with context->>key
  -- For anything complex, do it in the edge worker.
  title := coalesce(tt,'Notification');
  body  := coalesce(bt,'You have an update');
  action_route := coalesce(aroute,'/inbox');

  -- Replace {{..}} tokens present in title/body/route
  -- token list from keys in p_context
  perform 1; -- no-op

  -- simple replace loop in SQL:
  declare k text; v text;
  begin
    for k, v in
      select key, value from json_each_text(coalesce(p_context,'{}'::jsonb))
    loop
      title := replace(title, '{{'||k||'}}', v);
      body  := replace(body,  '{{'||k||'}}', v);
      action_route := replace(action_route, '{{'||k||'}}', v);
    end loop;
  end;

  return next;
end;
$function$;

-- respond_vibe_request(uuid,text)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.respond_vibe_request(p_other_user uuid, p_action text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  a uuid; b uuid; e friend_edges%rowtype;
begin
  if me is null then raise exception using errcode='P0001', message='auth_required'; end if;
  if p_action not in ('accept','reject') then
    raise exception using errcode='P0001', message='invalid_action';
  end if;

  select a,b into a,b from public._pair(me, p_other_user);
  select * into e from public.friend_edges
   where least(user_a,user_b)=a and greatest(user_a,user_b)=b;

  if e.id is null or e.status <> 'pending' then
    raise exception using errcode='P0001', message='no_pending_request';
  end if;

  -- Only the non-requester can respond
  if e.requested_by = me then
    raise exception using errcode='P0001', message='requester_cannot_respond';
  end if;

  if p_action = 'accept' then
    update public.friend_edges
      set status='accepted', responded_by=me, updated_at=now()
    where id=e.id;
    insert into public.friend_requests_audit(from_user,to_user,action,edge_id)
    values (e.requested_by, me, 'accepted', e.id);
    -- TODO: notification friend.accepted
    return 'synced';
  else
    update public.friend_edges
      set status='rejected', responded_by=me, updated_at=now()
    where id=e.id;
    insert into public.friend_requests_audit(from_user,to_user,action,edge_id)
    values (e.requested_by, me, 'rejected', e.id);
    -- TODO: notification friend.rejected
    return 'vibe_missed';
  end if;
end;
$function$;
REVOKE ALL ON FUNCTION public.respond_vibe_request(uuid,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.respond_vibe_request(uuid,text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_vibe_request(uuid,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.respond_vibe_request(uuid,text) TO anon;
GRANT EXECUTE ON FUNCTION public.respond_vibe_request(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_vibe_request(uuid,text) TO service_role;

-- rpc_admin_approve_venue_submission(uuid)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_admin_approve_venue_submission(p_submission_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
DECLARE
  v_submission public.venue_submissions%rowtype;
  v_admin_user_id uuid;
  v_venue_id uuid;
BEGIN
  -- 1️⃣ Resolve admin identity from JWT
  v_admin_user_id :=
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid;

  IF v_admin_user_id IS NULL THEN
    RAISE EXCEPTION 'Missing auth context';
  END IF;

  IF NOT public.is_admin(v_admin_user_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- 2️⃣ Lock submission
  SELECT *
  INTO v_submission
  FROM public.venue_submissions
  WHERE id = p_submission_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Submission not found';
  END IF;

  IF v_submission.status <> 'pending' THEN
    RAISE EXCEPTION
      'Submission is not pending (current: %)',
      v_submission.status;
  END IF;

  -- 3️⃣ Create venue
  INSERT INTO public.venues (
    owner_user_id,
    name_en,
    name_ar,
    description_en,
    description_ar,
    city,
    district,
    area,
    address_line1,
    lat,
    lng,
    phone,
    website,
    instagram,
    amenities,
    is_indoor,
    surface_type,
    is_active,
    is_verified
  )
  VALUES (
    v_submission.submitted_by_user_id,
    v_submission.name_en,
    v_submission.name_ar,
    v_submission.description_en,
    v_submission.description_ar,
    COALESCE(v_submission.city, 'Dubai'),
    v_submission.district,
    v_submission.area,
    v_submission.address_line1,
    v_submission.lat,
    v_submission.lng,
    v_submission.phone,
    v_submission.website,
    v_submission.instagram,
    COALESCE(v_submission.amenities, '{}'::text[]),
    v_submission.is_indoor,
    v_submission.surface_type,
    true,
    false
  )
  RETURNING id INTO v_venue_id;

  -- 4️⃣ COPY SPORTS (submission → venue)
  INSERT INTO public.venue_sports (venue_id, sport_id)
  SELECT
    v_venue_id,
    vss.sport_id
  FROM public.venue_submission_sports vss
  WHERE vss.venue_submission_id = p_submission_id
  ON CONFLICT DO NOTHING;

  -- 5️⃣ Finalize submission
  UPDATE public.venue_submissions
  SET
    status = 'approved',
    approved_venue_id = v_venue_id,
    approved_at = now(),
    approved_by = v_admin_user_id,
    reviewed_at = now(),
    reviewed_by = v_admin_user_id,
    updated_at = now()
  WHERE id = p_submission_id;

  RETURN v_venue_id;
END;
$function$;

-- rpc_admin_freeze_user(uuid,text,integer,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_admin_freeze_user(p_user_id uuid, p_scope text DEFAULT 'all'::text, p_days integer DEFAULT NULL::integer, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare until_ts timestamptz; rid uuid;
begin
  if not public.is_admin(auth.uid()) then raise exception using errcode='P0001', message='admin_only'; end if;
  until_ts := case when p_days is null then null else now() + (p_days||' days')::interval end;
  insert into public.user_freezes(user_id,scope,reason,created_by,until,is_active)
  values (p_user_id, p_scope, left(coalesce(p_reason,'admin freeze'),280), auth.uid(), until_ts, true)
  returning id into rid;
  return rid;
end; $function$;

-- rpc_admin_hide_post(uuid,boolean,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_admin_hide_post(p_post_id uuid, p_hide boolean, p_notes text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin(auth.uid()) then raise exception using errcode='P0001', message='admin_only'; end if;
  update public.posts set is_hidden_admin = coalesce(p_hide,true) where id=p_post_id;
  insert into public.moderation_actions(target_kind,target_id,action,actor_user_id,notes)
  values ('post', p_post_id, case when p_hide then 'hide' else 'unhide' end, auth.uid(), left(p_notes,280));
  return case when p_hide then 'hidden' else 'unhidden' end;
end;
$function$;

-- rpc_admin_unfreeze_user(uuid)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_admin_unfreeze_user(p_freeze_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin(auth.uid()) then raise exception using errcode='P0001', message='admin_only'; end if;
  update public.user_freezes set is_active=false where id=p_freeze_id;
  if not found then return 'not_found'; end if;
  return 'unfrozen';
end; $function$;

-- rpc_autocomplete_people(text,text[],text,integer)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_autocomplete_people(p_prefix text, p_roles text[] DEFAULT ARRAY['player'::text, 'organiser'::text], p_sport text DEFAULT NULL::text, p_limit integer DEFAULT 10)
 RETURNS TABLE(profile_id uuid, profile_type text, username text, display_name text, sport_key text, avatar_url text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me   uuid := auth.uid();
  pref text := public._norm_prefix(p_prefix);
  take int  := greatest(1, coalesce(p_limit,10));
begin
  -- Require auth
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  -- Minimum prefix length
  if pref is null or length(pref) < 2 then
    return;
  end if;

  -- Fast prefix scan via text_pattern_ops
  return query
  with prefix_hits as (
    select
      pr.id,
      pr.profile_type,
      pr.username,
      pr.display_name,
      pr.sport_key,
      pr.avatar_url
    from public.profiles pr
    where (p_roles is null or pr.profile_type = any(p_roles))
      and (p_sport is null or pr.profile_type='organiser' or pr.sport_key = p_sport)
      and (
        lower(unaccent_immutable(pr.username))     like pref || '%' or
        lower(unaccent_immutable(pr.display_name)) like pref || '%'
      )
      and public.can_view_profile(me, pr.id)
    order by
      (lower(unaccent_immutable(pr.username)) like pref || '%') desc,
      pr.created_at desc
    limit take
  )
  select * from prefix_hits;

  -- If prefix results < limit/2, do fuzzy tail
  if (select count(*) from (
        select 1
        from public.profiles pr
        where (p_roles is null or pr.profile_type = any(p_roles))
          and (p_sport is null or pr.profile_type='organiser' or pr.sport_key = p_sport)
          and public.can_view_profile(me, pr.id)
          and (
            similarity(lower(pr.username), pref) > 0.4 or
            similarity(lower(pr.display_name), pref) > 0.4
          )
      ) x) > 0 then

    return query
    with fuzzy as (
      select
        pr.id,
        pr.profile_type,
        pr.username,
        pr.display_name,
        pr.sport_key,
        pr.avatar_url,
        greatest(
          similarity(lower(pr.username), pref),
          similarity(lower(pr.display_name), pref)
        ) as sim
      from public.profiles pr
      where (p_roles is null or pr.profile_type = any(p_roles))
        and (p_sport is null or pr.profile_type='organiser' or pr.sport_key = p_sport)
        and public.can_view_profile(me, pr.id)
        and not (
          lower(unaccent_immutable(pr.username))     like pref || '%' or
          lower(unaccent_immutable(pr.display_name)) like pref || '%'
        )
    )
    select id, profile_type, username, display_name, sport_key, avatar_url
    from fuzzy
    where sim > 0.45
    order by sim desc
    limit greatest(0, take - (
      select count(*) from (
        select 1
        from public.profiles pr
        where (p_roles is null or pr.profile_type = any(p_roles))
          and (p_sport is null or pr.profile_type='organiser' or pr.sport_key = p_sport)
          and (
            lower(unaccent_immutable(pr.username))     like pref || '%' or
            lower(unaccent_immutable(pr.display_name)) like pref || '%'
          )
          and public.can_view_profile(me, pr.id)
      ) c
    ));
  end if;
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_autocomplete_people(text,text[],text,integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_autocomplete_people(text,text[],text,integer) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_autocomplete_people(text,text[],text,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.rpc_autocomplete_people(text,text[],text,integer) TO anon;
GRANT EXECUTE ON FUNCTION public.rpc_autocomplete_people(text,text[],text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_autocomplete_people(text,text[],text,integer) TO service_role;

-- rpc_ban_display_name(text,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_ban_display_name(p_display_name text, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
  dn      text;
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  dn := public.normalize_display_name(p_display_name);

  insert into public.display_name_banned(pattern, reason)
  values (dn, coalesce(p_reason,'moderation_ban'))
  on conflict (pattern) do nothing;

  insert into public.moderation_actions(actor_admin_id, action_type, target_table, target_id, reason, metadata)
  values (v_actor, 'ban_display_name', 'profiles', gen_random_uuid(), p_reason, jsonb_build_object('display_name_norm', dn));
end;
$function$;

-- rpc_ban_username(text,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_ban_username(p_username text, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
  norm    text;
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  norm := public.normalize_username(p_username);

  insert into public.username_banned(username, reason, created_at)
  values (norm, coalesce(p_reason,'moderation_ban'), now())
  on conflict (username) do nothing;

  insert into public.moderation_actions(actor_admin_id, action_type, target_table, target_id, reason, metadata)
  values (v_actor, 'ban_username', 'username_registry', gen_random_uuid(), p_reason, jsonb_build_object('username', norm));
end;
$function$;

-- rpc_delete_post(uuid)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_delete_post(p_post_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  p public.posts%rowtype;
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;
  select * into p from public.posts where id=p_post_id;
  if not found then raise exception using errcode='P0001', message='not_found'; end if;

  if p.author_user_id <> auth.uid() and not public.is_admin(auth.uid()) then
    raise exception using errcode='P0001', message='forbidden';
  end if;

  update public.posts set is_deleted = true where id=p_post_id;
  insert into public.moderation_actions(target_kind,target_id,action,actor_user_id,notes)
  values ('post', p_post_id, 'delete', auth.uid(), 'soft-delete');
  return 'deleted';
end;
$function$;

-- rpc_feed_ranked(text,uuid,text,double precision,double precision,numeric,timestamp with time zone,integer)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_feed_ranked(p_scope text DEFAULT 'home'::text, p_author_user_id uuid DEFAULT NULL::uuid, p_sport text DEFAULT NULL::text, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_radius_km numeric DEFAULT NULL::numeric, p_since timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 30)
 RETURNS TABLE(id uuid, kind text, visibility text, link_token text, body text, lang text, sport_key text, venue_id uuid, media jsonb, like_count integer, comment_count integer, created_at timestamp with time zone, author_username text, author_display_name text, author_role text, score numeric, reasons jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  v_max_km numeric;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  select coalesce(p_radius_km, fcfg.max_km)
  into v_max_km
  from public.feed_rank_config fcfg
  where fcfg.id = true;

  return query
  with base as (
    select *
    from public.v_feed_candidates f
    where (p_sport is null or f.sport_key = p_sport)
      and (p_scope <> 'author' or f.author_user_id = p_author_user_id)
      and (p_since is null or f.created_at < p_since)
  ),
  scoped as (
    select b.*
    from base b
    where case
      when p_scope = 'circle' then public._is_synced(me, b.author_user_id)
      when p_scope = 'author' then true
      else true
    end
  ),
  feats as (
    select
      s.*,
      public._time_decay(s.created_at, fcfg.half_life_hours)                                as f_fresh,
      public._engagement_score(s.id, fcfg.engage_half_life_hours, fcfg.max_engage_per_post) as f_engage,
      public._clamp01(coalesce((select r.composite_score
                                from public.v_user_reputation r
                                where r.user_id = s.author_user_id)/5.0, 0.6))              as f_repute,
      public._bool01(public._is_synced(me, s.author_user_id))                               as f_circle,
      case
        when p_lat is null or p_lng is null then 0.5
        when s.post_lat is not null and s.post_lng is not null
          then public._clamp01(1.0 - least(v_max_km, public._km_between(p_lat, p_lng, s.post_lat, s.post_lng)) / v_max_km)
        else 0.5
      end                                                                                   as f_local,
      public._bool01(p_sport is not null and s.sport_key = p_sport)                         as f_sport,
      public._vibes_momentum_nudge(s.id)                                                    as f_vibes
    from scoped s
    cross join public.feed_rank_config fcfg
    where fcfg.id = true
  ),
  scored as (
    select
      f.*,
      (
        fcfg.w_fresh  * f.f_fresh  +
        fcfg.w_engage * f.f_engage +
        fcfg.w_repute * f.f_repute +
        fcfg.w_circle * f.f_circle +
        fcfg.w_local  * f.f_local  +
        fcfg.w_sport  * f.f_sport  +
        fcfg.w_vibes  * f.f_vibes
      )::numeric as raw_score
    from feats f
    cross join public.feed_rank_config fcfg
    where fcfg.id = true
  )
  select
    q.id, q.kind, q.visibility, q.link_token, q.body, q.lang, q.sport_key, q.venue_id, q.media,
    q.like_count, q.comment_count, q.created_at,
    q.author_username::text,            -- ← cast citext → text
    q.author_display_name::text,        -- ← cast citext → text (safe even if already text)
    q.author_role,
    round(q.raw_score, 6) as score,
    jsonb_build_object(
      'fresh',  q.f_fresh,
      'engage', q.f_engage,
      'repute', q.f_repute,
      'circle', q.f_circle,
      'local',  q.f_local,
      'sport',  q.f_sport,
      'vibes',  q.f_vibes
    ) as reasons
  from scored q
  order by q.raw_score desc, q.created_at desc, q.id
  limit greatest(1, coalesce(p_limit, 30));
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_feed_ranked(text,uuid,text,double precision,double precision,numeric,timestamp with time zone,integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_feed_ranked(text,uuid,text,double precision,double precision,numeric,timestamp with time zone,integer) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_feed_ranked(text,uuid,text,double precision,double precision,numeric,timestamp with time zone,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.rpc_feed_ranked(text,uuid,text,double precision,double precision,numeric,timestamp with time zone,integer) TO anon;
GRANT EXECUTE ON FUNCTION public.rpc_feed_ranked(text,uuid,text,double precision,double precision,numeric,timestamp with time zone,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_feed_ranked(text,uuid,text,double precision,double precision,numeric,timestamp with time zone,integer) TO service_role;

-- rpc_freeze_user(uuid,text,timestamp with time zone)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_freeze_user(p_user_id uuid, p_reason text DEFAULT NULL::text, p_until timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
begin
  if v_actor is null then
    raise exception using errcode='P0001', message='not_authenticated';
  end if;

  if not public.is_admin(v_actor) then
    raise exception using errcode='P0001', message='not_admin';
  end if;

  insert into public.user_freezes(user_id, is_frozen, reason, until, created_by)
  values (p_user_id, true, p_reason, p_until, v_actor)
  on conflict (user_id) do update
    set is_frozen = true,
        reason    = excluded.reason,
        until     = excluded.until,
        frozen_at = now(),
        lifted_at = null;

  insert into public.moderation_actions(actor_admin_id, action_type, target_table, target_id, target_user_id, reason)
  values (v_actor, 'freeze_user', 'auth.users', p_user_id, p_user_id, p_reason);
end;
$function$;

-- rpc_mark_all_read()  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_mark_all_read()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
  update public.notifications
  set is_read = true, read_at = now()
  where user_id = auth.uid() and is_read = false;
  get diagnostics n = row_count;
  return n;
end;
$function$;

-- rpc_moderation_resolve_ticket(uuid,text,text,text,integer)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_moderation_resolve_ticket(p_ticket_id uuid, p_action text, p_notes text DEFAULT NULL::text, p_freeze_scope text DEFAULT NULL::text, p_freeze_days integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t public.moderation_tickets%rowtype;
        target_user uuid;
        until_ts timestamptz;
begin
  if not public.is_admin(auth.uid()) then raise exception using errcode='P0001', message='admin_only'; end if;
  select * into t from public.moderation_tickets where id=p_ticket_id;
  if not found then raise exception using errcode='P0001', message='ticket_not_found'; end if;

  if t.target_kind='post' then
    if p_action='hide' then update public.posts set is_hidden_admin=true where id=t.target_id;
    elsif p_action='unhide' then update public.posts set is_hidden_admin=false where id=t.target_id;
    elsif p_action='delete' then update public.posts set is_deleted=true where id=t.target_id;
    end if;
  elsif t.target_kind='comment' then
    if p_action='hide' then update public.post_comments set is_hidden_admin=true where id=t.target_id;
    elsif p_action='unhide' then update public.post_comments set is_hidden_admin=false where id=t.target_id;
    elsif p_action='delete' then update public.post_comments set is_deleted=true where id=t.target_id;
    end if;
  end if;

  if p_action='freeze' then
    if t.target_kind='post' then
      select author_user_id into target_user from public.posts where id=t.target_id;
    elsif t.target_kind='comment' then
      select author_user_id into target_user from public.post_comments where id=t.target_id;
    end if;
    until_ts := case when p_freeze_days is null then null else now() + (p_freeze_days||' days')::interval end;
    insert into public.user_freezes(user_id, scope, reason, created_by, until, is_active)
    values (target_user, coalesce(p_freeze_scope,'all'), left(coalesce(p_notes,'moderation freeze'),280), auth.uid(), until_ts, true);
  end if;

  update public.moderation_tickets set status =
    case when p_action='dismiss' then 'dismissed' else 'resolved' end,
    updated_at = now()
  where id = p_ticket_id;

  insert into public.moderation_actions(target_kind,target_id,action,actor_user_id,notes)
  values (t.target_kind, t.target_id, p_action, auth.uid(), left(p_notes, 500));

  return 'resolved';
end; $function$;

-- rpc_profile_update_basic(text,text,text,text,text,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_profile_update_basic(p_profile_type text, p_display_name text DEFAULT NULL::text, p_avatar_url text DEFAULT NULL::text, p_bio text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_language text DEFAULT NULL::text)
 RETURNS TABLE(profile_id uuid, profile_type text, username citext, display_name text, avatar_url text, bio text, city text, country text, language text, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  pid uuid;
  new_display_name_norm text;
begin
  if p_profile_type not in ('player','organiser') then
    raise exception using errcode = 'P0001', message = 'profile_type_invalid';
  end if;

  select id into pid
  from public.profiles
  where user_id = me and profile_type = p_profile_type
  limit 1;

  if pid is null then
    raise exception using errcode = 'P0001', message = 'profile_missing';
  end if;

  if p_display_name is not null then
    if public.is_display_name_banned(p_display_name) then
      raise exception using errcode = 'P0001', message = 'display_name_banned';
    end if;

    new_display_name_norm := public.normalize_display_name(p_display_name);

    if public.display_name_conflicts_username(p_display_name, (select username from public.profiles where id = pid)) then
      raise exception using errcode = 'P0001', message = 'display_name_conflicts_username';
    end if;

    if exists (
      select 1 from public.profiles
      where display_name_norm = new_display_name_norm
        and id <> pid
    ) then
      raise exception using errcode = 'P0001', message = 'display_name_taken';
    end if;
  end if;

  update public.profiles
  set display_name = coalesce(p_display_name, display_name),
      avatar_url   = coalesce(p_avatar_url, avatar_url),
      bio          = coalesce(p_bio, bio),
      city         = coalesce(p_city, city),
      language     = coalesce(p_language, language)
  where id = pid
  returning id, profile_type, username, display_name, avatar_url, bio, city, country, language, updated_at
  into profile_id, profile_type, username, display_name, avatar_url, bio, city, country, language, updated_at;

  return next;
end;
$function$;
REVOKE ALL ON FUNCTION public.rpc_profile_update_basic(text,text,text,text,text,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_profile_update_basic(text,text,text,text,text,text) TO postgres;
GRANT EXECUTE ON FUNCTION public.rpc_profile_update_basic(text,text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_profile_update_basic(text,text,text,text,text,text) TO service_role;

-- rpc_unfreeze_user(uuid,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_unfreeze_user(p_user_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
begin
  if v_actor is null then
    raise exception using errcode='P0001', message='not_authenticated';
  end if;
  if not public.is_admin(v_actor) then
    raise exception using errcode='P0001', message='not_admin';
  end if;

  update public.user_freezes
     set is_frozen = false,
         lifted_at = now(),
         reason    = coalesce(p_reason, reason)
   where user_id = p_user_id;

  insert into public.moderation_actions(actor_admin_id, action_type, target_table, target_id, target_user_id, reason)
  values (v_actor, 'unfreeze_user', 'auth.users', p_user_id, p_user_id, p_reason);
end;
$function$;

-- rpc_unverify_profile(uuid,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_unverify_profile(p_profile_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
  uid     uuid;
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  insert into public.profile_verifications(profile_id, verified, verified_at, verified_by, reason)
  values (p_profile_id, false, now(), v_actor, p_reason)
  on conflict (profile_id) do update
    set verified    = false,
        verified_at = now(),
        verified_by = v_actor,
        reason      = coalesce(p_reason, public.profile_verifications.reason);

  select user_id into uid from public.profiles where id = p_profile_id;

  insert into public.moderation_actions(actor_admin_id, action_type, target_table, target_id, target_user_id, reason)
  values (v_actor, 'unverify_profile', 'profiles', p_profile_id, uid, p_reason);
end;
$function$;

-- rpc_verify_profile(uuid,text)  ACL {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.rpc_verify_profile(p_profile_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := public.admin_actor();
  uid     uuid;
begin
  if v_actor is null then raise exception using errcode='P0001', message='not_authenticated'; end if;
  if not public.is_admin(v_actor) then raise exception using errcode='P0001', message='not_admin'; end if;

  insert into public.profile_verifications(profile_id, verified, verified_at, verified_by, reason)
  values (p_profile_id, true, now(), v_actor, p_reason)
  on conflict (profile_id) do update
    set verified    = true,
        verified_at = now(),
        verified_by = v_actor,
        reason      = coalesce(p_reason, public.profile_verifications.reason);

  select user_id into uid from public.profiles where id = p_profile_id;

  insert into public.moderation_actions(actor_admin_id, action_type, target_table, target_id, target_user_id, reason)
  values (v_actor, 'verify_profile', 'profiles', p_profile_id, uid, p_reason);
end;
$function$;

-- search_venues_with_filters(double precision,double precision,double precision,text,numeric,numeric,boolean,text,numeric,text[],text)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.search_venues_with_filters(p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_radius_km double precision DEFAULT 10, p_sport text DEFAULT NULL::text, p_price_min numeric DEFAULT NULL::numeric, p_price_max numeric DEFAULT NULL::numeric, p_is_indoor boolean DEFAULT NULL::boolean, p_surface_type text DEFAULT NULL::text, p_min_rating numeric DEFAULT NULL::numeric, p_amenities text[] DEFAULT NULL::text[], p_city text DEFAULT NULL::text)
 RETURNS TABLE(id uuid, name_en text, address_line1 text, city text, lat double precision, lng double precision, is_indoor boolean, surface_type text, min_price_per_hour numeric, max_price_per_hour numeric, rating numeric, rating_count integer, amenities text[], distance_km double precision)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    v.id,
    v.name_en,
    v.address_line1,
    v.city,
    v.lat,
    v.lng,
    v.is_indoor,
    v.surface_type,
    v.min_price_per_hour,
    v.max_price_per_hour,
    v.rating,
    v.rating_count,
    v.amenities,
    CASE 
      WHEN p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
        -- Haversine distance calculation (approximate)
        6371 * acos(
          cos(radians(p_lat)) * 
          cos(radians(v.lat)) * 
          cos(radians(v.lng) - radians(p_lng)) + 
          sin(radians(p_lat)) * 
          sin(radians(v.lat))
        )
      ELSE NULL
    END AS distance_km
  FROM venues v
  LEFT JOIN venue_spaces vs ON vs.venue_id = v.id
  WHERE 
    v.is_active = true
    AND (p_sport IS NULL OR vs.sport = p_sport)
    AND (p_city IS NULL OR v.city = p_city)
    AND (p_price_min IS NULL OR v.max_price_per_hour >= p_price_min)
    AND (p_price_max IS NULL OR v.min_price_per_hour <= p_price_max)
    AND (p_is_indoor IS NULL OR v.is_indoor = p_is_indoor)
    AND (p_surface_type IS NULL OR v.surface_type = p_surface_type)
    AND (p_min_rating IS NULL OR v.rating >= p_min_rating)
    AND (p_amenities IS NULL OR v.amenities && p_amenities)
    AND (
      p_lat IS NULL OR 
      p_lng IS NULL OR
      -- Distance filter (using bounding box approximation)
      v.lat BETWEEN p_lat - (p_radius_km / 111.0) AND p_lat + (p_radius_km / 111.0)
      AND v.lng BETWEEN p_lng - (p_radius_km / (111.0 * cos(radians(p_lat)))) 
                     AND p_lng + (p_radius_km / (111.0 * cos(radians(p_lat))))
    )
  GROUP BY v.id, v.name_en, v.address_line1, v.city, v.lat, v.lng, 
           v.is_indoor, v.surface_type, v.min_price_per_hour, v.max_price_per_hour,
           v.rating, v.rating_count, v.amenities
  ORDER BY distance_km NULLS LAST, v.rating DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.search_venues_with_filters(double precision,double precision,double precision,text,numeric,numeric,boolean,text,numeric,text[],text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.search_venues_with_filters(double precision,double precision,double precision,text,numeric,numeric,boolean,text,numeric,text[],text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_venues_with_filters(double precision,double precision,double precision,text,numeric,numeric,boolean,text,numeric,text[],text) TO postgres;
GRANT EXECUTE ON FUNCTION public.search_venues_with_filters(double precision,double precision,double precision,text,numeric,numeric,boolean,text,numeric,text[],text) TO anon;
GRANT EXECUTE ON FUNCTION public.search_venues_with_filters(double precision,double precision,double precision,text,numeric,numeric,boolean,text,numeric,text[],text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_venues_with_filters(double precision,double precision,double precision,text,numeric,numeric,boolean,text,numeric,text[],text) TO service_role;

-- trgfn_payment_to_ledger()  ACL {postgres=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.trgfn_payment_to_ledger()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_platform_pct numeric;
  v_platform_fee numeric;
  v_venue_amount numeric;

  v_user_wallet uuid;
  v_platform_wallet uuid;
  v_venue_wallet uuid;

  v_venue_id uuid;
BEGIN
  -- Only fire on success
  IF NEW.status <> 'succeeded' THEN
    RETURN NEW;
  END IF;

  -- Prevent double processing
  -- KAN-128 / T-049 Invariant 4: this EXISTS check is a read-then-write with no
  -- lock. It is NOT idempotency and is no longer the only thing between a
  -- webhook and a double credit -- financial_ledger_payment_entry_unique is. It
  -- stays as a cheap early return that avoids an error round-trip.
  IF EXISTS (
    SELECT 1
    FROM public.financial_ledger
    WHERE payment_intent_id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  -- Get booking venue
  -- KAN-140 / T-061: two-hop join through venue_bookings -> venue_spaces.
  -- Both venue_bookings.venue_space_id and venue_spaces.venue_id are NOT NULL
  -- with FKs enforcing referential integrity, so given a venue_bookings row
  -- venue_id cannot be NULL -- no NULL-handling branch is written. INTO
  -- STRICT asserts (does not establish) that booking_id resolves to exactly
  -- one row, a guarantee KAN-145's payment_intents_booking_id_fkey holds.
  SELECT vs.venue_id
  INTO STRICT v_venue_id
  FROM public.venue_bookings vb
  JOIN public.venue_spaces vs ON vs.id = vb.venue_space_id
  WHERE vb.id = NEW.booking_id;

  -- Get commission
  SELECT percentage
  INTO v_platform_pct
  FROM public.commission_rules
  WHERE applies_to = 'platform'
    AND is_active = true
  LIMIT 1;

  v_platform_fee := round(NEW.amount * (v_platform_pct / 100), 2);
  v_venue_amount := NEW.amount - v_platform_fee;

  -- Resolve wallets
  v_user_wallet := fn_get_wallet('user', NEW.user_id, NEW.currency);
  v_platform_wallet := fn_get_wallet('platform', fn_platform_owner_id(), NEW.currency);
  v_venue_wallet := fn_get_wallet('venue', v_venue_id, NEW.currency);

  -- USER pays
  INSERT INTO public.financial_ledger (
    entity_type, entity_id, wallet_id,
    booking_id, payment_intent_id,
    entry_type, amount, currency, reason
  ) VALUES (
    'user', NEW.user_id, v_user_wallet,
    NEW.booking_id, NEW.id,
    'debit', NEW.amount, NEW.currency, 'booking_payment'
  )
  ON CONFLICT DO NOTHING;

  -- PLATFORM commission
  INSERT INTO public.financial_ledger (
    entity_type, entity_id, wallet_id,
    booking_id, payment_intent_id,
    entry_type, amount, currency, reason
  ) VALUES (
    'platform', fn_platform_owner_id(), v_platform_wallet,
    NEW.booking_id, NEW.id,
    'credit', v_platform_fee, NEW.currency, 'commission'
  )
  ON CONFLICT DO NOTHING;

  -- VENUE revenue
  INSERT INTO public.financial_ledger (
    entity_type, entity_id, wallet_id,
    booking_id, payment_intent_id,
    entry_type, amount, currency, reason
  ) VALUES (
    'venue', v_venue_id, v_venue_wallet,
    NEW.booking_id, NEW.id,
    'credit', v_venue_amount, NEW.currency, 'booking_payment'
  )
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$function$;

-- trgfn_set_venue_space_sport_id()  ACL {postgres=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.trgfn_set_venue_space_sport_id()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- If sport_id is already provided, nothing to do
  IF new.sport_id IS NOT NULL THEN
    RETURN new;
  END IF;

  -- Legacy fallback: resolve sport_id from sport text key if present
  IF new.sport IS NOT NULL THEN
    SELECT s.id
    INTO new.sport_id
    FROM public.sports s
    WHERE s.sport_key = CASE
      WHEN lower(trim(new.sport)) = 'paddle' THEN 'padel'
      ELSE lower(trim(new.sport))
    END
    AND s.is_active = true;

    IF new.sport_id IS NULL THEN
      RAISE EXCEPTION USING
        errcode = 'P0001',
        message = 'invalid_sport';
    END IF;
  END IF;

  RETURN new;
END;
$function$;

-- unsync(uuid)  ACL {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
CREATE OR REPLACE FUNCTION public.unsync(p_other_user uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  a uuid; b uuid; e friend_edges%rowtype;
begin
  if me is null then raise exception using errcode='P0001', message='auth_required'; end if;

  select a,b into a,b from public._pair(me, p_other_user);
  select * into e from public.friend_edges
   where least(user_a,user_b)=a and greatest(user_a,user_b)=b
   for update;

  if e.id is null or e.status <> 'accepted' then
    return 'not_synced';
  end if;

  update public.friend_edges
    set status='removed', responded_by=me, updated_at=now()
  where id=e.id;

  insert into public.friend_requests_audit(from_user,to_user,action,edge_id)
  values (me, p_other_user, 'removed', e.id);

  -- TODO: notification friend.removed (optional)
  return 'unsynced';
end;
$function$;
REVOKE ALL ON FUNCTION public.unsync(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.unsync(uuid) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.unsync(uuid) TO postgres;
GRANT EXECUTE ON FUNCTION public.unsync(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.unsync(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unsync(uuid) TO service_role;

COMMIT;
