-- KAN-862 P3 (reads and ratings; supersedes the unapplied KAN-807 D04 residual files
-- _superseded/20261104110900_kan807_d04_residual_a.sql and _superseded/20261104111000_kan807_d04_residual_b.sql).
-- These SECURITY DEFINER functions stop reading the games/meetups copies of the shared event facts and read them from
-- public.events only (every body already joins it on event_id), so KAN-719 Z01 cannot break them with 42703.
--
--   function                                                                           removed read
--   public._is_game_host(uuid)                                                         g.creator_user_id (e.creator_user_id kept)
--   public.active_stream(text[], text, integer, timestamptz, text, uuid)               g.is_cancelled, g.creator_user_id; m.is_cancelled,
--                                                                                      m.creator_user_id, can_view_owner(m.creator_user_id,
--                                                                                      m.listing_visibility) (e.* halves and kan713_meetup_visible kept)
--   public.rpc_get_activity_feed(text, integer, timestamptz)                           g.is_cancelled (e.is_cancelled kept)
--   public.rpc_rate_game(uuid, uuid, jsonb, text)                                      g0.is_cancelled -> e.is_cancelled
--   public.rpc_rate_user(uuid, uuid, uuid, jsonb, text)                                g0.creator_user_id, g0.start_at, g0.is_cancelled -> e.*
--   public.rpc_rate_venue(uuid, uuid, uuid, jsonb, text)                               g0.creator_user_id, g0.is_cancelled -> e.*
--
-- NOT TOUCHED (verified live 2026-11-13): public._can_view_game(uuid) already reads events only (KAN-903, md5(prosrc)
-- 85f265c09711425a66a21c4a595cce62); public.rpc_get_nearby_games(6-arg) already equals the KAN-807 post-image
-- (3a27dca7144c61e9615f25517ba814c9).
--
-- WHY THE RESULT IS UNCHANGED. Each removed read was one half of an intersection (or, for the rating cancel flag, a
-- union) whose other half reads the same field from events. Section 0 refuses unless every removed column equals its
-- events counterpart on every row (KAN-711 parity; 0 mismatches live at authoring), so the same rows are selected.
-- kan713_meetup_visible(event_id) is can_view_owner(e.creator_user_id, e.listing_visibility) on events.
--
-- AUTHORED FROM THE LIVE CATALOGUE (T-058). Live md5(prosrc) of all six equals the KAN-807 pinned pre-images, and the
-- pre-image bodies (20261104100800_kan714_b08..., 20261104101200_kan714_b12..., _is_game_host via pg_get_functiondef)
-- were diffed line by line against the new bodies: only the reads above change. CREATE OR REPLACE with the same
-- signature keeps oid, owner, ACL, SECURITY DEFINER, volatility and search_path; section 2 asserts it. No table,
-- column, policy, trigger, grant or row is touched. No BEGIN/COMMIT (the CLI wraps each migration).
--
-- Live proof: supabase/tests/events_p4/kan862_p3_residual_reads_ratings_test.sql (BEGIN ... ROLLBACK).

set local lock_timeout = '10s';

-- 0. Preconditions. Refuse; never repair.
do $pre$
declare
  r record;
  v_n bigint;
  c record;
  v_attr jsonb;
