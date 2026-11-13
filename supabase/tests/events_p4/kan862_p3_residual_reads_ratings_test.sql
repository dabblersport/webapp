-- KAN-862 P3 live proof for supabase/migrations/20261113145011_kan862_p3_residual_reads_ratings.sql.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
-- Nothing persists: the fixture cancellations, every rating call (each in its own subtransaction, always undone) and
-- the pg_temp twins are undone by the final ROLLBACK.
--
-- OBJECTS. public._is_game_host, public.active_stream, public.rpc_get_activity_feed, public.rpc_rate_game,
-- public.rpc_rate_user, public.rpc_rate_venue now read the shared event facts from public.events only. The migration
-- removed the games/meetups half of each intersection (creator_user_id, is_cancelled, start_at, listing_visibility).
--
-- TWINS. pg_temp.k862_pre_<fn> is the verbatim live pre-image body of each function (T0 proves md5(prosrc) equals the
-- pinned pre-image), with SECURITY DEFINER dropped (the test runs as postgres, the owner, so the reads are the same).
-- pg_temp.k862_mut_active_stream drops the cancelled filter; pg_temp.k862_mut_rpc_rate_game treats every game as not
-- cancelled. They are the negative controls: a comparison that cannot tell them apart proves nothing.
-- PHASES. 'live' uses the data as it is (0 cancelled events on 2026-11-13). 'fixture' cancels two recently ended
-- games, one upcoming game and two meetups, on both the subtype row and its events parent (KAN-711 parity kept).
-- Callers: up to 4 game hosts, 3 meetup hosts, 4 roster members of recently ended games, one admin, one plain user, anon.
--   T0  twins are the true pre-images; mutants differ from the new bodies
--   T1  each new body reads none of the removed games/meetups columns, and none names a Z01 manifest column   RED before
--   T2  _is_game_host           live = pre-image twin, every caller x every game, both phases
--   T3  active_stream           live = twin, every caller x {all, game types, meetup types}, both phases
--   T4  rpc_get_activity_feed   live = twin, every caller, both phases
--   T5  rpc_rate_game           live = twin, every caller x every scenario game, both phases (outcome or error text)
--   T6  rpc_rate_user           same, ratee = the host and a roster member
--   T7  rpc_rate_venue          same, venue = the game's venue_id (or a missing id)
--   T8  negative controls: each mutant differs from its twin in the fixture phase
--   T9  capture not trivial (rows returned, more than one outcome kind, fixture rows seen)
--   T10 attributes / ACL unchanged on all six (owner, SECURITY DEFINER, volatility, search_path, proacl, language)
-- VALID ONLY BEFORE Z01: the twins read the columns Z01 drops.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k862_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k862_cap (ph text, fn text, variant text, k text, v text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.k862_pre__is_game_host(p_game_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $zz$
  select exists (
    select 1 from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'   -- KAN-713
    where g.id = p_game_id
      and g.creator_user_id = auth.uid()
      and e.creator_user_id = auth.uid()                                  -- KAN-713: both must agree
  );
$zz$;
CREATE FUNCTION pg_temp.k862_pre_active_stream(p_event_types text[] DEFAULT NULL::text[], p_city text DEFAULT NULL::text, p_limit integer DEFAULT 30, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_type text DEFAULT NULL::text, p_before_entity uuid DEFAULT NULL::uuid)
 RETURNS TABLE(event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $zz$
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
       AND g.is_cancelled = false AND e.is_cancelled = false
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
    UNION ALL
    -- game_started
    SELECT 'game_started'::text, e.start_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
    UNION ALL
    -- game_ended
    SELECT 'game_ended'::text, e.end_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND g.is_cancelled = false AND e.is_cancelled = false
       AND e.end_at <= now()
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, g.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
    UNION ALL
    -- meetup_created
    SELECT 'meetup_created'::text, e.created_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false AND e.is_cancelled = false
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
    UNION ALL
    -- meetup_started
    SELECT 'meetup_started'::text, e.start_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false AND e.is_cancelled = false
       AND e.start_at <= now()
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
    UNION ALL
    -- meetup_completed
    SELECT 'meetup_completed'::text, COALESCE(e.end_at, e.start_at), 'meetup'::text, m.id, e.creator_profile_id,
           a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
       AND m.is_cancelled = false AND e.is_cancelled = false
       AND COALESCE(e.end_at, e.start_at) <= now()
       AND public.can_view_owner(m.creator_user_id, m.listing_visibility)
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, m.creator_user_id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731: intersection, never wider
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
$zz$;
CREATE FUNCTION pg_temp.k862_pre_rpc_get_activity_feed(_period text DEFAULT 'all'::text, _limit integer DEFAULT 50, _cursor timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS TABLE(id uuid, subject_type text, subject_id uuid, verb text, status text, time_bucket text, happened_at timestamp with time zone, scheduled_for timestamp with time zone, priority integer, payload jsonb)
 LANGUAGE plpgsql

 SET search_path TO 'public', 'pg_temp'
AS $zz$
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
    WHERE g.is_cancelled = false
      AND e.is_cancelled = false                                           -- KAN-731: intersection, never wider
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
      AND g.is_cancelled = false
      AND e.is_cancelled = false                                           -- KAN-731: intersection, never wider
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
$zz$;
CREATE FUNCTION pg_temp.k862_pre_rpc_rate_game(p_game_id uuid, p_rater_profile_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql

 SET search_path TO 'public'
AS $zz$
declare
  g record;
  prof record;
  r_user uuid;
  d record; v numeric;
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;

  -- KAN-727: end_at from events; cancelled = union of the two flags (never widened).
  select g0.id, e.end_at, (g0.is_cancelled or e.is_cancelled) as is_cancelled into g
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
$zz$;
CREATE FUNCTION pg_temp.k862_pre_rpc_rate_user(p_game_id uuid, p_rater_profile_id uuid, p_ratee_user_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql

 SET search_path TO 'public'
AS $zz$
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

  -- KAN-727: end_at from events; cancelled = union of the two flags (never widened); creator stays on games.
  SELECT g0.id, g0.creator_user_id, g0.start_at, e.end_at, (g0.is_cancelled OR e.is_cancelled) AS is_cancelled INTO g
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
$zz$;
CREATE FUNCTION pg_temp.k862_pre_rpc_rate_venue(p_game_id uuid, p_venue_id uuid, p_rater_profile_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql

 SET search_path TO 'public'
AS $zz$
DECLARE
  g      record;
  prof   record;
  r_user uuid;
  d record; v numeric;
  tied boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='auth_required'; END IF;

  -- KAN-727: end_at from events; cancelled = union of the two flags (never widened); creator stays on games.
  SELECT g0.id, g0.creator_user_id, e.end_at, (g0.is_cancelled OR e.is_cancelled) AS is_cancelled INTO g
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
$zz$;
CREATE FUNCTION pg_temp.k862_mut_active_stream(p_event_types text[] DEFAULT NULL::text[], p_city text DEFAULT NULL::text, p_limit integer DEFAULT 30, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_type text DEFAULT NULL::text, p_before_entity uuid DEFAULT NULL::uuid)
 RETURNS TABLE(event_type text, event_at timestamp with time zone, entity_kind text, entity_id uuid, actor_profile_id uuid, city text, title text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $zz$
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
       AND public._can_view_game(g.id)
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- game_started
    SELECT 'game_started'::text, e.start_at, 'game'::text, g.id, e.creator_profile_id, a.city, e.title
      FROM public.games g
      JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-731
      JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
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
       AND public.kan713_meetup_visible(m.event_id)                           -- KAN-713 helper: intersection
       AND NOT public.is_blocked(prm.viewer, e.creator_user_id)               -- KAN-731 / KAN-807: events half only
    UNION ALL
    -- meetup_started
    SELECT 'meetup_started'::text, e.start_at, 'meetup'::text, m.id, e.creator_profile_id, a.city, e.title
      FROM public.meetups m
      JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'   -- KAN-731
      LEFT JOIN public.areas a ON a.id = e.area_id, prm
     WHERE prm.viewer IS NOT NULL
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
$zz$;
CREATE FUNCTION pg_temp.k862_mut_rpc_rate_game(p_game_id uuid, p_rater_profile_id uuid, p_scores jsonb, p_comment text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql

 SET search_path TO 'public'
AS $zz$
declare
  g record;
  prof record;
  r_user uuid;
  d record; v numeric;
begin
  if auth.uid() is null then raise exception using errcode='P0001', message='auth_required'; end if;

  -- KAN-727 / KAN-807: end_at and cancelled from events.
  select g0.id, e.end_at, false as is_cancelled into g
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
$zz$;

-- Callers.
CREATE TEMP TABLE k862_u ON COMMIT DROP AS
WITH gh AS (SELECT DISTINCT ON (e.creator_user_id) e.creator_user_id AS uid, e.created_at FROM public.games g
              JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game' WHERE e.creator_user_id IS NOT NULL
             ORDER BY e.creator_user_id, e.created_at DESC),
     mh AS (SELECT DISTINCT ON (e.creator_user_id) e.creator_user_id AS uid, e.created_at FROM public.meetups m
              JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup' WHERE e.creator_user_id IS NOT NULL
             ORDER BY e.creator_user_id, e.created_at DESC),
     ro AS (SELECT DISTINCT gr.user_id AS uid FROM public.game_roster gr JOIN public.games g ON g.id = gr.game_id
              JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
             WHERE gr.status = 'active' AND e.end_at BETWEEN now() - interval '7 days' AND now() AND gr.user_id IS NOT NULL)
SELECT * FROM (SELECT 'game_host_' || row_number() OVER (ORDER BY created_at DESC) AS kind, uid FROM gh ORDER BY created_at DESC LIMIT 4) a
UNION ALL SELECT * FROM (SELECT 'meetup_host_' || row_number() OVER (ORDER BY created_at DESC), uid FROM mh ORDER BY created_at DESC LIMIT 3) b
UNION ALL SELECT * FROM (SELECT 'roster_' || row_number() OVER (ORDER BY uid), uid FROM ro ORDER BY uid LIMIT 4) c
UNION ALL SELECT 'admin', (SELECT min(u.id::text)::uuid FROM auth.users u WHERE public.is_admin(u.id))
UNION ALL SELECT 'plain', (SELECT min(u.id::text)::uuid FROM auth.users u WHERE NOT public.is_admin(u.id)
                             AND NOT EXISTS (SELECT 1 FROM public.events e WHERE e.creator_user_id = u.id)
                             AND NOT EXISTS (SELECT 1 FROM public.game_roster gr WHERE gr.user_id = u.id))
UNION ALL SELECT 'anon', NULL::uuid;
DELETE FROM k862_u WHERE kind <> 'anon' AND uid IS NULL;

-- Scenario games for the rating calls: every game ended in the last 7 days, 3 upcoming, 3 ended long ago, one missing id.
CREATE TEMP TABLE k862_g ON COMMIT DROP AS
SELECT * FROM (SELECT g.id AS gid, e.creator_user_id AS host, g.venue_id FROM public.games g
                 JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
                WHERE e.end_at BETWEEN now() - interval '7 days' AND now()) r
UNION ALL SELECT * FROM (SELECT g.id, e.creator_user_id, g.venue_id FROM public.games g
                 JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
                WHERE e.start_at > now() ORDER BY e.start_at, g.id LIMIT 3) u
UNION ALL SELECT * FROM (SELECT g.id, e.creator_user_id, g.venue_id FROM public.games g
                 JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
                WHERE e.end_at < now() - interval '7 days' ORDER BY e.end_at DESC, g.id LIMIT 3) o
UNION ALL SELECT '86200000-0000-0000-0000-0000000000ff'::uuid, NULL::uuid, NULL::uuid;

-- One call as a caller, in a subtransaction that is always undone. Returns the result text or the error.
CREATE FUNCTION pg_temp.k862_call(p_uid uuid, p_sql text) RETURNS text
LANGUAGE plpgsql AS $f$
DECLARE r text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims',
      CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('sub', p_uid, 'role', 'authenticated')::text END, true);
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    EXECUTE p_sql INTO r;
    RAISE EXCEPTION 'k862_undo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'k862_undo' THEN r := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(r, '<null>');
END $f$;

DO $run$
DECLARE ph text; u record; gg record; var text; fq text; t text; prof uuid; ratee uuid; acc text;
BEGIN
  FOREACH ph IN ARRAY ARRAY['live', 'fixture'] LOOP
    IF ph = 'fixture' THEN
      CREATE TEMP TABLE k862_fx ON COMMIT DROP AS
      SELECT * FROM (SELECT 'games'::text AS tbl, g.id, g.event_id FROM public.games g
                       JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
                      WHERE e.end_at BETWEEN now() - interval '7 days' AND now() ORDER BY e.end_at DESC, g.id LIMIT 2) a
      UNION ALL SELECT * FROM (SELECT 'games', g.id, g.event_id FROM public.games g
                       JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
                      WHERE e.start_at > now() ORDER BY e.start_at, g.id LIMIT 1) b
      UNION ALL SELECT * FROM (SELECT 'meetups', m.id, m.event_id FROM public.meetups m
                       JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
                      ORDER BY e.created_at DESC, m.id LIMIT 2) c;
      PERFORM set_config('kan712.contract', 'on', true);
      UPDATE public.events e SET is_cancelled = true FROM pg_temp.k862_fx f WHERE e.id = f.event_id;
      IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'is_cancelled' AND NOT attisdropped) THEN
        UPDATE public.games x SET is_cancelled = true FROM pg_temp.k862_fx f WHERE f.tbl = 'games' AND x.id = f.id;
      END IF;
      IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.meetups'::regclass AND attname = 'is_cancelled' AND NOT attisdropped) THEN
        UPDATE public.meetups x SET is_cancelled = true FROM pg_temp.k862_fx f WHERE f.tbl = 'meetups' AND x.id = f.id;
      END IF;
    END IF;
    FOR u IN SELECT * FROM pg_temp.k862_u LOOP
      SELECT p.id INTO prof FROM public.profiles p WHERE p.user_id = u.uid AND p.profile_type = 'player' ORDER BY p.created_at, p.id LIMIT 1;
      IF prof IS NULL THEN
        SELECT p.id INTO prof FROM public.profiles p WHERE p.user_id = u.uid ORDER BY p.created_at, p.id LIMIT 1;
      END IF;
      FOREACH var IN ARRAY ARRAY['live', 'pre', 'mut'] LOOP
        -- _is_game_host
        IF var <> 'mut' THEN
          fq := CASE var WHEN 'live' THEN 'public._is_game_host' ELSE 'pg_temp.k862_pre__is_game_host' END;
          INSERT INTO pg_temp.k862_cap VALUES (ph, '_is_game_host', var, u.kind,
            pg_temp.k862_call(u.uid, format('SELECT coalesce(string_agg(id::text, '','' ORDER BY id), '''') FROM public.games WHERE %s(id)', fq)));
        END IF;
        -- active_stream
        fq := CASE var WHEN 'live' THEN 'public.active_stream' WHEN 'pre' THEN 'pg_temp.k862_pre_active_stream' ELSE 'pg_temp.k862_mut_active_stream' END;
        FOREACH t IN ARRAY ARRAY['NULL::text[]', '''{game_created,game_started,game_ended}''::text[]',
                                 '''{meetup_created,meetup_started,meetup_completed}''::text[]'] LOOP
          INSERT INTO pg_temp.k862_cap VALUES (ph, 'active_stream', var, u.kind || '|' || t,
            pg_temp.k862_call(u.uid, format('SELECT coalesce(string_agg(to_jsonb(s)::text, ''|'' ORDER BY to_jsonb(s)::text), '''') FROM %s(%s, NULL, 50) s', fq, t)));
        END LOOP;
        IF var = 'mut' THEN CONTINUE; END IF;
        -- rpc_get_activity_feed
        fq := CASE var WHEN 'live' THEN 'public.rpc_get_activity_feed' ELSE 'pg_temp.k862_pre_rpc_get_activity_feed' END;
        INSERT INTO pg_temp.k862_cap VALUES (ph, 'rpc_get_activity_feed', var, u.kind,
          pg_temp.k862_call(u.uid, format('SELECT coalesce(string_agg(to_jsonb(s)::text, ''|'' ORDER BY to_jsonb(s)::text), '''') FROM %s(''all'', 500, NULL) s', fq)));
      END LOOP;
      -- ratings, per scenario game
      FOR gg IN SELECT * FROM pg_temp.k862_g LOOP
        FOREACH var IN ARRAY ARRAY['live', 'pre', 'mut'] LOOP
          fq := CASE var WHEN 'live' THEN 'public.rpc_rate_game' WHEN 'pre' THEN 'pg_temp.k862_pre_rpc_rate_game' ELSE 'pg_temp.k862_mut_rpc_rate_game' END;
          INSERT INTO pg_temp.k862_cap VALUES (ph, 'rpc_rate_game', var, u.kind || '|' || gg.gid,
            pg_temp.k862_call(u.uid, format('SELECT %s(%L, %L, ''{}''::jsonb, NULL)', fq, gg.gid, prof)));
          IF var = 'mut' THEN CONTINUE; END IF;
          fq := CASE var WHEN 'live' THEN 'public.rpc_rate_user' ELSE 'pg_temp.k862_pre_rpc_rate_user' END;
          SELECT min(gr.user_id::text)::uuid INTO ratee FROM public.game_roster gr
           WHERE gr.game_id = gg.gid AND gr.status = 'active' AND gr.user_id IS DISTINCT FROM u.uid;
          INSERT INTO pg_temp.k862_cap VALUES (ph, 'rpc_rate_user', var, u.kind || '|' || gg.gid || '|host',
            pg_temp.k862_call(u.uid, format('SELECT %s(%L, %L, %L, ''{}''::jsonb, NULL)', fq, gg.gid, prof, gg.host)));
          INSERT INTO pg_temp.k862_cap VALUES (ph, 'rpc_rate_user', var, u.kind || '|' || gg.gid || '|member',
            pg_temp.k862_call(u.uid, format('SELECT %s(%L, %L, %L, ''{}''::jsonb, NULL)', fq, gg.gid, prof, ratee)));
          fq := CASE var WHEN 'live' THEN 'public.rpc_rate_venue' ELSE 'pg_temp.k862_pre_rpc_rate_venue' END;
          INSERT INTO pg_temp.k862_cap VALUES (ph, 'rpc_rate_venue', var, u.kind || '|' || gg.gid,
            pg_temp.k862_call(u.uid, format('SELECT %s(%L, %L, %L, ''{}''::jsonb, NULL)', fq, gg.gid,
              coalesce(gg.venue_id, '86200000-0000-0000-0000-0000000000fe'::uuid), prof)));
        END LOOP;
      END LOOP;
    END LOOP;
  END LOOP;
END
$run$;

-- T0
INSERT INTO k862_tap SELECT 0,
  count(*) = 6 AND bool_and(md5(p.prosrc) = k.pre)
  AND (SELECT md5(prosrc) FROM pg_proc WHERE proname = 'k862_mut_active_stream' AND pronamespace = pg_my_temp_schema()) <> '8dcd300437015f7570e5b0ea6dbdb9b7'
  AND (SELECT md5(prosrc) FROM pg_proc WHERE proname = 'k862_mut_rpc_rate_game' AND pronamespace = pg_my_temp_schema()) <> 'de0f3b8f83fbc730f81a59eb62f64b42',
  'twins are the pinned pre-images; mutants differ from the new bodies',
  string_agg(k.fn || '=' || left(md5(p.prosrc), 8), ' ' ORDER BY k.fn)
  FROM (VALUES ('_is_game_host', '6db7b07bf7cf405d6935ecbf7bc15800'), ('active_stream', '3cad1cfaaa6fb56e1cbd7ac86e7e5192'),
               ('rpc_get_activity_feed', '1d6bb17983ba2ed632cb4f7602257162'), ('rpc_rate_game', 'd6f6f57755538391ece9aa19b6dd8a50'),
               ('rpc_rate_user', 'fd2700e72e60bdf7f7eb9e1b36201b10'), ('rpc_rate_venue', 'd1dab20091ecef646714dc20edf8ea7d')) k(fn, pre)
  JOIN pg_proc p ON p.proname = 'k862_pre_' || k.fn AND p.pronamespace = pg_my_temp_schema();

-- T1 (games alias g / g0; meetups alias m; rating bodies use g as a record variable, so only g0 is checked there)
INSERT INTO k862_tap SELECT 1,
  count(*) = 6 AND bool_and(NOT (p.prosrc ~ k.bad) AND position('search_tsv' IN p.prosrc) = 0
    AND NOT (p.prosrc ~ '\mm\.(creator_profile_id|creator_user_id|title|listing_visibility|rsvp_policy|capacity|start_at|end_at|is_cancelled|created_at|updated_at|search_tsv|geo_location_id|sport_id|area_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id)\M')),
  'new bodies read no removed games/meetups column and no Z01 manifest column',
  string_agg(k.fn || CASE WHEN p.prosrc ~ k.bad OR p.prosrc ~ '\mm\.(creator_user_id|listing_visibility|is_cancelled)\M' THEN '=BAD' ELSE '=clean' END, ' ' ORDER BY k.fn)
  FROM (VALUES ('_is_game_host', 'public._is_game_host(uuid)', '\mg\.(creator_user_id|is_cancelled|listing_visibility|start_at)\M'),
               ('active_stream', 'public.active_stream(text[],text,integer,timestamp with time zone,text,uuid)', '\mg\.(creator_user_id|is_cancelled|listing_visibility|start_at)\M'),
               ('rpc_get_activity_feed', 'public.rpc_get_activity_feed(text,integer,timestamp with time zone)', '\mg\.(creator_user_id|is_cancelled|listing_visibility|start_at)\M'),
               ('rpc_rate_game', 'public.rpc_rate_game(uuid,uuid,jsonb,text)', '\mg0\.(creator_user_id|is_cancelled|listing_visibility|start_at)\M'),
               ('rpc_rate_user', 'public.rpc_rate_user(uuid,uuid,uuid,jsonb,text)', '\mg0\.(creator_user_id|is_cancelled|listing_visibility|start_at)\M'),
               ('rpc_rate_venue', 'public.rpc_rate_venue(uuid,uuid,uuid,jsonb,text)', '\mg0\.(creator_user_id|is_cancelled|listing_visibility|start_at)\M')) k(fn, sig, bad)
  JOIN pg_proc p ON p.oid = k.sig::regprocedure;

-- T2..T7: live = twin
INSERT INTO k862_tap
SELECT 1 + row_number() OVER (ORDER BY o.ord), x.ndiff = 0 AND x.n > 0 AND x.nerr_live = 0,
  o.fn || ' live = pre-image twin on every scenario, both phases',
  x.ndiff || ' differing of ' || x.n || '; live 42703 errors ' || x.nerr_live
FROM (VALUES (1, '_is_game_host'), (2, 'active_stream'), (3, 'rpc_get_activity_feed'), (4, 'rpc_rate_game'),
             (5, 'rpc_rate_user'), (6, 'rpc_rate_venue')) o(ord, fn)
CROSS JOIN LATERAL (
  SELECT count(*) AS n, count(*) FILTER (WHERE a.v IS DISTINCT FROM b.v) AS ndiff,
         count(*) FILTER (WHERE a.v LIKE 'ERR 42703%') AS nerr_live
    FROM (SELECT ph, k, v FROM k862_cap WHERE fn = o.fn AND variant = 'live') a
    FULL JOIN (SELECT ph, k, v FROM k862_cap WHERE fn = o.fn AND variant = 'pre') b USING (ph, k)) x;

-- T8: negative controls
INSERT INTO k862_tap SELECT 8,
  count(*) FILTER (WHERE a.fn = 'active_stream' AND a.v IS DISTINCT FROM b.v) > 0
  AND count(*) FILTER (WHERE a.fn = 'rpc_rate_game' AND a.v IS DISTINCT FROM b.v) > 0,
  'negative controls: each mutant differs from its twin',
  'active_stream ' || count(*) FILTER (WHERE a.fn = 'active_stream' AND a.v IS DISTINCT FROM b.v)
  || ', rpc_rate_game ' || count(*) FILTER (WHERE a.fn = 'rpc_rate_game' AND a.v IS DISTINCT FROM b.v) || ' differing'
  FROM (SELECT * FROM k862_cap WHERE variant = 'mut') a
  JOIN (SELECT * FROM k862_cap WHERE variant = 'pre') b USING (ph, fn, k);

-- T9: capture not trivial
INSERT INTO k862_tap SELECT 9,
  count(*) FILTER (WHERE fn = 'active_stream' AND v <> '' AND v NOT LIKE 'ERR%') > 0
  AND count(*) FILTER (WHERE fn = 'active_stream' AND ph = 'live' AND v LIKE '%"entity_kind": "meetup"%') > 0
  AND count(*) FILTER (WHERE fn = '_is_game_host' AND v <> '' AND v NOT LIKE 'ERR%') > 0
  AND count(*) FILTER (WHERE fn = 'rpc_get_activity_feed' AND v <> '' AND v NOT LIKE 'ERR%') > 0
  AND count(DISTINCT v) FILTER (WHERE fn = 'rpc_rate_game') >= 3
  AND count(*) FILTER (WHERE fn LIKE 'rpc_rate_%' AND ph = 'fixture' AND v LIKE '%game_not_ratable%') > 0
  AND (SELECT count(*) FROM k862_u) >= 6,
  'capture not trivial',
  (SELECT count(*) FROM k862_u) || ' callers, ' || (SELECT count(*) FROM k862_g) || ' rating games; rate_game outcomes: '
  || (SELECT string_agg(DISTINCT left(v, 40), ' / ') FROM k862_cap WHERE fn = 'rpc_rate_game' AND variant = 'pre')
  FROM k862_cap WHERE variant = 'pre';

-- T10: attributes / ACL unchanged
INSERT INTO k862_tap SELECT 10,
  count(*) = 6 AND bool_and(p.proowner = 'postgres'::regrole AND p.prosecdef AND p.provolatile::text = k.vol
    AND p.proconfig::text = k.cfg AND p.proacl::text = k.acl AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = k.lang)),
  'attributes / ACL unchanged on all six', string_agg(k.fn || ' ' || p.proacl::text, '; ' ORDER BY k.fn)
  FROM (VALUES
    ('public._is_game_host(uuid)', 's', '{search_path=public}', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'sql'),
    ('public.active_stream(text[],text,integer,timestamp with time zone,text,uuid)', 's', '{"search_path=public, pg_temp"}', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'sql'),
    ('public.rpc_get_activity_feed(text,integer,timestamp with time zone)', 'v', '{"search_path=public, pg_temp"}', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'plpgsql'),
    ('public.rpc_rate_game(uuid,uuid,jsonb,text)', 'v', '{search_path=public}', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'plpgsql'),
    ('public.rpc_rate_user(uuid,uuid,uuid,jsonb,text)', 'v', '{search_path=public}', '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'plpgsql'),
    ('public.rpc_rate_venue(uuid,uuid,uuid,jsonb,text)', 'v', '{search_path=public}', '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}', 'plpgsql')
  ) k(fn, vol, cfg, acl, lang)
  JOIN pg_proc p ON p.oid = k.fn::regprocedure;

SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label || coalesce(' [' || detail || ']', ''), E'\n' ORDER BY n) AS tap
  FROM k862_tap;
ROLLBACK;