begin
  for r in select * from (values
    ('public._is_game_host(uuid)', '6db7b07bf7cf405d6935ecbf7bc15800', '046664286d884f8697502a84aacf61ab'),
    ('public.active_stream(text[], text, integer, timestamp with time zone, text, uuid)', '3cad1cfaaa6fb56e1cbd7ac86e7e5192', '8dcd300437015f7570e5b0ea6dbdb9b7'),
    ('public.rpc_get_activity_feed(text, integer, timestamp with time zone)', '1d6bb17983ba2ed632cb4f7602257162', '88455cacf9aa21fd739854938e27758d'),
    ('public.rpc_rate_game(uuid, uuid, jsonb, text)', 'd6f6f57755538391ece9aa19b6dd8a50', 'de0f3b8f83fbc730f81a59eb62f64b42'),
    ('public.rpc_rate_user(uuid, uuid, uuid, jsonb, text)', 'fd2700e72e60bdf7f7eb9e1b36201b10', 'dffe5f8e35a99b27cb627be34d659e91'),
    ('public.rpc_rate_venue(uuid, uuid, uuid, jsonb, text)', 'd1dab20091ecef646714dc20edf8ea7d', 'fe2f803c1e63949bc3cee62f47dd57e3')) k(fn, pre_md5, post_md5) loop
    if to_regprocedure(r.fn) is null then
      raise exception 'KAN-862 P3 pre: % is absent', r.fn;
    end if;
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) not in (r.pre_md5, r.post_md5) then
      raise exception 'KAN-862 P3 pre: pre-image drift on % (md5(prosrc) is %, expected %); re-author from pg_get_functiondef',
        r.fn, (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)), r.pre_md5;
    end if;
    if not (select prosecdef from pg_proc where oid = to_regprocedure(r.fn)) then
      raise exception 'KAN-862 P3 pre: % is no longer SECURITY DEFINER', r.fn;
    end if;
  end loop;
  for c in select * from (values ('games','game','creator_user_id'), ('games','game','is_cancelled'), ('games','game','start_at'),
                                 ('meetups','meetup','creator_user_id'), ('meetups','meetup','listing_visibility'),
                                 ('meetups','meetup','is_cancelled')) v(tbl, etype, col) loop
    if exists (select 1 from pg_attribute where attrelid = ('public.' || c.tbl)::regclass and attname = c.col and not attisdropped) then
      execute format('select count(*) from public.%I x left join public.events e on e.id = x.event_id and e.event_type = %L
                       where e.id is null or x.%I is distinct from e.%I', c.tbl, c.etype, c.col, c.col) into v_n;
      if v_n <> 0 then
        raise exception 'KAN-862 P3 pre: % row(s) of public.% lack their typed events parent or differ on % (KAN-711 parity)', v_n, c.tbl, c.col;
      end if;
    end if;
  end loop;
  select jsonb_object_agg(k.fn, jsonb_build_array(pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
           p.prosecdef, p.provolatile, p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset))
    into v_attr
    from (values
    ('public._is_game_host(uuid)', '6db7b07bf7cf405d6935ecbf7bc15800', '046664286d884f8697502a84aacf61ab'),
    ('public.active_stream(text[], text, integer, timestamp with time zone, text, uuid)', '3cad1cfaaa6fb56e1cbd7ac86e7e5192', '8dcd300437015f7570e5b0ea6dbdb9b7'),
    ('public.rpc_get_activity_feed(text, integer, timestamp with time zone)', '1d6bb17983ba2ed632cb4f7602257162', '88455cacf9aa21fd739854938e27758d'),
    ('public.rpc_rate_game(uuid, uuid, jsonb, text)', 'd6f6f57755538391ece9aa19b6dd8a50', 'de0f3b8f83fbc730f81a59eb62f64b42'),
    ('public.rpc_rate_user(uuid, uuid, uuid, jsonb, text)', 'fd2700e72e60bdf7f7eb9e1b36201b10', 'dffe5f8e35a99b27cb627be34d659e91'),
    ('public.rpc_rate_venue(uuid, uuid, uuid, jsonb, text)', 'd1dab20091ecef646714dc20edf8ea7d', 'fe2f803c1e63949bc3cee62f47dd57e3')) k(fn, pre_md5, post_md5) join pg_proc p on p.oid = to_regprocedure(k.fn);
  perform set_config('kan862.p3_attr', v_attr::text, true);
end $pre$;

-- 1. New bodies (pg_get_functiondef of the live pre-image; only the reads listed above change).
CREATE OR REPLACE FUNCTION public._is_game_host(p_game_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'   -- KAN-713
    where g.id = p_game_id
      and e.creator_user_id = auth.uid()                                  -- KAN-713 / KAN-807: host from events
  );
$function$;

CREATE OR REPLACE FUNCTION public.active_stream(p_event_types text[] DEFAULT NULL::text[], p_city text DEFAULT NULL::text, p_limit integer DEFAULT 30, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_type text DEFAULT NULL::text, p_before_entity uuid DEFAULT NULL::uuid)
 RETURNS TABLE(event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH prm AS (
    SELECT auth.uid() AS viewer,
           LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50) AS lim,
           NULLIF(btrim(p_city), '') AS city
  ),
  ev AS (
    -- player_joined
    SELECT 'player_joined'::text AS event_type, p.created_at AS event_at, 'profile'::text AS entity_kind,
           p.id AS entity_id, p.id AS actor_profile_id, p.city AS city, p.display_name AS title
      FROM public.profiles p, prm
     WHERE prm.viewer IS NOT NULL
       AND p.profile_type = 'personal'
       AND p.created_at IS NOT NULL
       AND public.is_profile_publicly_visible(p.id)
       AND NOT public.is_blocked(prm.viewer, p.user_id)
    UNION ALL
    -- venue_added
    SELECT 'venue_added'::text, v.created_at, 'venue'::text, v.id, NULL::uuid, a.city, v.name_en
      FROM public.venues v
      JOIN public.areas a ON a.id = v.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND v.is_active = true
       AND (v.owner_user_id IS NULL OR NOT public.is_blocked(prm.viewer, v.owner_user_id))
    UNION ALL
    -- game_created
    SELECT 'game_created'::text, e.created_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- game_started
    SELECT 'game_started'::text, e.start_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- game_ended
    SELECT 'game_ended'::text, e.end_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.end_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_created
    SELECT 'meetup_created'::text, e.created_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_started
    SELECT 'meetup_started'::text, e.start_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_completed
    SELECT 'meetup_completed'::text, COALESCE(e.end_at, e.start_at), 'meetup'::text, m.id, e.creator_profile_id,
           a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND e.is_cancelled = false
       AND COALESCE(e.end_at, e.start_at) <= now()
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
  ),
  filtered AS (
    SELECT DISTINCT ON (ev.event_type, ev.entity_id) ev.*
      FROM ev, prm
     WHERE (p_event_types IS NULL OR ev.event_type = ANY (p_event_types))
       AND (prm.city IS NULL OR lower(ev.city) = lower(prm.city))
       AND (
         p_before IS NULL
         OR ev.event_at < p_before
         OR (p_before_type IS NOT NULL AND p_before_entity IS NOT NULL
             AND ev.event_at = p_before
             AND (ev.event_type, ev.entity_id) < (p_before_type, p_before_entity))
       )
     ORDER BY ev.event_type, ev.entity_id, ev.event_at DESC
  )
  SELECT f.event_type, f.event_at, f.entity_kind, f.entity_id, f.actor_profile_id, f.city, f.title
    FROM filtered f
   ORDER BY f.event_at DESC, f.event_type DESC, f.entity_id DESC
   LIMIT (SELECT lim FROM prm);
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_activity_feed(_period text DEFAULT 'all'::text, _limit integer DEFAULT 50, _cursor timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(id uuid, subject_type text, subject_id uuid, verb text, status text, time_bucket text, happened_at timestamp with time zone, scheduled_for timestamp with time zone, priority integer, payload jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  WITH me AS (
    SELECT auth.uid() AS user_id
  ),
  game_created AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'created'::text                                               AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN e.end_at < NOW()                              THEN 'past'
        WHEN e.start_at <= NOW() AND e.end_at >= NOW()    THEN 'present'
        WHEN e.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      e.created_at                                                  AS happened_at,
      e.start_at                                                    AS scheduled_for,
      90                                                            AS priority,
      jsonb_build_object('role', 'host')                            AS payload
    FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731: shared columns from events
    JOIN me ON e.creator_user_id = me.user_id
    WHERE e.is_cancelled = false                                           -- KAN-731 / KAN-807: events half only
  ),
  game_joined AS (
    SELECT
      g.id                                                          AS id,
      'game'::text                                                  AS subject_type,
      g.id                                                          AS subject_id,
      'joined'::text                                                AS verb,
      NULL::text                                                    AS status,
      CASE
        WHEN e.end_at < NOW()                              THEN 'past'
        WHEN e.start_at <= NOW() AND e.end_at >= NOW()    THEN 'present'
        WHEN e.start_at > NOW()                           THEN 'upcoming'
        ELSE 'past'
      END                                                           AS time_bucket,
      gr.joined_at                                                  AS happened_at,
      e.start_at                                                    AS scheduled_for,
      80                                                            AS priority,
      jsonb_build_object('role', 'player')                          AS payload
    FROM public.game_roster gr
    JOIN public.games g ON g.id = gr.game_id
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731: shared columns from events
    JOIN me ON gr.user_id = me.user_id
    WHERE gr.status = 'active'
      AND e.is_cancelled = false                                           -- KAN-731 / KAN-807: events half only
      AND e.creator_user_id <> me.user_id
  ),
  game_events AS (
    SELECT * FROM game_created
    UNION ALL
    SELECT * FROM game_joined
  ),
  filtered AS (
    SELECT * FROM game_events e
    WHERE (_period = 'all' OR e.time_bucket = _period)
      AND (_cursor IS NULL OR e.happened_at < _cursor)
  )
  SELECT f.* FROM filtered f
  ORDER BY
    CASE f.time_bucket WHEN 'upcoming' THEN 1 WHEN 'present' THEN 2 WHEN 'past' THEN 3 END,
    f.scheduled_for ASC,
    f.happened_at DESC,
    f.priority DESC
  LIMIT _limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_rate_game(p_game_id uuid, p_rater_profile_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  g record;
  prof record;
  r_user uuid;
  d record; v numeric;
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;

  -- KAN-727 / KAN-807: end_at and cancelled from events.
  select g0.id, e.end_at, e.is_cancelled as is_cancelled into g
    from public.games g0 join public.events e on e.id = g0.event_id and e.event_type = 'game'
   where g0.id=p_game_id;
  if not found or g.is_cancelled then raise exception using errcode='P0001', message='game_not_ratable'; end if;
  if now() > g.end_at + interval '7 days' then raise exception using errcode='P0001', message='rating_window_closed'; end if;

  select id, user_id, profile_type into prof from public.profiles where id=p_rater_profile_id;
  if not found or prof.user_id <> auth.uid() then raise exception using errcode='P0001', message='not_profile_owner'; end if;
  if prof.profile_type <> 'player' then raise exception using errcode='P0001', message='organiser_cannot_rate_game'; end if;
  r_user := prof.user_id;

  if not public._user_played_in_game(r_user, p_game_id) then
    raise exception using errcode='P0001', message='rater_not_in_game';
  end if;

  if exists (select 1 from public.game_rating_events where game_id=p_game_id and rater_user_id=r_user) then
    raise exception using errcode='P0001', message='already_rated';
  end if;

  if p_scores is null or jsonb_typeof(p_scores) <> 'object' then
    raise exception using errcode='P0001', message='invalid_scores';
  end if;

  for d in select key from public.game_rating_dimensions where is_active loop
    if p_scores ? d.key then
      v := (p_scores ->> d.key)::numeric;
      if v is null then raise exception using errcode='P0001', message='score_not_numeric'; end if;
      if v < 0 or v > 5 then raise exception using errcode='P0001', message='score_out_of_range'; end if;
    end if;
  end loop;

  insert into public.game_rating_events(game_id, rater_user_id, rater_profile_id, scores, comment)
  values (p_game_id, r_user, p_rater_profile_id, p_scores, left(p_comment, 280));

  perform public.game_rating_recompute(p_game_id);

  return 'ok';
end;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_rate_user(p_game_id uuid, p_rater_profile_id uuid, p_ratee_user_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g              record;
  rater_user     uuid;
  rprof          record;
  ratee_is_host  boolean;
  window_ok      boolean;
  d              record;
  k text; v numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  -- KAN-727 / KAN-807: creator, start_at, end_at and cancelled from events.
  SELECT g0.id, e.creator_user_id, e.start_at, e.end_at, e.is_cancelled AS is_cancelled INTO g
    FROM public.games g0 JOIN public.events e ON e.id = g0.event_id AND e.event_type = 'game'
   WHERE g0.id = p_game_id;
  IF NOT FOUND OR g.is_cancelled THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_ratable'; END IF;

  window_ok := (now() <= g.end_at + interval '7 days');
  IF NOT window_ok THEN RAISE EXCEPTION USING errcode='P0001', message='rating_window_closed'; END IF;

  SELECT id, user_id, profile_type INTO rprof FROM public.profiles WHERE id = p_rater_profile_id;
  IF NOT FOUND OR rprof.user_id <> auth.uid() THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_profile_owner';
  END IF;
  IF rprof.profile_type <> 'player' THEN
    RAISE EXCEPTION USING errcode='P0001', message='organiser_cannot_rate_user';
  END IF;

  rater_user := rprof.user_id;

  IF NOT EXISTS (SELECT 1 FROM public.game_roster WHERE game_id = p_game_id AND user_id = rater_user AND status = 'active') THEN
    RAISE EXCEPTION USING errcode='P0001', message='rater_not_in_game';
  END IF;

  ratee_is_host := (p_ratee_user_id = g.creator_user_id);
  IF NOT ratee_is_host AND NOT EXISTS (
    SELECT 1 FROM public.game_roster WHERE game_id = p_game_id AND user_id = p_ratee_user_id AND status = 'active'
  ) THEN RAISE EXCEPTION USING errcode='P0001', message='ratee_not_in_game'; END IF;

  IF p_ratee_user_id = rater_user THEN
    RAISE EXCEPTION USING errcode='P0001', message='cannot_rate_self';
  END IF;

  IF EXISTS (SELECT 1 FROM public.user_reputation_events WHERE game_id = p_game_id AND rater_user_id = rater_user AND ratee_user_id = p_ratee_user_id) THEN
    RAISE EXCEPTION USING errcode='P0001', message='already_rated';
  END IF;

  IF p_scores IS NULL OR jsonb_typeof(p_scores) <> 'object' THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_scores';
  END IF;

  FOR d IN
    SELECT key FROM public.reputation_dimensions
    WHERE is_active = true
      AND (
        (ratee_is_host     AND 'rate_organiser' = ANY(applicable_to)) OR
        (NOT ratee_is_host AND 'rate_player'    = ANY(applicable_to))
      )
  LOOP
    k := d.key;
    IF p_scores ? k THEN
      v := (p_scores ->> k)::numeric;
      IF v IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='score_not_numeric'; END IF;
      IF v < 0 OR v > 5 THEN RAISE EXCEPTION USING errcode='P0001', message='score_out_of_range'; END IF;
    END IF;
  END LOOP;

  INSERT INTO public.user_reputation_events(game_id, rater_user_id, rater_profile_id, ratee_user_id, scores, comment)
  VALUES (p_game_id, rater_user, p_rater_profile_id, p_ratee_user_id, p_scores, LEFT(p_comment, 280));

  PERFORM public.reputation_recompute(p_ratee_user_id);
  RETURN 'ok';
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_rate_venue(p_game_id uuid, p_venue_id uuid, p_rater_profile_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g      record;
  prof   record;
  r_user uuid;
  d record; v numeric;
  tied boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  -- KAN-727 / KAN-807: creator, end_at and cancelled from events.
  SELECT g0.id, e.creator_user_id, e.end_at, e.is_cancelled AS is_cancelled INTO g
    FROM public.games g0 JOIN public.events e ON e.id = g0.event_id AND e.event_type = 'game'
   WHERE g0.id = p_game_id;
  IF NOT FOUND OR g.is_cancelled THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_ratable'; END IF;

  IF NOT public._game_belongs_to_venue(p_game_id, p_venue_id) THEN
    RAISE EXCEPTION USING errcode='P0001', message='venue_mismatch';
  END IF;
  IF now() > g.end_at + interval '7 days' THEN
    RAISE EXCEPTION USING errcode='P0001', message='rating_window_closed';
  END IF;

  SELECT id, user_id, profile_type INTO prof FROM public.profiles WHERE id = p_rater_profile_id;
  IF NOT FOUND OR prof.user_id <> auth.uid() THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_profile_owner';
  END IF;
  r_user := prof.user_id;

  IF prof.profile_type = 'player' THEN
    tied := public._user_played_in_game(r_user, p_game_id);
  ELSE
    tied := public._user_hosted_game(r_user, p_game_id);
  END IF;
  IF NOT tied THEN RAISE EXCEPTION USING errcode='P0001', message='rater_not_tied_to_game'; END IF;

  IF EXISTS (SELECT 1 FROM public.venue_rating_events WHERE game_id = p_game_id AND venue_id = p_venue_id AND rater_user_id = r_user) THEN
    RAISE EXCEPTION USING errcode='P0001', message='already_rated';
  END IF;

  IF p_scores IS NULL OR jsonb_typeof(p_scores) <> 'object' THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_scores';
  END IF;

  FOR d IN SELECT key FROM public.venue_rating_dimensions WHERE is_active LOOP
    IF p_scores ? d.key THEN
      v := (p_scores ->> d.key)::numeric;
      IF v IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='score_not_numeric'; END IF;
      IF v < 0 OR v > 5 THEN RAISE EXCEPTION USING errcode='P0001', message='score_out_of_range'; END IF;
    END IF;
  END LOOP;

  INSERT INTO public.venue_rating_events(game_id, venue_id, rater_user_id, rater_profile_id, scores, comment)
  VALUES (p_game_id, p_venue_id, r_user, p_rater_profile_id, p_scores, LEFT(p_comment, 280));

  PERFORM public.venue_rating_recompute(p_venue_id);
  RETURN 'ok';
END;
$function$;

-- 2. Postconditions: new body pinned; signature, result, SECURITY, volatility, search_path, owner, ACL unchanged.
do $post$
declare
  r record;
  v_attr jsonb := current_setting('kan862.p3_attr')::jsonb;
  v_now jsonb;
begin
  for r in select * from (values
    ('public._is_game_host(uuid)', '6db7b07bf7cf405d6935ecbf7bc15800', '046664286d884f8697502a84aacf61ab'),
    ('public.active_stream(text[], text, integer, timestamp with time zone, text, uuid)', '3cad1cfaaa6fb56e1cbd7ac86e7e5192', '8dcd300437015f7570e5b0ea6dbdb9b7'),
    ('public.rpc_get_activity_feed(text, integer, timestamp with time zone)', '1d6bb17983ba2ed632cb4f7602257162', '88455cacf9aa21fd739854938e27758d'),
    ('public.rpc_rate_game(uuid, uuid, jsonb, text)', 'd6f6f57755538391ece9aa19b6dd8a50', 'de0f3b8f83fbc730f81a59eb62f64b42'),
    ('public.rpc_rate_user(uuid, uuid, uuid, jsonb, text)', 'fd2700e72e60bdf7f7eb9e1b36201b10', 'dffe5f8e35a99b27cb627be34d659e91'),
    ('public.rpc_rate_venue(uuid, uuid, uuid, jsonb, text)', 'd1dab20091ecef646714dc20edf8ea7d', 'fe2f803c1e63949bc3cee62f47dd57e3')) k(fn, pre_md5, post_md5) loop
    if (select md5(prosrc) from pg_proc where oid = to_regprocedure(r.fn)) <> r.post_md5 then
      raise exception 'KAN-862 P3 post: % body is not the authored one', r.fn;
    end if;
    select jsonb_build_array(pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid), p.prosecdef, p.provolatile,
             p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text, p.prolang, p.proretset)
      into v_now from pg_proc p where p.oid = to_regprocedure(r.fn);
    if v_now is distinct from v_attr -> r.fn then
      raise exception 'KAN-862 P3 post: % changed signature/result/SECURITY/volatility/search_path/owner/ACL: % -> %', r.fn, v_attr -> r.fn, v_now;
    end if;
  end loop;
end $post$;
